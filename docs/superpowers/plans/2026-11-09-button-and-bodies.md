# One Button and Body Shapes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parts fire only when the player presses one button (a volley of every ready triggered part), and Cutter, Dozer and Corsair become Wedge, Tower and Barge silhouettes with their own mass, grip and enemy driving style.

**Architecture:** The FIFO energy queue is replaced by a press-driven volley inside `ChBattleContext.tick`, fed by per-side press callables on `ChBattle` that mirror the existing `drivers`. Bodies gain an outline polygon, physics props and a drive style on `ChBodyDef`. `ChTextures` fills the outline, and the engine's convex hull does the rest. The balance runner gains press policies and a `bodies` suite, and is then used to re-tune.

**Tech Stack:** Godot 4 / GDScript, the `noita_engine` GDExtension (`PixelRigidBody`), the headless test runner `tests/run_tests.gd`, the balance runner `tools/balance/run.sh`.

**Spec:** `docs/superpowers/specs/2026-11-09-button-and-bodies-design.md`

## Global Constraints

- The fire key is `Space`, input action `fire`. The edge counts: holding fires once.
- A part is **triggered** when `def.cooldown > 0`, and **passive** otherwise. No new field.
- Volley: ready triggered parts are paid **dearest `energy_cost` first, ties in mount order**. A part that doesn't fit is skipped, and cheaper parts after it can still pay. Unpaid parts stay ready, and nothing is remembered between presses.
- Driving is still paid before the volley.
- Ready triggered parts show a **glowing outline**: no fill tint. No "N ready" HUD count. The "N parts waiting" line is removed.
- Body ids, display names, **slot count and slot order** are kept. The cook keeps its file and id `dozer_cook`, and its `body_id` becomes `corsair`.
- `ChBodyDef.size` must equal the outline's bounding box, so every reader of `size` (hull box, half-width, camera, pit) stays correct.
- Enemy press thresholds (Proposed): press when a ready part has a target in reach and the pool ≥ **60%** of the ready volley's cost, or the pool is at cap.
- Tests are run with `godot --headless --path . --script res://tests/run_tests.gd` and must end `0 failed`. If `tests/balance/*` report "did not run", run `godot --headless --path . --import` once first.
- Runner fights must use `tools/balance/run.sh`, which passes `--fixed-fps 60`.
- When an old test pins old behaviour, read its comments for what it checks. Change constants or add the press, and don't weaken what is checked.
- Commit after every task. Commit only the task's files: the tree has unrelated uncommitted edits in `tools/balance/suites/*.json` and the handoff doc, so never `git add -A`.

## Review Focus

1. **A part that becomes ready while the press is held** must not fire until the next press. The edge counts, not the hold. Test in Task 2.
2. **A frozen, broken or out-of-charges part at the moment of a press** must not fire or pay. Test in Task 1.
3. **A press with no energy, or with nothing ready**, must pay nothing, change no cooldown and give the dud nudge, not crash. Tests in Tasks 1 and 2.
4. **A mirrored (enemy) Wedge** must have its nose facing the player. Mirroring only negated part anchors before. Test in Task 5.
5. **Body copies** (`ChTest._body_with_hp`, `ChBalanceScenario._body_with_hp`) must carry the new outline, mass and drive fields, or test and runner fights silently use box hulls. Test in Task 5.

---

### Task 1: The volley replaces the energy queue

**Files:**
- Modify: `game/battle/ch_energy.gd` (drop `queue`, `request`, `cancel`, `queue_size`, `is_queued`, `_queued`, and the queue pass in `tick`)
- Modify: `game/battle/ch_part_runtime.gd` (add `is_ready`)
- Modify: `game/battle/ch_battle_context.gd:195-274` (`tick`, `_tick_chariot`)
- Modify: `game/battle/ch_chariot_runtime.gd:60-70` (`break_part` no longer calls `energy.cancel`)
- Test: `tests/battle/test_energy.gd`, `tests/battle/test_context.gd`, `tests/battle/test_behaviours_{melee,fire,ranged}.gd`, `tests/battle/test_part_runtime.gd`

**Interfaces:**
- Produces:
  - `ChEnergy.try_pay(cost: float) -> bool`: spends and adds to `spent` when `cost <= value`, else changes nothing.
  - `ChEnergy.tick(delta: float, driving: bool) -> Dictionary`: returns `{"drove": bool}`.
  - `ChPartRuntime.is_ready() -> bool`: `def != null and def.cooldown > 0 and not broken and cooldown_left <= 0 and charges_left != 0 and not is_frozen()`.
  - `ChPartRuntime.tick_cooldown(delta)` keeps counting down. It no longer implies a fire.
  - `ChBattleContext.tick(delta: float, drive_input: Array[float], press_input: Array = []) -> Array[int]`: `press_input[side]` is a bool (missing reads false). Returns the number of parts fired per side.
  - `ChBattleContext.volley_cost(chariot: ChChariotRuntime) -> int`: the sum of `energy_cost` over the chariot's ready parts.

- [ ] **Step 1: Rewrite `tests/battle/test_energy.gd` for the new pool**

Delete the queue tests (`test_request_paid_immediately_when_affordable`, `test_fifo_strict`, `test_release_drive_drains_queue_in_order`, `test_cancel_removes`, `test_is_queued_reports_waiting_requester`). Rework `_pool_at` to drain with `try_pay(cap - value)`. Add:

```gdscript
func test_try_pay_spends_only_when_it_fits() -> void:
	var pool := _pool_at(5.0, 10.0, 0.0, 2.0)
	assert_true(pool.try_pay(4.0), "4 fits in 5")
	assert_eq(pool.value, 1.0, "5 minus 4")
	assert_false(pool.try_pay(2.0), "2 does not fit in 1")
	assert_eq(pool.value, 1.0, "a refused payment spends nothing")
	assert_eq(pool.spent, 9.0, "the drain's 5 plus the 4 paid")
	_complete()
```

Keep `test_regen_clamps_to_cap`, `test_driving_paid_first` and `test_drive_ignored_without_energy`, adjusted to the `{"drove"}` result. `test_spent_counts_drive_and_paid_requests` uses `try_pay`.

- [ ] **Step 2: Add the volley tests to `tests/battle/test_context.gd`**

Build each chariot with the existing helpers in that file. The parts are ready (cooldown_left 0), on a side with a pool of known value:

- `test_no_press_fires_nothing`: a ready Rocket and 10 energy. Ticking with `press_input = [false]` returns `[0]`, `cooldown_left` stays 0, and the pool is unchanged.
- `test_press_fires_every_ready_part`: two ready parts, costs 2 and 1, pool 10. One pressed tick returns `[2]`, the pool is 7 (plus one tick's regen), and both cooldowns are reset to `def.cooldown`.
- `test_press_pays_dearest_first_and_skips`: ready parts costing 3 (mounted second), 2 and 1, pool 4. The 3 and the 1 fire, the 2 stays ready with `cooldown_left == 0.0`, and the pool is 0.
- `test_unpaid_part_does_not_fire_later_without_press`: after the previous test, tick 120 times unpressed with regen. The 2-cost part has still not fired (its `PART_FIRED` count is unchanged).
- `test_press_skips_frozen_broken_and_spent`: one frozen, one broken and one with `charges_left == 0`, all with cooldown 0, plus pool 10. A press returns `[0]` and the pool is unchanged.
- `test_volley_cost_sums_ready_parts`: ready costs 3 and 1 plus a cooling-down 2. `volley_cost` is 4.
- `test_drive_is_paid_before_the_volley`: pool exactly `drive_cost * TICK + 2`, a ready 2-cost and a ready 3-cost part, driving and pressing. The chariot drives, the 2-cost fires, and the 3-cost doesn't.

- [ ] **Step 3: Run the tests to make sure the new ones fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: the new tests in `test_energy.gd` and `test_context.gd` FAIL (`try_pay` / `volley_cost` don't exist, or `tick` returns null).

- [ ] **Step 4: Implement**

- In `ChEnergy`: `try_pay`, and remove the queue.
- In `ChPartRuntime`: `is_ready`.
- In `ChBattleContext._tick_chariot(chariot, delta, direction, pressed) -> int`, the order is:
  1. Sample and tick cooldowns.
  2. `energy.tick` (regen, then the drive).
  3. If pressed, collect `is_ready()` parts, sort them stably by `-def.energy_cost`, `try_pay` each, and fire the paid ones with the existing fire/cooldown/charge/`_emit_fired` code.
  4. Then process, burn and drive as today.

  Return the fired count.
- In `break_part`: drop `energy.cancel` and its comment.
- Update the header comment of `ch_battle_context.gd` to describe the new tick order.

- [ ] **Step 5: Make the behaviour tests press**

Every `ctx.tick(TICK, [0.0, 0.0])` (or `[0.0]`) call in `test_behaviours_{melee,fire,ranged}.gd` and `test_context.gd` that expects a part to fire gets a press array: `ctx.tick(TICK, [0.0, 0.0], [true, true])`. Use a file-level `const PRESS := [true, true]`. Leave calls that test something with no fire unpressed. Fix any `test_part_runtime.gd` test that reads the removed queue.

- [ ] **Step 6: Run the tests**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `test_energy`, `test_context`, `test_behaviours_*` and `test_part_runtime` all pass. Fight-level tests in `test_battle.gd`, `tests/balance/*` and `test_battle_hud.gd` may still fail on the queue or on no-press fights. Note them for Tasks 2 and 4.

- [ ] **Step 7: Commit**

```bash
git add game/battle/ch_energy.gd game/battle/ch_part_runtime.gd game/battle/ch_battle_context.gd game/battle/ch_chariot_runtime.gd tests/battle/
git commit -m "feat(battle): one press fires a volley of ready parts; drop the energy queue"
```

---

### Task 2: The button in a fight: input, enemy press, dud and HUD

**Files:**
- Modify: `game/battle/ch_battle.gd` (`_add_input_actions`, a new `pressers` array, `_step`, new `ai_press`, `_player_press`)
- Modify: `game/battle/ch_enemy_ai.gd` (add `should_press`)
- Modify: `game/battle/ch_battle_hud.gd` (remove the `waiting` label, add the volley mark on the pips)
- Test: `tests/battle/test_battle.gd`, `tests/battle/test_battle_hud.gd`, a new `tests/battle/test_enemy_press.gd`

**Interfaces:**
- Consumes: Task 1's `ChBattleContext.tick(..., press_input) -> Array[int]`, `volley_cost`, and `ChPartRuntime.is_ready`.
- Produces:
  - `ChBattle.pressers: Array = [Callable(), Callable()]`. Each valid entry is `func(battle: ChBattle, side: int) -> bool` and replaces that side's press. The defaults are `_player_press()` for side 0 and `ai_press(1)` for side 1, matching `drivers`.
  - `ChBattle.ai_press(side: int) -> bool`.
  - `ChEnemyAI.should_press(chariot: ChChariotRuntime, target_x: float, own_half: float, target_half: float) -> bool`. Constant `PRESS_SHARE := 0.6`.
  - `ChBattleHud.show_state(player, enemy, volley_cost: int = 0)`.

- [ ] **Step 1: Write the failing tests**

`tests/battle/test_enemy_press.gd` (pure: hand-built `ChChariotRuntime` with `ChPartRuntime`s and fake bodies, the way `test_part_runtime.gd` builds them):

- `test_no_ready_parts_never_press`: everything is cooling down, and the pool is at cap. Returns false.
- `test_full_pool_presses`: one ready Rocket that is out of reach and facing away, with the pool at cap. Returns true.
- `test_in_reach_and_enough_energy_presses`: a ready Mace (reach 6) with the target 6 + halves away. With the pool at 60% of the volley cost it returns true; at 50% it returns false.
- `test_out_of_reach_melee_waits`: a ready Mace with the target 100 cells away and the pool at 80% of cap. Returns false.
- `test_ranged_part_counts_in_reach_when_facing`: a ready Rocket (proximity_range 0) facing the target returns true at 60%. The same part facing away returns false.

`tests/battle/test_battle.gd`:

- `test_never_press_fires_nothing`: a fight with `pressers = [func(_b, _s): return false, func(_b, _s): return false]` runs 120 ticks, and no `PART_FIRED` event appears on the bus.
- `test_held_key_fires_once`: inject `Input.action_press(&"fire")` before the first tick and keep it held for 120 ticks with a ready Chainsaw (cooldown 0.75). Exactly one `PART_FIRED` from side 0. Release it in the test's teardown.
- `test_dud_press_nudges_hull`: side 0 presses every tick with every part cooling down. `ChJuice.of(battle.player.chassis_visual).scale_spring.velocity` is non-zero after the press tick.

`tests/battle/test_battle_hud.gd`:

- Replace the "parts waiting" assertions. The HUD has no `waiting` node, and `show_state(p, e, 4)` with 6 lit pips colours pips 3–6 with `VOLLEY` (the four lit pips the volley would spend, counted from the top of the lit run) and the rest `ACCENT`.

- [ ] **Step 2: Run them to make sure they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: the new tests FAIL (`should_press`, `pressers` and `VOLLEY` don't exist).

- [ ] **Step 3: Implement**

- `_add_input_actions` adds an action `fire` bound to `KEY_SPACE` when it's missing (`InputMap.add_action` first).
- `_player_press()` returns `Input.is_action_just_pressed(&"fire")`.
- `_step` builds `presses` from `pressers` the same way it builds `drives`, and passes both to `ctx.tick`. When `presses[0]` is true and the returned `fired[0] == 0`, it plays `Feedback.play(&"nudge", player.chassis_visual)`. Feedback is visual only and must be skipped when `chassis_visual` isn't valid.
- `_hud_tick` passes `ctx.volley_cost(player)`.
- In `should_press`:
  - Reach uses `ChEnemyAI.reach`'s per-part rules: Harpoon `HARPOON_RANGE`, otherwise `proximity_range`, and 0 means ranged.
  - A melee part is in reach when `absf(dx) <= range + own_half + target_half`.
  - A ranged part is in reach when `signf(part.facing().x) == signf(dx)`.
- HUD: delete `waiting`. Add `const VOLLEY := Color("#ffd166")`. `_energy(pool, volley_cost)` paints the top `volley_cost` of the lit pips `VOLLEY`. Update the header comments that mention the queue.

- [ ] **Step 4: Fix the remaining fight tests**

Fight-level tests in `test_battle.gd` that expect the player to deal damage without pressing (for example `test_chain1_cut_ignites_and_pays_energy_in_a_real_fight` and `test_simultaneous_death_is_loss`) set `battle.pressers[0] = func(b, s): return b.ai_press(s)`. Check each test's comment for what it pins.

- [ ] **Step 5: Run the tests**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: everything passes except `tests/balance/*`, which Task 4 fixes.

- [ ] **Step 6: Commit**

```bash
git add game/battle/ch_battle.gd game/battle/ch_enemy_ai.gd game/battle/ch_battle_hud.gd tests/battle/
git commit -m "feat(battle): Space fires the volley; enemy press rule, dud nudge, volley mark on the pool"
```

---

### Task 3: Glowing outline on ready parts

**Files:**
- Modify: `game/battle/ch_textures.gd` (add `outline`)
- Modify: `game/battle/ch_chariot_builder.gd` (add an `Outline` sprite to each triggered part's body)
- Modify: `game/battle/ch_part_runtime.gd` (`var outline: Sprite2D = null`)
- Modify: `game/battle/ch_battle.gd` (`_show_ready()` called from `_step` after `ctx.tick`)
- Test: `tests/battle/test_builder.gd`, `tests/battle/test_battle.gd`

**Interfaces:**
- Consumes: `ChPartRuntime.is_ready()` (Task 1).
- Produces:
  - `ChTextures.outline(source: Image, colour: Color) -> ImageTexture`: an image 2 px larger on each axis. Each transparent pixel with an opaque 4-neighbour in `source` (offset by 1) is `colour`, and everything else is transparent.
  - `ChPartRuntime.outline`: the sprite, which is null for passive parts.
  - `ChBattle.READY_GLOW := Color(2.4, 2.0, 0.6)`: an HDR colour above 1, so the battle's `hdr_2d` lets it glow.
  - `ChBattle.READY_PULSE_HZ := 2.0`.

- [ ] **Step 1: Write the failing tests**

- `test_builder.gd` `test_triggered_parts_get_an_outline`: after building a chariot with a Rocket and a Wheel, the Rocket's `outline` is a `Sprite2D` child of its body, starts hidden and has a texture 2 px wider and taller than the part. The Wheel's `outline` is null.
- `test_builder.gd` `test_outline_texture_rings_the_shape`: `ChTextures.outline` of a 3×3 opaque image is 5×5. Pixel (0,2) is opaque, pixel (0,0) (a corner, with no 4-neighbour) is transparent, and pixel (2,2) is transparent.
- `test_battle.gd` `test_outline_shows_while_ready`: in a real fight with presses off, once the Rocket's cooldown runs out its `outline.visible` is true. With a single-tick press forced via `pressers`, `outline.visible` is false on the next tick.

- [ ] **Step 2: Run them to make sure they fail**

Expected: FAIL (there's no `outline`).

- [ ] **Step 3: Implement**

- The builder creates the sprite when `def.cooldown > 0`, centred, with `z_index = -1` under the part's Visual and `visible = false`.
- `_show_ready()` sets each live part's `outline.visible = part.is_ready()`, and while it's visible sets `modulate = READY_GLOW * (0.75 + 0.25 * sin(TAU * READY_PULSE_HZ * ctx.time))` with alpha 1. Mirrored parts flip the sprite the same way the builder flips their Visual.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: the new tests pass, and nothing new fails.

- [ ] **Step 5: Look at it**

Run `godot --headless --path . --script res://tools/screenshot.gd` (or the in-game battle) and check that ready parts show a bright rim and no fill tint. Adjust `READY_GLOW` if the rim reads as white.

- [ ] **Step 6: Commit**

```bash
git add game/battle/ch_textures.gd game/battle/ch_chariot_builder.gd game/battle/ch_part_runtime.gd game/battle/ch_battle.gd tests/battle/
git commit -m "feat(battle): ready parts glow with an outline"
```

---

### Task 4: Press policies in the balance runner

**Files:**
- Modify: `tools/balance/ch_balance_drivers.gd` (add `PRESS_POLICIES`, `make_press`)
- Modify: `tools/balance/ch_balance_scenario.gd` (`press` key, like `drive`)
- Modify: `tools/balance/ch_balance_matchup.gd` (`var press: PackedStringArray = ["ai", "ai"]`)
- Modify: `tools/balance/run.gd` (set `battle.pressers` from the matchup)
- Modify: `tools/balance/ch_fight_stats.gd` (new metrics)
- Modify: `tools/balance/README.md`
- Test: `tests/balance/test_scenario.gd`, `tests/balance/test_fight_stats.gd`

**Interfaces:**
- Consumes: `ChBattle.pressers`, `ai_press` (Task 2), `ChPartRuntime.is_ready`, and `ChBattleContext.volley_cost`.
- Produces:
  - `ChBalanceDrivers.PRESS_POLICIES := ["ai", "mash", "never"]`.
  - `ChBalanceDrivers.make_press(policy: String) -> Callable`. `mash` returns true every tick and `never` returns false.
  - Scenario key `"press": {"player": ..., "enemy": ...}`, defaulting to `ai`/`ai`. Unknown policies are rejected with the same error shape as `drive`.
  - Per-part metric `seconds_ready_unfired`, which replaces `seconds_waiting`.
  - Per-side metric `energy_starved_seconds`: ticks where the side has a ready part whose cost exceeds `energy.value`.

- [ ] **Step 1: Write the failing tests**

- `test_scenario.gd`: `press` parses, defaults to `["ai","ai"]`, and rejects `"press": {"player": "spam"}` with an error naming `press.player`.
- `test_fight_stats.gd`: replace the queue-based waiting assertions. With `press` `never` on both sides, every triggered part's `seconds_ready_unfired` is at least the fight length minus its first cooldown, and `firings` is 0.

- [ ] **Step 2: Run them to make sure they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: the new `tests/balance` assertions FAIL.

- [ ] **Step 3: Implement it, and update the README schema table and metric list**

- [ ] **Step 4: Run the tests and a smoke run**

Run: `godot --headless --path . --script res://tests/run_tests.gd`, then `tools/balance/run.sh --suite smoke`.
Expected: `0 failed`, and smoke exits 0.

- [ ] **Step 5: Commit**

```bash
git add tools/balance/ch_balance_drivers.gd tools/balance/ch_balance_scenario.gd tools/balance/ch_balance_matchup.gd tools/balance/run.gd tools/balance/ch_fight_stats.gd tools/balance/README.md tests/balance/
git commit -m "feat(balance): press policies ai, mash, never and ready-unfired metrics"
```

---

### Task 5: Outlined hulls with mass, grip and drive style

**Files:**
- Modify: `game/data/ch_body_def.gd` (new fields plus `copy()`)
- Modify: `game/battle/ch_textures.gd` (add `polygon`)
- Modify: `game/battle/ch_chariot_builder.gd:30` (chassis texture and physics)
- Modify: `game/garage/ch_pit_piece.gd:31-40` (draw the outline)
- Modify: `tests/ch_test.gd:102-118` and `tools/balance/ch_balance_scenario.gd` `_body_with_hp`, so both use `copy()`
- Test: `tests/battle/test_builder.gd`, `tests/data/test_catalog.gd`

**Interfaces:**
- Produces on `ChBodyDef`:
  - `outline: PackedVector2Array = []`: convex polygon in body-local cells. When it's empty, the hull is the `size` box.
  - `mass: float = 0.0`, `friction: float = 0.0` and `restitution: float = -1.0`. 0 or -1 means the engine default is left alone.
  - `drive_style: StringName = &""`: `&"brawler"`, `&"kiter"` or empty.
  - `type_name: String = ""`: "Wedge", "Tower" or "Barge", shown in the garage.
  - `copy() -> ChBodyDef`: field-by-field (see the existing `_body_with_hp` note on why `duplicate()` can't be used).
- Produces `ChTextures.polygon(outline: PackedVector2Array, size: Vector2i, colour: Color, mirror_x: bool = false) -> ImageTexture`. A pixel is opaque when its centre minus `size/2` (x negated when mirrored) is inside the outline (`Geometry2D.is_point_in_polygon`). The rim is darkened by 0.3 like `box`.

- [ ] **Step 1: Write the failing tests**

- `test_builder.gd` `test_outline_hull_is_drawn_from_polygon`: a body with a right triangle outline (`(-5,5),(5,5),(-5,-5)`) on a 10×10 `size`. The chassis texture's pixel (8,1) is transparent and (1,8) is opaque.
- `test_builder.gd` `test_mirrored_hull_flips_nose`: the same body built with `mirror_x = true` has (1,1) transparent and (8,8) opaque. *(Review Focus 4)*
- `test_builder.gd` `test_body_physics_applied`: `mass = 50`, `friction = 0.2`, `restitution = 0.4` reach `runtime.chassis`. Defaults leave the engine's own values alone.
- `test_catalog.gd` `test_body_copy_keeps_every_field`: for each catalog body, `copy()` equals the original on `id`, `hp`, `outline`, `mass`, `friction`, `restitution`, `drive_style`, `type_name` and `slots`. *(Review Focus 5)*
- `test_catalog.gd` `test_outline_matches_size`: for every body with an outline, the outline's bounding box is `size` centred on the origin.

- [ ] **Step 2: Run them to make sure they fail**

Expected: FAIL (the fields and `polygon` don't exist).

- [ ] **Step 3: Implement**

- The builder uses `ChTextures.polygon(def.outline, def.size, def.color, mirror_x)` when the outline isn't empty, else `box`, and applies the non-default physics props to the chassis before `add_child`.
- The pit draws `draw_colored_polygon(outline * ChGarage.ZOOM, color)` plus a darker `draw_polyline` when the outline isn't empty, and keeps the rectangle otherwise.
- Both `_body_with_hp` helpers call `copy()` and then set `hp`.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 failed` apart from `tests/balance` failures already tracked for later tasks, if any. No body data has changed yet.

- [ ] **Step 5: Commit**

```bash
git add game/data/ch_body_def.gd game/battle/ch_textures.gd game/battle/ch_chariot_builder.gd game/garage/ch_pit_piece.gd tests/ch_test.gd tools/balance/ch_balance_scenario.gd tests/
git commit -m "feat(bodies): outline hulls with mass, grip and drive style fields"
```

---

### Task 6: Brawler and kiter driving

**Files:**
- Modify: `game/battle/ch_enemy_ai.gd` (`decide` gains `style`)
- Modify: `game/battle/ch_battle.gd` (`ai_drive` passes `me.body_def.drive_style`)
- Test: `tests/battle/test_battle.gd` (pure `decide` tests can go in `tests/battle/test_enemy_press.gd`, renamed `test_enemy_ai.gd`)

**Interfaces:**
- Produces `ChEnemyAI.decide(self_x, target_x, preferred_range, own_half_width := 0.0, target_half_width := 0.0, style: StringName = &"") -> float` and `const KITE_BACKOFF := 8.0` (cells, Proposed).
  - `&"brawler"`: always `signf(dx)`, so it keeps pushing on contact.
  - `&"kiter"`: with `hold = preferred_range + halves`, it drives away when `absf(dx) < hold - KITE_BACKOFF`, toward when `absf(dx) > hold`, and otherwise returns 0. An INF range holds still.
  - Empty: today's rule, unchanged.

- [ ] **Step 1: Write the failing tests**

- `test_brawler_keeps_pushing`: `decide(0, 20, 6, 15, 15, &"brawler") == 1.0`. The hulls overlap at 20 apart and it still pushes.
- `test_kiter_backs_off_inside_reach`: `decide(0, 20, 30, 10, 10, &"kiter") == -1.0`.
- `test_kiter_holds_in_band`: `decide(0, 45, 30, 10, 10, &"kiter") == 0.0`.
- `test_kiter_closes_from_far`: `decide(0, 200, 30, 10, 10, &"kiter") == 1.0`.
- `test_unstyled_unchanged`: the existing `test_ai_holds_off_the_hulls` still passes.

- [ ] **Step 2: Run them to make sure they fail**, then implement and wire `ai_drive`.

- [ ] **Step 3: Run the tests**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: the new tests pass, with no new failures.

- [ ] **Step 4: Commit**

```bash
git add game/battle/ch_enemy_ai.gd game/battle/ch_battle.gd tests/battle/
git commit -m "feat(ai): brawler and kiter drive styles"
```

---

### Task 7: Wedge, Tower and Barge data, and the cook on the Barge

**Files:**
- Modify: `game/data/bodies/cutter.tres`, `dozer.tres`, `corsair.tres`
- Modify: `game/data/enemies/dozer_cook.tres`
- Modify: `tests/ch_test.gd` `_fight_catalog` (override the cook's body, which is now `corsair`)
- Modify: `game/garage/ch_garage.gd:496-507` (the body label shows `"%s · %s" % [display_name, type_name]`)
- Modify: `tools/balance/suites/demo.json`, `demo-matrix.json`, `mirror.json` (re-place reference-build parts where the slot moved, so melee still reaches)
- Test: `tests/data/test_catalog.gd`, new `tests/battle/test_bodies.gd`

**Interfaces:**
- Consumes: the Task 5 fields and the Task 6 styles.

Starting data (Proposed; Task 8 tunes the physics):

| Body | type_name | size | outline (cells, +x forward) | mass, friction, restitution | drive_style | Slots |
|---|---|---|---|---|---|---|
| cutter | Wedge | 34×9 | `(-17,-4.5) (4,-4.5) (17,3.5) (17,4.5) (-17,4.5)`: nose slopes down to the ground at the front | default, 1.2, 0.0 | brawler | 4, same order. Wheels on the bottom edge, both tops under the slope line |
| dozer | Tower | 22×30 | `(-11,15) (11,15) (8,-15) (-8,-15)`: tapers toward the top | default, default, 0.0 | kiter | 6, same order. Wheels on the bottom, tops in the upper half |
| corsair | Barge | 52×10 | `(-26,-5) (24,-5) (26,-3) (26,5) (-26,5)` | 2× its default mass, 1.0, 0.0 | brawler | 7, same order. Three top slots at the front |

The cook keeps its parts. Re-slot them onto Corsair indices so Hearth and the Mace sit at the front top (`[6]`, `[5]`), the Harpoon at `[4]`, and the wheels at `[0]`, `[1]`. `max_hp` stays 1800.

- [ ] **Step 1: Write the failing tests**

- `test_catalog.gd` `test_spec_bodies`: each body's `type_name`, `drive_style` and slot count are as in the table, and its outline is non-empty.
- `test_catalog.gd`: the existing wheel-mount check also asserts each wheel slot's y equals the outline's max y at that x, within 0.5 of a cell.
- `test_catalog.gd` `test_slots_inside_outline`: every slot lies within 1 cell of the outline (inside, or on its edge).
- `test_bodies.gd` `test_each_body_drives_the_arena`: a real fight with `pressers` set to never and side 0 driven by a constant `1.0`. For each body, the chassis moves at least 100 cells within 600 ticks, and `|rotation| < PI/2` throughout.
- `test_bodies.gd` `test_each_body_lands_upright`: after 120 idle ticks, each body's `|rotation| < 0.3`.
- `test_catalog.gd` `test_cook_is_a_barge`: `dozer_cook.tres` has `body_id == &"corsair"`, and its Hearth and Mace sit in front top slots.

- [ ] **Step 2: Run them to make sure they fail**, then write the data.

- [ ] **Step 3: Fix the tests that pinned old body numbers or slots**

For example `test_garage.gd` `test_no_hint_labels`, `test_main_draw_panel`, and fight tests that size the enemy through the `dozer` override. Read each test's comment first.

- [ ] **Step 4: Run the tests and `--suite smoke`**

Expected: `0 failed`, and smoke has 0 aborted.

- [ ] **Step 5: Commit**

```bash
git add game/data/bodies/ game/data/enemies/dozer_cook.tres game/garage/ch_garage.gd tests/ tools/balance/suites/demo.json tools/balance/suites/demo-matrix.json tools/balance/suites/mirror.json
git commit -m "feat(bodies): Wedge, Tower and Barge shapes; the cook drives a Barge"
```

---

### Task 8: The bodies suite, and tuning the shapes

**Files:**
- Modify: `tools/balance/ch_balance_scenario.gd` (side key `plain_hull`)
- Create: `tools/balance/suites/bodies.json`, `tools/balance/suites/bodies-box.json`
- Modify: `game/data/bodies/*.tres` (tuning only)
- Modify: `tools/balance/README.md`
- Test: `tests/balance/test_scenario.gd`

**Interfaces:**
- Produces the side key `"plain_hull": true` (inline `body_id` sides only). The side's body is `copy()`'d with `outline` cleared and id `<id>_box`, and joins the matchup catalog the way the `hp` override does.

Suites:

- `bodies`: all 9 ordered pairs of cutter, dozer and corsair, 8 seeds each, with `drive` and `press` both `ai`.
  - Each side carries two wheels plus a Rocket and a Chainsaw on the body's two highest front-facing non-wheel slots, with the Chainsaw at the front.
  - The Chainsaw's 14-cell reach and the Rocket's flat shot are what make height matter.
- `bodies-box`: the same suite with `"plain_hull": true` on both sides.

- [ ] **Step 1: Test `plain_hull`**

In `test_scenario.gd`, a side with `plain_hull` yields a body whose `outline` is empty and whose other fields match the original. `plain_hull` on a `layout` side is rejected.

- [ ] **Step 2: Implement it, then run both suites**

Run: `tools/balance/run.sh --suite bodies --out "$TMPDIR/bodies.json"` and the same for `bodies-box`, then `python3 tools/balance/analysis/matrix.py <out>` for each.

- [ ] **Step 3: Tune until the spec's body criteria hold**

Tune the outlines, mass, friction, restitution, `KITE_BACKOFF` and slot positions (count and order fixed):

- No body wins more than 65% overall.
- Each body wins one matchup at ≥ 60% and loses one at ≥ 60%.
- Cutter against dozer shows the dozer's `flipped_seconds` > 0 in most seeds.
- The `bodies` matrix is further from 50% (mean absolute deviation of the pair win rates) than `bodies-box`.

Record each try and its result in a short table at the end of `tools/balance/README.md` under "Body tuning log". Keep only the final numbers in the `.tres` files.

- [ ] **Step 4: Add `expect` ranges to `bodies.json` that pin the final result**, then rerun it. Expected: exit 0.

- [ ] **Step 5: Run the tests**

Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add tools/balance/ch_balance_scenario.gd tools/balance/suites/bodies.json tools/balance/suites/bodies-box.json tools/balance/README.md game/data/bodies/ tests/balance/
git commit -m "tune(bodies): bodies suite with a box control; shapes tuned to their matchups"
```

---

### Task 9: Re-balance for presses

**Files:**
- Modify: `game/data/parts/*.tres` (`energy_cost`, `cooldown`, `damage`), `game/battle/ch_enemy_ai.gd` (`PRESS_SHARE`), `game/data/enemies/dozer_cook.tres` (`max_hp`)
- Modify: `tools/balance/suites/demo.json`, `demo-matrix.json` (add `mash` and `never` variants and `expect` ranges)
- Modify: `docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md` (append a dated section with the results)

- [ ] **Step 1: Measure**

Run `demo` with the player's `press` set to `ai`, then to `mash`, then to `never`, and `demo-matrix` with `ai`.

- [ ] **Step 2: Tune until the spec's §4 criteria hold**

- `ai` beats `mash` by ≥ 15 points of win rate for every build.
- `never` wins no fight (a draw is fine).
- Every build stays within 0.35–0.65 in the round-robin.
- Standalone parts stay at about 10–20 DPS against `dozer_cook`.

If `mash` keeps up with `ai`, the energy pressure is too low: lower body regen or raise costs before touching cooldowns. Keep the payoff parts (Ember, Shatter, Ignition) below their builds.

- [ ] **Step 3: Pin it**

Add `expect` ranges for `win_rate` and `mean_fight_seconds` to `demo.json`, plus a `demo-mash` scenario that expects the lower win rate. Rerun. Expected: exit 0.

- [ ] **Step 4: Run the tests**

Fix the tests that pin re-tuned numbers (`test_catalog.gd` `test_spec_numbers`, and the cooldown-dependent behaviour tests), following their comments. Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add game/data/parts/ game/battle/ch_enemy_ai.gd game/data/enemies/dozer_cook.tres tools/balance/suites/demo.json tools/balance/suites/demo-matrix.json docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md tests/
git commit -m "tune(balance): re-cost parts for the press volley"
```

---

### Task 10: Docs and tooltips

**Files:**
- Modify: `docs/design-doc/core-mechanics.md` §3.2, §3.3
- Modify: `game/ui/ch_keywords.gd` (`press` and `passive` entries)
- Modify: `game/data/parts/*.tres` `description` (prefix each line)
- Test: `tests/ui/test_keywords.gd`, `tests/ui/test_part_tooltip.gd`

**Interfaces:**
- Produces two `ChKeywords.ENTRIES`:
  - `&"press"`: name "Press", text "Fires when you press Space, if it's ready and you have the energy. Ready parts glow."
  - `&"passive"`: name "Passive", text "Works on its own. No press needed."

- [ ] **Step 1: Write the failing test**

`test_part_tooltip.gd` `test_every_line_is_press_or_passive`: every catalog part's every description line starts with `{press}` or `{passive}`. A part with `cooldown > 0` has at least one `{press}` line, and a part with `cooldown == 0` has none.

- [ ] **Step 2: Run it to make sure it fails**, then add the entries and prefix the lines.

The firing line of a triggered part is `{press}`. Hooks are `{passive}`: Rocket's Ignition, Chainsaw's Sparks, Mace's Shatter, and the self-ignite lines of Hearth and Ring. Ember, Freeze Charge, Strut and Wheel are `{passive}`.

- [ ] **Step 3: Rewrite `core-mechanics.md`**

- §3.2: "The player drives left and right and presses one button. A press fires every ready part's triggered ability; passive abilities run on their own. The enemy follows the same rules."
- §3.3: replace the FIFO-queue bullet with the volley rule (dearest first, skip what doesn't fit, unpaid parts stay ready).

- [ ] **Step 4: Run the tests**

Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add docs/design-doc/core-mechanics.md game/ui/ch_keywords.gd game/data/parts/ tests/ui/
git commit -m "docs: one-button rules in core mechanics and Press/Passive tooltips"
```
