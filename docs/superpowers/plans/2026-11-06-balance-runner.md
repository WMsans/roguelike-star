# Balance Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless battle runner that takes a JSON scenario, runs seeded auto-battles and reports win rates, time to kill and per-part output as JSON, usable by LLM agents with no help.

**Architecture:** `ChBattle` gains three seams (a per-tick `stepped` signal, per-side drive overrides, a public AI drive) and `ChEnergy` gains spend tracking. Everything else lives in `tools/balance/`: scenario parsing, a stats collector bound to one battle, pure aggregation and reporting, and a SceneTree CLI. Fights run one after another, a fresh `battle.tscn` instance each.

**Tech Stack:** Godot 4 GDScript, the project's own test runner (`tests/run_tests.gd`, `ChTest`).

**Spec:** `docs/superpowers/specs/2026-11-06-bodies-and-balance-design.md` §5 (the runner). This is plan 1 of 4. Plans for body types (§1, §1b, §2), balance rules and the list checker (§3), and in-game alignment (§4) are written after this plan lands, because each one is tuned with this runner. The `bodies`, `payoffs` and `builds` suites belong to those plans; this plan ships `smoke` and `standalone`. `airborne_seconds` moves to the bodies plan, where ground contact gets defined.

## Global Constraints

- Run tests with `godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]`. The filter matches test file paths. Output ends `N passed, M failed`; every task ends with the whole suite green.
- Runner fights run only under `godot --headless --fixed-fps 60`. Measured on this branch: without the flag, the same seed gives a different fight (12.5 s fight against 10.8 s with it), because frames run uncapped while physics stays at 60 Hz. With the flag a fight runs about 10× faster than real time.
- Every new seam defaults to today's behaviour: with no driver set and no listener attached, a fight plays out exactly as before.
- Scenario and result files are JSON. Metric names are snake_case and carry their unit (`_seconds`, `_per_energy`, `dps_`).
- A run writes files only where `--out` says. Nothing lands in the repo by default.
- Code comments follow the existing files: explain why, mark trade-offs with `# shortcut:`, and mark contracts with `# CONTRACT:`.

## Review Focus

1. **Running without `--fixed-fps 60`** must refuse with the exact command to use, never silently produce numbers that don't reproduce. (Task 5, shell test.)
2. **Scenario typos** (unknown part id, a slot path the body doesn't have, a missing field) must fail before any fight, with the field path and the valid values in the message. (Task 2 tests.)
3. **Aborted fights** must not hang the run. They are counted, their seeds are listed, and the exit code is 3. (Tasks 4 and 5.)
4. **Draws** (nobody dies in 60 s) count in `mean_fight_seconds` as 60 and in the `win_rate` denominator. (Task 4 test.)
5. **Both sides on the same body with different `hp` overrides** must not overwrite each other in the catalog. (Task 2 test.)

## File Structure

| File | Responsibility |
|---|---|
| `game/battle/ch_energy.gd` (modify) | `spent` total and public `is_queued` |
| `game/battle/ch_battle.gd` (modify) | `stepped` signal, `drivers`, `ai_drive`, public `hull_box` |
| `tools/balance/ch_balance_scenario.gd` | JSON → validated matchups (layouts, catalog, seeds, drive, expect) |
| `tools/balance/ch_balance_matchup.gd` | One runnable pairing: two layouts, their catalog, seeds, drive, expect |
| `tools/balance/ch_balance_drivers.gd` | `ai`, `hold` and `charge` drive policies as Callables |
| `tools/balance/ch_fight_stats.gd` | Bound to one battle: samples ticks and events into a per-fight dictionary |
| `tools/balance/ch_balance_report.gd` | Pure: aggregate fights, check `expect`, summary text, `RESULT` line |
| `tools/balance/run.gd` | CLI entry: args, frame-pacing guard, `--list`, `--suite`, exit codes |
| `tools/balance/run.sh` | Wrapper that always passes `--headless --fixed-fps 60` |
| `tools/balance/suites/smoke.json`, `standalone.json` | Built-in suites |
| `tools/balance/README.md` | Commands, schema, metric meanings, how to read output |
| `.claude/skills/balance-runner/SKILL.md` | When an agent should use the runner and how |
| `tests/balance/test_*.gd` | Tests for the above |

---

### Task 1: Battle and energy seams

**Files:**
- Modify: `game/battle/ch_energy.gd`, `game/battle/ch_battle.gd`
- Test: `tests/battle/test_energy.gd`, `tests/battle/test_battle.gd`

**Interfaces:**
- Produces:
  - `ChEnergy.spent: float`: total energy paid since construction, for driving plus every paid request.
  - `ChEnergy.is_queued(requester: Object) -> bool`: public form of `_queued`.
  - `signal ChBattle.stepped(ctx: ChBattleContext)`: emitted once per fight tick, at the end of `_step` after `ctx.tick` and before the result check, so the last tick is included.
  - `ChBattle.drivers: Array[Callable]`: two entries, default `[Callable(), Callable()]`. A valid entry `func(battle: ChBattle, side: int) -> float` replaces that side's drive. The defaults stay `_player_drive()` for side 0 and the AI for side 1.
  - `ChBattle.ai_drive(side: int) -> float`: today's `ai.decide(...)` call, for either side, against the other chariot.
  - `ChBattle.hull_box(chariot: ChChariotRuntime) -> Rect2`: `_hull_box` made public. Update its callers.

- [ ] **Step 1: Write the failing tests**

In `tests/battle/test_energy.gd`:

```gdscript
func test_spent_counts_drive_and_paid_requests() -> void:
	var pool := ChEnergy.new(10.0, 0.0, 2.0)
	pool.request(_requester(), 3.0)
	pool.tick(0.5, true)  # drive 2/s * 0.5 s = 1, then the request's 3
	assert_near(pool.spent, 4.0, 0.0001, "drive and paid request both count")
	assert_near(pool.value, 6.0, 0.0001)
	_complete()


func test_is_queued_reports_waiting_requester() -> void:
	var pool := ChEnergy.new(1.0, 0.0, 2.0)
	var waiting := _requester()
	pool.request(waiting, 5.0)
	pool.tick(0.0, false)
	assert_true(pool.is_queued(waiting), "unaffordable request waits")
	assert_true(not pool.is_queued(_requester()), "a stranger is not queued")
	_complete()
```

In `tests/battle/test_battle.gd` (it already has `_battle_scene`, `_fight` and the `ChTest` layouts):

```gdscript
func test_stepped_fires_every_tick_and_drivers_override() -> void:
	var battle := _battle_scene()
	var ticks := [0]
	battle.stepped.connect(func(_ctx): ticks[0] += 1)
	# Player charges, enemy holds: the player must close distance.
	battle.drivers = [func(b, s): return 1.0, func(b, s): return 0.0]
	var start_gap := [-1.0]
	battle.stepped.connect(func(ctx):
		if start_gap[0] < 0.0:
			start_gap[0] = absf(ctx.chariots[1].chassis.global_position.x - ctx.chariots[0].chassis.global_position.x))
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1)
	assert_eq(ticks[0], int(round(battle.ctx.time / ChBattle.TICK)), "one stepped per tick, last tick included")
	var end_gap := absf(battle.enemy.chassis.global_position.x - battle.player.chassis.global_position.x)
	assert_true(end_gap < start_gap[0], "the charging player closed the gap")
	battle.free()
	_complete()


func test_ai_drive_is_symmetric() -> void:
	# ai_drive on side 0 decides toward side 1 with the same rule the enemy uses.
	var battle := _battle_scene()
	battle.drivers = [func(b, s): return b.ai_drive(s), Callable()]
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "an AI-driven player still finishes the fight")
	battle.free()
	_complete()
```

- [ ] **Step 2: Run them and check they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd -- test_energy` and `-- test_battle.gd`
Expected: FAIL. `spent`, `is_queued`, `stepped` and `drivers` don't exist yet.

- [ ] **Step 3: Implement the seams**

- `ChEnergy.tick` adds `drive_cost * delta` when it drives and each paid `cost` to `spent`. `is_queued` returns `_queued(requester)`.
- In `ChBattle._step`: `drives[side] = drivers[side].call(self, side) if drivers[side].is_valid() else <default>`, where side 1's default is `ai_drive(1)`. `ai_drive(side)` holds today's `ai.decide(...)` arguments with `self`/`other` resolved from `side`. Emit `stepped.emit(ctx)` right after `ctx.tick(delta, drives)`.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed`. Existing battle tests are unchanged, which shows the defaults behave as before.

- [ ] **Step 5: Commit**

```bash
git add game/battle/ch_energy.gd game/battle/ch_battle.gd tests/battle/test_energy.gd tests/battle/test_battle.gd
git commit -m "feat(battle): stepped signal, drive overrides and energy spend for the balance runner"
```

---

### Task 2: Scenario parsing and drive policies

**Files:**
- Create: `tools/balance/ch_balance_scenario.gd`, `tools/balance/ch_balance_matchup.gd`, `tools/balance/ch_balance_drivers.gd`
- Test: `tests/balance/test_scenario.gd`

**Interfaces:**
- Consumes: `ChCatalog.load_default()`, `ChCatalog.from_defs(parts, bodies)`, `ChChariotLayout.place(path, id)` / `toggle_flip(path)`, `ChBattle.ai_drive`, `ChBattle.hull_box`.
- Produces:
  - `class_name ChBalanceMatchup extends RefCounted` in its own file `tools/balance/ch_balance_matchup.gd`, with `name: String`, `player: ChChariotLayout`, `enemy: ChChariotLayout`, `catalog: ChCatalog`, `seeds: Array[int]`, `drive: PackedStringArray` (2 entries), `expect: Dictionary`.
  - `ChBalanceScenario.parse(data: Variant, base: ChCatalog, where: String) -> Dictionary` returning `{"ok": bool, "errors": PackedStringArray, "matchups": Array[ChBalanceMatchup]}`. `where` prefixes every error (a file path).
  - `ChBalanceScenario.parse_suite(data: Variant, base: ChCatalog, where: String) -> Dictionary`: same return; a suite is `{"name": String, "scenarios": [scenario, ...]}`.
  - `ChBalanceDrivers.make(policy: String) -> Callable` with the `func(battle, side) -> float` shape. `ai` → `battle.ai_drive(side)`, `hold` → `0.0`, `charge` → the sign of the other chassis's x minus own.
  - `ChBalanceDrivers.POLICIES := ["ai", "hold", "charge"]`.

Scenario schema (from the spec, plus `hp`):

```json
{
  "name": "string, required",
  "player": SIDE or [SIDE, ...],
  "enemy":  SIDE or [SIDE, ...],
  "seeds": {"from": 1, "count": 20},
  "drive": {"player": "ai", "enemy": "ai"},
  "expect": {"win_rate": [0.4, 0.6], "player.dps_dealt": [10, 20]}
}
SIDE = {"layout": "res://...tres"}
     | {"body_id": "cutter", "parts": [{"slot": [2], "part": "cutter_rocket", "flipped": false}], "hp": 100000}
```

- `seeds` defaults to `{"from": 1, "count": 10}` and `drive` to `ai`/`ai`. `hp` is optional.
- A list on either side makes a matrix: every player × enemy pair is one matchup, named `"<name>/<i>x<j>"`.
- `body_type`/`body_seed` are rejected for now with "body types arrive with the bodies plan". (The bodies plan adds them.)
- An `hp` override duplicates the body def under the id `"<body_id>__hp<hp>"` and points that side's layout at it. Copy the fields one by one, the way `ChTest._body_with_hp` does, because `duplicate()` drops them.
- Parts are placed shortest path first, so a part mounted on another part finds its parent.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends ChTest

func _base() -> ChCatalog:
	return ChCatalog.load_default()

func _side() -> Dictionary:
	return {"body_id": "cutter", "parts": [{"slot": [0], "part": "wheel"}, {"slot": [1], "part": "wheel"},
		{"slot": [2], "part": "cutter_rocket"}]}

func test_valid_scenario_builds_one_matchup() -> void:
	var out := ChBalanceScenario.parse({"name": "s", "player": _side(),
		"enemy": {"layout": "res://game/data/enemies/dozer_cook.tres"}}, _base(), "s.json")
	assert_true(out.ok, str(out.errors))
	assert_eq(out.matchups.size(), 1)
	var m: ChBalanceMatchup = out.matchups[0]
	assert_eq(m.seeds, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "default seeds")
	assert_eq(Array(m.drive), ["ai", "ai"], "default drive")
	assert_eq(m.player.get_node([2]).part_id, &"cutter_rocket")
	_complete()

func test_unknown_part_names_field_and_known_ids() -> void:
	var side := _side()
	side.parts[2].part = "rocket"
	var out := ChBalanceScenario.parse({"name": "s", "player": side, "enemy": _side()}, _base(), "s.json")
	assert_true(not out.ok)
	assert_true(out.errors[0].begins_with("s.json: player.parts[2].part: unknown part 'rocket'"), out.errors[0])
	assert_true(out.errors[0].contains("cutter_rocket"), "lists the known ids")
	_complete()

func test_slot_the_body_lacks_is_an_error() -> void:
	var side := _side()
	side.parts[2].slot = [9]
	var out := ChBalanceScenario.parse({"name": "s", "player": side, "enemy": _side()}, _base(), "s.json")
	assert_true(not out.ok)
	assert_true(out.errors[0].contains("player.parts[2].slot"), out.errors[0])
	_complete()

func test_missing_name_and_bad_drive_are_both_reported() -> void:
	var out := ChBalanceScenario.parse({"player": _side(), "enemy": _side(), "drive": {"player": "zoom"}},
		_base(), "s.json")
	assert_true(not out.ok)
	assert_eq(out.errors.size(), 2, str(out.errors))
	_complete()

func test_matrix_expands_every_pair() -> void:
	var out := ChBalanceScenario.parse({"name": "m", "player": [_side(), _side()],
		"enemy": [_side(), _side(), _side()]}, _base(), "m.json")
	assert_true(out.ok, str(out.errors))
	assert_eq(out.matchups.size(), 6)
	assert_eq(out.matchups[5].name, "m/1x2")
	_complete()

func test_same_body_different_hp_overrides_do_not_clash() -> void:
	var a := _side(); a.hp = 100
	var b := _side(); b.hp = 900
	var out := ChBalanceScenario.parse({"name": "s", "player": a, "enemy": b}, _base(), "s.json")
	assert_true(out.ok, str(out.errors))
	var m: ChBalanceMatchup = out.matchups[0]
	assert_eq(m.catalog.body(m.player.body_id).hp, 100)
	assert_eq(m.catalog.body(m.enemy.body_id).hp, 900)
	_complete()

func test_charge_driver_points_at_the_enemy() -> void:
	# Pure check of the sign rule, with stand-in chassis positions.
	assert_eq(ChBalanceDrivers.charge_toward(10.0, 50.0), 1.0)
	assert_eq(ChBalanceDrivers.charge_toward(50.0, 10.0), -1.0)
	_complete()
```

(`ChBalanceDrivers.charge_toward(self_x: float, other_x: float) -> float` is the pure core the `charge` Callable calls.)

- [ ] **Step 2: Run them and check they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd -- balance`
Expected: FAIL. The classes don't exist yet.

- [ ] **Step 3: Implement `ChBalanceScenario`, `ChBalanceMatchup` and `ChBalanceDrivers`**

Validation collects every error rather than stopping at the first. Error format: `"<where>: <field path>: <problem>"`. Unknown ids list the valid ones, sorted.

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tools/balance/ch_balance_scenario.gd tools/balance/ch_balance_matchup.gd tools/balance/ch_balance_drivers.gd tests/balance/test_scenario.gd
git commit -m "feat(balance): scenario parsing and drive policies"
```

---

### Task 3: Per-fight stats

**Files:**
- Create: `tools/balance/ch_fight_stats.gd`
- Test: `tests/balance/test_fight_stats.gd`

**Interfaces:**
- Consumes: `ChBattle.stepped`, `ChBattle.hull_box`, `ChEnergy.spent` / `is_queued`, `ChEvent.PART_FIRED` / `HIT` (HIT's `data.hp_damage`), `ChEventBus.subscribe(listener, type, callback)`.
- Produces: `class_name ChFightStats extends RefCounted` with
  - `bind(battle: ChBattle) -> void`: connects `stepped`, and subscribes to `ctx.bus` on the first step (the bus doesn't exist before `start()`).
  - `fight(seed: int, result: StringName) -> Dictionary`: the per-fight dictionary below.

Per-fight dictionary:

```
{ "seed": int, "result": "win"|"loss"|"draw"|"aborted", "fight_seconds": float,
  "sides": [SIDE0, SIDE1] }
SIDE = { "hp_left": int, "damage_dealt": int, "unattributed_damage": int, "dps_dealt": float,
         "energy_spent": float, "energy_starved_seconds": float, "flipped_seconds": float,
         "rams": int, "parts": { "<part_id>@<path>": PART } }
PART = { "part": String, "path": Array, "firings": int, "hits": int, "misses": int,
         "damage_dealt": int, "energy_spent": float, "damage_per_energy": float,
         "seconds_waiting": float, "broke_at_seconds": float }
```

Definitions:
- `damage_dealt`: the opposing chariot's `body_def.hp - hp`, so burn damage is included.
- `unattributed_damage`: `damage_dealt` minus the sum of the side's part `damage_dealt` (burn and other damage no part claimed).
- Part `damage_dealt`: the sum of `hp_damage` over HIT events whose `source` is that part.
- Part `energy_spent`: `firings * def.energy_cost`. (The alignment plan changes this when continuous parts pay per second.)
- `damage_per_energy`: `damage_dealt / energy_spent`, or `0.0` when `energy_spent` is 0.
- `misses`: `max(0, firings - hits)`. Documented as approximate in the README.
- `energy_starved_seconds`: ticks with `energy.queue_size() > 0`, times `TICK`.
- `flipped_seconds`: ticks with `absf(wrapf(chassis.global_rotation, -PI, PI)) > PI / 2`.
- `rams`: how many times the two chariots start touching, meaning `hull_box(a).grow(1.0).intersects(hull_box(b))` turns from false to true. The count is the same for both sides.
- `broke_at_seconds`: `ctx.time` on the first tick a part reads `broken`, else `-1.0`.
- `fight_seconds`: `ctx.time`, or `0.0` for an aborted fight. An aborted fight's sides are present with zeros.

- [ ] **Step 1: Write the failing tests**

One real fight (the suite runs without `--fixed-fps`, so assert invariants, not exact values):

```gdscript
extends ChTest

func test_stats_invariants_on_a_won_fight() -> void:
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	var stats := ChFightStats.new()
	stats.bind(battle)
	var results: Array[StringName] = []
	battle.finished.connect(func(r): results.append(r))
	await battle.start(_player_layout(), _enemy_layout(), _fight_catalog(30), 12345)
	var f := stats.fight(12345, results[0])
	assert_eq(f.result, "win")
	var me: Dictionary = f.sides[0]
	assert_eq(me.damage_dealt, 30, "won against a 30 HP enemy: all of it dealt")
	var part_sum := 0
	for key in me.parts:
		var p: Dictionary = me.parts[key]
		part_sum += p.damage_dealt
		assert_true(p.firings >= 0 and p.hits >= 0, "counts are non-negative")
		assert_eq(p.misses, maxi(0, p.firings - p.hits))
	assert_eq(me.unattributed_damage, me.damage_dealt - part_sum)
	assert_eq(f.sides[1].hp_left, 0)
	assert_near(f.fight_seconds, battle.ctx.time, 0.0001)
	assert_true(me.energy_spent > 0.0, "the winner paid for its shots")
	battle.free()
	_complete()


func test_aborted_fight_has_zeroed_sides() -> void:
	var stats := ChFightStats.new()
	var f := stats.fight(7, &"aborted")
	assert_eq(f.result, "aborted")
	assert_eq(f.fight_seconds, 0.0)
	assert_eq(f.sides.size(), 2)
	assert_eq(f.sides[0].damage_dealt, 0)
	_complete()
```

- [ ] **Step 2: Run them and check they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd -- balance`
Expected: FAIL. `ChFightStats` doesn't exist yet.

- [ ] **Step 3: Implement `ChFightStats`**

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tools/balance/ch_fight_stats.gd tests/balance/test_fight_stats.gd
git commit -m "feat(balance): per-fight stats collector"
```

---

### Task 4: Aggregation, expectations and output text

**Files:**
- Create: `tools/balance/ch_balance_report.gd`
- Test: `tests/balance/test_report.gd`

**Interfaces:**
- Consumes: per-fight dictionaries from Task 3.
- Produces: `class_name ChBalanceReport extends RefCounted` with static
  - `aggregate(name: String, fights: Array[Dictionary]) -> Dictionary`
  - `check_expect(agg: Dictionary, expect: Dictionary) -> PackedStringArray` (one message per failed or unknown path)
  - `summary_text(aggs: Array[Dictionary]) -> String`
  - `result_line(aggs: Array[Dictionary], failures: PackedStringArray) -> String`

Aggregate shape:

```
{ "name", "fights", "wins", "losses", "draws", "aborted", "win_rate", "mean_fight_seconds",
  "aborted_seeds": [...], "draw_seeds": [...], "player": SIDE_MEANS, "enemy": SIDE_MEANS }
```

- `SIDE_MEANS` has the same keys as a fight's `SIDE`, holding means over the non-aborted fights. `parts` is merged by key, with every numeric field averaged. `broke_at_seconds` is averaged over the fights where the part broke, and a `broke_fraction` field is added.
- `win_rate` = wins / (fights − aborted), or `0.0` when every fight aborted.
- A draw counts as a fight in both `win_rate` and `mean_fight_seconds`, with its real `fight_seconds` (60).
- `expect` paths are dotted (`win_rate`, `player.dps_dealt`, `player.parts.cutter_rocket@[2].damage_per_energy`), and values are inclusive `[min, max]`. An unknown path is a failure, with the message `"<name>: expect <path>: no such metric"`.
- `summary_text` prints one block per aggregate: the W/L/D/aborted counts and win rate, the mean fight seconds, then a part table per side (part, firings, hits, damage, damage per energy, seconds waiting).
- `result_line` = `"RESULT " + JSON.stringify({"ok": failures.is_empty() and no aborts, "scenarios": [{name, win_rate, mean_fight_seconds, aborted}], "failures": failures})`, on one line.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends ChTest

func _fight(result: String, seconds: float, dealt: int) -> Dictionary:
	var side := {"hp_left": 0, "damage_dealt": dealt, "unattributed_damage": 0, "dps_dealt": dealt / maxf(seconds, 0.001),
		"energy_spent": 10.0, "energy_starved_seconds": 0.0, "flipped_seconds": 0.0, "rams": 0,
		"parts": {"cutter_rocket@[2]": {"part": "cutter_rocket", "path": [2], "firings": 4, "hits": 2, "misses": 2,
			"damage_dealt": dealt, "energy_spent": 8.0, "damage_per_energy": dealt / 8.0,
			"seconds_waiting": 0.0, "broke_at_seconds": -1.0}}}
	return {"seed": 1, "result": result, "fight_seconds": seconds, "sides": [side, side.duplicate(true)]}

func test_draws_count_and_aborts_do_not() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100), _fight("draw", 60.0, 50),
		_fight("aborted", 0.0, 0)])
	assert_eq(agg.fights, 3)
	assert_eq(agg.aborted, 1)
	assert_near(agg.win_rate, 0.5, 0.0001, "1 win of 2 real fights")
	assert_near(agg.mean_fight_seconds, 35.0, 0.0001, "draw counted as 60, abort excluded")
	assert_eq(agg.draw_seeds, [1])
	_complete()

func test_expect_passes_fails_and_flags_unknown_paths() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100)])
	assert_eq(ChBalanceReport.check_expect(agg, {"win_rate": [0.9, 1.0]}).size(), 0)
	assert_eq(ChBalanceReport.check_expect(agg, {"player.parts.cutter_rocket@[2].damage_per_energy": [20, 30]}).size(), 1)
	var unknown := ChBalanceReport.check_expect(agg, {"player.nope": [0, 1]})
	assert_eq(unknown.size(), 1)
	assert_true(unknown[0].contains("no such metric"), unknown[0])
	_complete()

func test_all_aborted_gives_zero_win_rate() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("aborted", 0.0, 0)])
	assert_eq(agg.win_rate, 0.0)
	_complete()

func test_result_line_is_one_parseable_line() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100)])
	var line := ChBalanceReport.result_line([agg], PackedStringArray())
	assert_true(line.begins_with("RESULT "))
	assert_true(not line.contains("\n"))
	var parsed = JSON.parse_string(line.substr(7))
	assert_eq(parsed.ok, true)
	assert_eq(parsed.scenarios[0].name, "x")
	_complete()
```

- [ ] **Step 2: Run them and check they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd -- balance`
Expected: FAIL. `ChBalanceReport` doesn't exist yet.

- [ ] **Step 3: Implement `ChBalanceReport`**

- [ ] **Step 4: Run the whole suite**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tools/balance/ch_balance_report.gd tests/balance/test_report.gd
git commit -m "feat(balance): aggregate fights, check expectations, print results"
```

---

### Task 5: The CLI

**Files:**
- Create: `tools/balance/run.gd`, `tools/balance/run.sh` (executable), `tools/balance/suites/smoke.json`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces, for later plans and agents:
  - `tools/balance/run.sh <scenario.json> [--out <file>]`
  - `tools/balance/run.sh --suite <name> [--out <file>]`, where a suite is `tools/balance/suites/<name>.json`.
  - `tools/balance/run.sh --list`: prints part ids, body ids, `res://game/data/enemies/*.tres` layouts and suite names, one section each.
  - Exit codes: `0` ok, `1` usage, parse or frame-pacing error (no fights run), `2` an `expect` failed, `3` a fight aborted. When several apply, the highest wins.

Behaviour:
- `run.sh` is `exec godot --headless --fixed-fps 60 --path "$(dirname "$0")/../.." -s res://tools/balance/run.gd -- "$@"`.
- The frame-pacing guard runs first: over 10 process frames, `Engine.get_physics_frames()` must advance by exactly 10. Otherwise print `balance: run with --headless --fixed-fps 60 (use tools/balance/run.sh) — without it fights don't reproduce` and exit 1.
- Each fight: instantiate `battle.tscn`, add it to root, set `drivers` from `ChBalanceDrivers.make`, bind a fresh `ChFightStats`, `await start(...)`, collect the fight, `free()` the battle, then go on to the next fight.
- Progress goes to stdout as one line per matchup (`[3/12] wedge-vs-tower: 7W 3L 0D`). Then `summary_text`, then the `RESULT` line, which comes last.
- `--out` writes `{"aggregates": [...], "fights": {name: [...]}, "failures": [...]}` as indented JSON.

`suites/smoke.json`: one matchup, the Cutter with wheels and a `cutter_rocket` against `dozer_cook.tres`, seeds 1–3, with `"expect": {"aborted": [0, 0]}`.

- [ ] **Step 1: Check the frame-pacing guard refuses**

Run: `godot --headless --path . -s res://tools/balance/run.gd -- --suite smoke; echo "exit=$?"`
Expected, once implemented: the guard message and `exit=1`. Before implementation: the script is missing.

- [ ] **Step 2: Implement `run.gd`, `run.sh` and `suites/smoke.json`**

- [ ] **Step 3: Verify the smoke suite and determinism**

Run:
```bash
out=$(mktemp -d)
tools/balance/run.sh --suite smoke --out "$out/a.json"; echo "exit=$?"
tools/balance/run.sh --suite smoke --out "$out/b.json"; echo "exit=$?"
diff "$out/a.json" "$out/b.json" && echo SAME
```
Expected: both runs `exit=0`, the last stdout line starts `RESULT {"ok":true`, and `SAME`.

- [ ] **Step 4: Verify the error paths**

Run each and check the exit code and message:
- A scenario file with `"part": "rocket"` → `exit=1`, the message names `player.parts[...].part` and lists `cutter_rocket`.
- `smoke.json` copied with `"expect": {"win_rate": [2, 3]}` → `exit=2`, and the `RESULT` failures name `win_rate`.
- `--list` → `exit=0`, with sections for parts, bodies, layouts and suites.
- No arguments → `exit=1` and the usage text.

- [ ] **Step 5: Run the whole test suite, then commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed`.

```bash
git add tools/balance/run.gd tools/balance/run.sh tools/balance/suites/smoke.json
git commit -m "feat(balance): headless runner CLI with smoke suite"
```

---

### Task 6: Standalone suite, README and agent skill

**Files:**
- Create: `tools/balance/suites/standalone.json`, `tools/balance/README.md`, `.claude/skills/balance-runner/SKILL.md`

**Interfaces:**
- Consumes: the CLI from Task 5.
- Produces: the `standalone` suite that later plans compare against the paper baseline, and the docs that agents read.

`standalone.json`: one scenario per in-game damaging part (`cutter_rocket`, `cutter_chainsaw`, `flamethrower`, `firebolt_launcher`, `hearth`, `ice_cream_mace`, `ring_of_fire`, `corsair_harpoon`). Each puts the part on a Cutter (`[0]`/`[1]` wheels, the part at `[2]`) against a reference dummy: a Dozer layout with two wheels and nothing else, `"hp": 100000`, enemy drive `hold`, player drive `ai`, seeds 1–5. No `expect`: this suite measures. My call on the reference body and dummy (the spec leaves them to the builder): the Cutter is the starting body, and a dummy that can't die or fight back means every fight runs the full 60 s, so damage per energy is measured over the same window for every part.

README sections, in this order:
1. **What it's for**: one paragraph, plus when to run it (after changing a part, a body or a balance number).
2. **Run it**: the three commands, the exit codes, and why `run.sh` exists (`--fixed-fps 60`).
3. **Scenario schema**: the schema block from Task 2, with every field's default.
4. **Reading results**: the `RESULT` line, then each metric with its definition from Tasks 3–4, including that `misses` is approximate and `unattributed_damage` is mostly burn.
5. **Suites**: what `smoke` and `standalone` measure. `bodies`, `payoffs` and `builds` are listed as coming with the later plans.
6. **Writing a regression check**: an `expect` example.
7. **Gotchas**: a run takes about 6 s per 60-second fight; parts are referenced by slot path; the enemy layout is mirrored by the battle, so write it facing right like the player's.

`SKILL.md` frontmatter `name: balance-runner`, with the description "Use after changing any part, body or balance number in roguelike-star, or when asked whether something is balanced: runs headless seeded battles and reports win rates and per-part damage per energy." The body points to the README and repeats only the three commands and the exit codes.

- [ ] **Step 1: Write `standalone.json` and run it**

Run: `tools/balance/run.sh --suite standalone --out "$(mktemp -d)/standalone.json"; echo "exit=$?"`
Expected: `exit=0` and 8 matchup lines. Every part shows `firings > 0`. (A part with 0 firings means the layout is wrong: fix the scenario, not the part.)

- [ ] **Step 2: Write `README.md` and `SKILL.md`**

- [ ] **Step 3: Check that an agent can use it from the README alone**

Dispatch a fresh general-purpose subagent with only this prompt: "In /mnt/windows/Godot/roguelike-star, read only tools/balance/README.md. Write a scenario pitting a Corsair carrying an ice_cream_mace against dozer_cook.tres over seeds 1–4, run it, and report the player's win rate and the mace's damage per energy. Then list anything in the README that was unclear or wrong." Expected: it runs the scenario and reports both numbers. Fix every README problem it lists.

- [ ] **Step 4: Commit**

```bash
git add tools/balance/suites/standalone.json tools/balance/README.md .claude/skills/balance-runner/SKILL.md
git commit -m "docs(balance): standalone suite, runner README and agent skill"
```

- [ ] **Step 5: Hand back the baseline**

Paste the `standalone` suite's per-part damage per energy and DPS into the final report. They are the "before" numbers for the alignment plan.
