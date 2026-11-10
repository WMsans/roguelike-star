# The Cook and the Arena Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lazy one-gun builds lose badly to the Cook, full builds face a hard fight, and part of
that difficulty comes from an arena of explosives, oil, acid and lava that reacts in the sim.

**Architecture:**
- The engine gains explosive materials. After each sim tick, `PixelWorld` scans the arena for
  burning explosive cells and detonates them through its existing `explode`.
- A blast lights the explosive cells it covers instead of removing them, so chains ripple from one
  tick to the next.
- Every blast is queued, and the game drains the queue once per fight tick. `ChHazards` turns
  material blasts into chariot damage and knockback.
- `ChArenaBuilder` lays one mirrored, hand-designed arena.
- The Cook, parts and arena are then tuned together with the balance runner.

**Tech Stack:** Godot 4 / GDScript; the `noita_engine` GDExtension (C++, rebuilt with
`addons/noita_engine/build.sh`); the headless test runner `tests/run_tests.gd`; the balance runner
`tools/balance/run.sh` and `tools/balance/analysis/*.py`.

**Spec:** `docs/superpowers/specs/2026-11-10-cook-and-arena-design.md`

## Global Constraints

- Tests: `godot --headless --path . --script res://tests/run_tests.gd` must end `0 failed`.
  If `tests/balance/*` report "did not run", run `godot --headless --path . --import` once first.
- After any C++ change, rebuild: `addons/noita_engine/build.sh`. A "Could not find type
  PixelWorld" error means the library didn't build or load.
- Runner fights go only through `tools/balance/run.sh`, which passes `--fixed-fps 60`.
- The Cook keeps the file and id `dozer_cook`, the Corsair body and its Hearth. It uses only catalog
  parts, at most two of each.
- The one-button rules don't change (`core-mechanics.md` §2).
- Spawns hang in air 30 cells above the surface (`ChArenaBuilder.SPAWN_ABOVE`).
- No liquid deeper than 1 cell on the driving line (the surface between x 140 and 340).
- A Rocket or Firebolt blast (`world.explode` from GDScript) deals no area damage to chariots. Only
  material blasts do.
- A blast takes chariot HP once, scaled by the hull's distance from the centre. Each part inside the
  radius loses integrity only.
- **Hazard damage** means HP lost to material blasts. Burn doesn't count. Lava wear only touches
  integrity, so it adds no HP.
- When an old test pins an old number or layout, read its comments for what it checks, then move
  its constants. Don't weaken the check.
- Commit after every task, adding only that task's files (never `git add -A`).

## Review Focus

1. **A chain bigger than the per-tick cap.** A 200-cell gunpowder pile must still detonate
   completely over later ticks, with nothing left lit but unexploded. Test in Task 1.
2. **A blast beside the concrete border** must not open the arena (indestructible cells are
   spared, and explosive cells next to them still go). Test in Task 1.
3. **A blast over a chariot with broken parts, or with a freed chassis,** must skip what is out of
   the fight and must not crash. Test in Task 3.
4. **One blast covering both chariots** charges each chariot's HP once. Test in Task 3.
5. **A mirrored arena under any seed.** The surface noise is mirrored too, so the left and right
   halves match cell for cell. Test in Task 4.

---

### Task 1: Explosive materials in the engine

**Files:**
- Modify: `addons/noita_engine/engine/core/material.h` (fields on `MaterialDef` and
  `CompiledMaterial`)
- Modify: `addons/noita_engine/engine/core/material.cpp` (`compiled_from` copies them)
- Modify: `addons/noita_engine/engine/core/particles.cpp` (`explode`: lights explosive cells instead
  of removing them)
- Modify: `addons/noita_engine/engine/godot/pixel_material.h/.cpp` (properties, `to_def`)
- Modify: `addons/noita_engine/engine/godot/pixel_world.h/.cpp` (detonation scan, blast queue,
  `take_blasts`)
- Test: `tests/engine/test_engine_additions.gd`

**Interfaces:**
- Produces:
  - `PixelMaterial.explode_radius: int` (default 0, meaning it doesn't explode) and
    `PixelMaterial.explode_power: float` (default 0).
  - `PixelWorld.take_blasts() -> Array`: each entry is
    `{"position": Vector2i, "radius": int, "power": float, "material": StringName}`. `material` is
    the detonated cell's material name, or `&""` for a blast from `explode()`. The call returns
    every blast since the last call and clears the queue.
  - `PixelWorld.explode(...)` keeps its signature and return value, and also queues its blast with
    `material &""`.
- Engine constant: `MAX_DETONATIONS_PER_TICK = 16`.

Rules:
- **The scan.** In `tick_world()`, after `sim->tick()` and before `particles->step()`, scan the
  arena rect (only when `arena` is set) row by row for cells whose material has
  `explode_radius > 0` and that carry `FLAG_BURNING`.
  - For each one, unless it lies within its own `explode_radius` of a centre already chosen this
    tick: set the cell to air, then run the same styled explode `PixelWorld::explode` uses, at that
    cell, with the material's radius and power. Queue the blast.
  - Stop after `MAX_DETONATIONS_PER_TICK` detonations. Cells passed over stay lit for later ticks.
  - Add a `// ponytail:` note on the full-arena scan: it costs O(arena) per tick, and a dirty-chunk
    list is the upgrade if it ever shows in a profile.
- **Blasts already start fires.** `PixelWorld::explode`'s style leaves fire in cleared cells
  (`EXPLODE_FIRE_CHANCE`), which covers the spec's "blasts start fires", so nothing new is needed
  for it.
- **Explosive cells inside a blast** (core `explode`) are not removed or thrown. They get
  `FLAG_BURNING`, and their temperature rises to at least their `ignite_temp`. Every other cell
  behaves exactly as today.

- [ ] **Step 1: Write the failing tests** in `tests/engine/test_engine_additions.gd`. Extend
  `_make_world` with a `gunpowder` (powder, `ignite_temperature` 150, `explode_radius` 3,
  `explode_power` 150) and a `tnt` (solid, `ignite_temperature` 250, `explode_radius` 10,
  `explode_power` 400).

```gdscript
func test_lit_tnt_detonates_and_reports() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 4, 4), &"tnt")
	world.take_blasts()
	world.explode(Vector2i(28, 32), 2, 100)   # covers TNT cells: lights them
	world.step(3)
	var blasts := world.take_blasts()
	var tnt := blasts.filter(func(b): return b["material"] == &"tnt")
	assert_true(blasts.any(func(b): return b["material"] == &"" and b["radius"] == 2), "explode() is reported")
	assert_true(tnt.size() >= 1, "lit TNT went off")
	assert_eq(tnt[0]["radius"], 10)
	assert_eq(world.count_materials(Rect2i(30, 30, 4, 4)).get(&"tnt", 0), 0, "the crate is gone")
	assert_eq(world.take_blasts().size(), 0, "take_blasts clears the queue")

func test_gunpowder_pile_chains_past_the_cap() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(10, 50, 40, 5), &"gunpowder")   # 200 cells
	world.explode(Vector2i(10, 52), 2, 50)
	world.step(120)
	assert_eq(world.count_materials(Rect2i(0, 0, 64, 64)).get(&"gunpowder", 0), 0, "every cell went")

func test_unlit_tnt_is_inert() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 4, 4), &"tnt")
	world.step(60)
	assert_eq(world.count_materials(Rect2i(30, 30, 4, 4)).get(&"tnt", 0), 16)
	assert_eq(world.take_blasts().size(), 0)

func test_chain_next_to_border_keeps_the_wall() -> void:
	var world := await _make_world(Rect2i(0, 0, 64, 64), &"concrete")
	world.fill_rect(Rect2i(0, 20, 6, 6), &"tnt")
	world.explode(Vector2i(4, 22), 2, 50)
	world.step(5)
	assert_eq(world.get_material_at(Vector2i(-1, 22)), &"concrete", "the border survives")
```

  `test_gunpowder_pile_chains_past_the_cap` also needs a fire material in the set, so that the
  gunpowder's own burn doesn't decide the result. If one is needed, add it as `ChTest.make_world`'s
  set does.

- [ ] **Step 2: Run them to verify they fail.**
  Run: `godot --headless --path . --script res://tests/run_tests.gd`
  Expected: the four tests fail (unknown property `explode_radius`, or no `take_blasts`).
- [ ] **Step 3: Implement the fields, `to_def`, the core `explode` change, the scan, the queue and
  `take_blasts`** as specified above.
- [ ] **Step 4: Rebuild and run all tests.**
  Run: `addons/noita_engine/build.sh && godot --headless --path . --script res://tests/run_tests.gd`
  Expected: `0 failed`. The existing Rocket, Firebolt and arena-wall tests pass unchanged, because no
  game material explodes yet.
- [ ] **Step 5: Commit** (`feat(engine): explosive materials, chained detonation and a blast queue`),
  including the rebuilt `bin/` library if it is tracked.

---

### Task 2: Gunpowder, TNT and acid in the game set

**Files:**
- Create: `game/materials/gunpowder.tres`, `tnt.tres`, `acid.tres`, `acid_sand.tres`,
  `acid_wood.tres`, `acid_gunpowder.tres`, `acid_tnt.tres`
- Modify: `game/materials/game_set.tres`
- Test: `tests/test_materials.gd`

**Interfaces:**
- Produces material names `&"gunpowder"`, `&"tnt"` and `&"acid"`.
  - Starting values (tuned in Task 6): gunpowder: powder, density 1.4, `ignite_temperature` 150,
    radius 3, power 150. TNT: solid, `collision_solid` true, `ignite_temperature` 250, radius 12,
    power 400. Acid: liquid, density 1.1, dispersion 3, a green colour.
  - Pick colours that read at a glance: gunpowder dark grey, TNT red, acid bright green with a
    little `emission`.
- Reactions: `a = &"acid"`, `b` each of sand, wood, gunpowder and tnt, `a_into = &"smoke"`,
  `b_into = &""` (air), `probability` 0.15.
- **Acid does not dissolve rock** (this departs from the spec's §1 table). The arena keeps acid in
  rock basins, and a seal that dissolves would empty the basin on the first tick. Concrete and rock
  hold acid.

- [ ] **Step 1: Write failing tests** in `tests/test_materials.gd`, in the file's existing style:
  - `test_game_set_has_explosives`: the set holds gunpowder and tnt, with `explode_radius` > 0.
  - `test_acid_eats_sand_not_rock`: in `make_world`, a 6×6 acid pool sits on sand inside a rock
    basin. After 120 ticks, the sand under it is fewer than before, and the rock count is unchanged.
  - `test_fire_sets_off_tnt`: fire cells beside a 4×4 TNT crate. Within 120 ticks, `take_blasts()`
    holds a `&"tnt"` blast.
- [ ] **Step 2: Run to verify they fail.** Expected: the three tests fail.
- [ ] **Step 3: Add the `.tres` files and list them in `game_set.tres`.**
- [ ] **Step 4: Run all tests.** Expected: `0 failed`.
- [ ] **Step 5: Commit** (`feat(materials): gunpowder, TNT and acid`).

---

### Task 3: Blasts hurt and push chariots

**Files:**
- Create: `game/battle/ch_hazards.gd`
- Modify: `game/battle/ch_battle_context.gd` (`tick` drains the blasts first)
- Modify: `game/battle/ch_event.gd` (`HAZARD_HIT`)
- Modify: `game/battle/ch_battle_feedback.gd` (a `HAZARD_HIT` plays the same struck feedback and
  damage popup as a `HIT` on that chariot)
- Modify: `tools/balance/ch_fight_stats.gd`, `tools/balance/analysis/summary.py`,
  `tools/balance/README.md` (metrics)
- Test: `tests/battle/test_hazards.gd` (new), `tests/balance/test_fight_stats.gd`

**Interfaces:**
- Consumes: `PixelWorld.take_blasts()` from Task 1.
- Produces:
  - `class_name ChHazards extends RefCounted`.
  - `const BLAST_DAMAGE := {&"tnt": 150, &"gunpowder": 6}`: HP at the centre, falling linearly to
    0 at the radius. A material that isn't listed deals 0.
  - `const BLAST_WEAR := 0.5`: the share of the blast's damage each part inside the radius loses
    as integrity.
  - `const BLAST_IMPULSE := 60.0`: impulse per unit of `power` at the centre, with the same falloff.
  - `static func apply(ctx: ChBattleContext, blasts: Array) -> void`.
  - `ChEvent.HAZARD_HIT: StringName = &"hazard_hit"`. Its `data` is `{"target_side": int,
    "hp_damage": int, "material": StringName, "hp_after": int}`, with `event.source` null and
    `event.position` the blast centre.
  - Fight-stats side keys: `hazard_damage` (int, HP lost) and `killed_by_hazard` (bool: the side's
    HP reached 0 on a `HAZARD_HIT`).

Rules for `apply`, per blast:
- Skip a blast whose `material` is `&""`.
- Skip a chariot whose chassis isn't valid or that is already dead.
- Measure the distance from the blast centre to the hull box (`ChBattle.hull_box`'s rule: the
  nearest point of the hull rect). If it's within the radius:
  - The falloff is `1 - d / radius`.
  - HP drops once by `roundi(BLAST_DAMAGE * falloff)`, never below 0.
  - Each unbroken part whose `anchor_world()` lies within the radius loses
    `roundi(that damage * BLAST_WEAR)` integrity, and breaks through `chariot.break_part` at 0.
  - The chassis gets `apply_impulse(dir * power * BLAST_IMPULSE * falloff)` at its centre, where
    `dir` points from the blast centre to the chassis. If the two coincide, push straight up.
  - Emit `HAZARD_HIT`.
- `ChBattleContext.tick` calls `ChHazards.apply(self, world.take_blasts())` first, when `world`
  isn't null.

- [ ] **Step 1: Write failing tests** in `tests/battle/test_hazards.gd`. Build the fight rig the
  way `tests/battle/test_context.gd` does, and feed `ChHazards.apply` hand-made blast dicts, so
  these tests need no TNT:
  - `test_material_blast_costs_hp_once`: a TNT blast centred on the hull with radius 12. HP drops
    by exactly 150. Every part within 12 loses 75 integrity. One `HAZARD_HIT` is emitted.
  - `test_falloff_halves_at_half_radius`: centre 6 cells off the hull box edge. HP drops by 75.
  - `test_script_blast_deals_nothing`: material `&""`. HP is unchanged and nothing is emitted.
  - `test_one_blast_both_chariots_each_once`: a blast covering both hulls. Each chariot loses its
    own amount exactly once.
  - `test_broken_part_and_freed_chassis_skipped`: one broken part, plus the other chariot's
    chassis freed. No error, and the broken part's integrity is unchanged.
  - `test_blast_pushes_away`: after `apply` and one physics step, the chassis velocity's x has the
    sign of (chassis x − blast x).
  - In `tests/balance/test_fight_stats.gd`, `test_hazard_damage_and_kill`: a `HAZARD_HIT` that
    takes the side to 0 sets `killed_by_hazard` true, and `hazard_damage` equals its `hp_damage`.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement `ChHazards`, the tick hook, the event, the feedback, and the stats keys.**
  `summary.py` prints `haz=<hazard_damage>` per side and `hazkill=<count>` per matchup. The README's
  metrics table lists both keys.
- [ ] **Step 4: Run all tests.** Expected: `0 failed`.
- [ ] **Step 5: Commit** (`feat(battle): material blasts damage and push chariots`).

---

### Task 4: The arena

**Files:**
- Modify: `game/battle/ch_arena_builder.gd`
- Test: `tests/battle/test_arena.gd`, `tests/battle/test_bodies.gd` (constants only)

**Interfaces:**
- Consumes: the material names from Task 2.
- Produces: `ChArenaBuilder.build(world, rng_seed) -> Dictionary`, unchanged in shape.
  - `SPAWN_RIGHT_X` becomes 309, so that the spawns mirror around `x ↔ 479 - x`.
  - New const `MIRROR_X := 240`.

Layout. Every left-half piece is mirrored at `479 - x`. The noise surface is computed for
`x < 240`, and `surface[x] = surface[479 - x]` for the right half. Starting coordinates are tuned
in Task 6:

| Piece | Left-half placement | Notes |
|---|---|---|
| Lava under a crust | x 210–239, top = surface + 4, 6 deep | Spans the middle once mirrored (210–269) |
| TNT crate | x 118–123, top = surface + 3, 6×6 | Clear of the spawn hull (144–196) |
| Gunpowder seam | x 124–150, 1 cell at surface + 2 | Fuse toward the crate; stops before the spawn |
| Oil tank on a ledge | rock shelf x 1–40, y SURFACE_Y − 26, 4 thick; wood walls 2 wide; oil 30×8 inside | Joined to the arena wall |
| Acid basin | rock mound x 80–100 rising 8 above the surface, a 12×5 acid basin in its top with a 1-cell rock lip | A blast breaks the lip |
| Dig room | sand x 150–209 down to `ROCK_TOP` | Already sand; nothing placed |

Remove the old water strips (they sat over the new lava) and the old lava pools. Keep or drop the
wood patches as Task 6 finds.

- [ ] **Step 1: Write failing tests** in `tests/battle/test_arena.gd`. Add `&"tnt"`,
  `&"gunpowder"`, `&"acid"` and `&"oil"` to `TERRAIN`, and set `SPAWN_RIGHT_X` to 309.
  - `test_arena_is_mirrored`: for seeds 12345 and 7, every cell `(x, y)` with `x < 240` matches
    `(479 - x, y)` (`get_material_at`).
  - `test_set_pieces_present`: the arena holds TNT ≥ 72 cells (two 6×6 crates), gunpowder > 0,
    acid > 0, oil > 0, and lava within 8 cells under the surface at x 240.
  - `test_no_deep_liquid_on_driving_line`: for x 140–340, no column has 2 or more liquid cells
    (water, oil, acid, lava) touching from the surface down.
  - `test_nothing_explodes_on_its_own`: build, then step 600 ticks with no chariots. `take_blasts()`
    holds no TNT or gunpowder blast.
  - Keep `test_no_caves`, `test_spawns_above_surface` and `test_walls_concrete_and_indestructible`,
    with constants moved as needed.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Rewrite `ChArenaBuilder.build`** as in the table. Update the header comment to
  describe the new arena.
- [ ] **Step 4: Run all tests.** Expected: `0 failed`, including
  `test_bodies.gd` `test_each_body_drives_the_arena` and
  `test_tower_drives_upright_on_slow_frames`.
  - If a body can't drive off its spawn, move set pieces, not the bodies.
- [ ] **Step 5: Commit** (`feat(arena): mirrored arena with explosives, oil, acid and a lava crust`).

---

### Task 5: Runner support for the new goals

**Files:**
- Modify: `game/battle/ch_battle.gd` (`ai_drive` takes a style)
- Modify: `tools/balance/ch_balance_drivers.gd` (`kite`, `brawl`)
- Create: `tools/balance/suites/lazy.json`
- Modify: `tools/balance/suites/demo.json` (no-wheel twins)
- Modify: `tools/balance/analysis/summary.py` (`--wheel-gap`), `tools/balance/README.md`
- Test: `tests/balance/test_scenario.gd`

**Interfaces:**
- Produces:
  - `ChBattle.ai_drive(side: int, style: StringName = &"") -> float`. An empty `style` uses
    `me.body_def.drive_style`, as today.
  - `ChBalanceDrivers.POLICIES := ["ai", "hold", "charge", "kite", "brawl"]`. `kite` and `brawl`
    call `ai_drive(side, &"kiter")` and `ai_drive(side, &"brawler")`.
  - `lazy.json`: 16 scenarios named `lazy/<part>` and `lazy/<part>-nowheels`, for the 8 damaging
    parts: cutter_chainsaw, cutter_rocket, ice_cream_mace, flamethrower, hearth, ring_of_fire,
    firebolt_launcher and corsair_harpoon.
    - Each is a Corsair with the part on `[6]`, wheels on `[0]` and `[1]` unless the name says
      `-nowheels`, `press.player: mash`, against `res://game/data/enemies/dozer_cook.tres`, with
      seeds 1–8.
    - `expect`: `win_rate` [0, 0.125] and `aborted` [0, 0].
  - `demo.json` gains `vs-cook-<build>-nowheels` for each of the five builds: the same parts
    without slots `[0]` and `[1]`, under `ai` presses.
  - `summary.py --wheel-gap out.json` prints, per build, the win rate with and without wheels and
    the gap.

- [ ] **Step 1: Write the failing test** in `tests/balance/test_scenario.gd`:
  `test_kite_and_brawl_policies_parse`. A scenario with `"drive": {"player": "kite"}` parses with no
  errors, and one with `"drive": {"player": "glide"}` reports an error.
- [ ] **Step 2: Run to verify it fails.**
- [ ] **Step 3: Implement the style parameter and the two policies, write `lazy.json`, the demo
  twins and `--wheel-gap`, and update the README's suite list and policy table.**
- [ ] **Step 4: Run tests, then the new suite once (it fails its `expect` today, which is fine).**
  - Run: `godot --headless --path . --script res://tests/run_tests.gd` → `0 failed`.
  - Run: `tools/balance/run.sh --suite lazy --out /tmp/lazy.json; python3 tools/balance/analysis/summary.py /tmp/lazy.json`
    → 16 lines print. `lazy/cutter_rocket-nowheels` should show about 7 wins of 8 on today's Cook.
- [ ] **Step 5: Commit** (`feat(balance): kite and brawl drives, lazy suite, no-wheel demo twins`).

---

### Task 6: Tune the Cook, the parts and the arena together

**Files:**
- Modify: `game/data/enemies/dozer_cook.tres`
- Modify: `game/data/parts/*.tres` and `game/battle/behaviours/*.gd` constants, as tuning needs
- Modify: `game/materials/{gunpowder,tnt,acid}.tres`, `ch_hazards.gd` constants,
  `ch_arena_builder.gd` placements
- Modify: `tools/balance/suites/*.json` (`expect` re-pins), `tools/balance/README.md` (tuning log,
  Known-fail)
- Modify: tooltip copy (`description` in each changed part's `.tres`) and the tests that pin
  changed numbers
- Modify: `docs/design-doc/core-mechanics.md` §3.5, `docs/design-doc/elements-list.md`

Starting point:
- The Cook: `max_hp` 1500; Firebolt Launcher on `[2]` and Ring of Fire on `[3]`; Harpoon, Hearth
  and Mace stay.
- First part lever: a Rocket that hits within 12 cells of its own anchor deals half damage (a
  point-blank falloff in `ch_rocket.gd`, with its tooltip updated).

Goals (from the spec). Tuning is done when all of these hold:

| # | Check | Command | Pass |
|---|---|---|---|
| G1 | Lazy builds lose badly | `run.sh --suite lazy` | every `lazy/*` `win_rate` ≤ 0.125, and the median Cook `hp_left` ≥ half its `max_hp` |
| G2 | Full builds face a hard fight | `run.sh --suite demo` | the five `vs-cook-<build>` win 0.40–0.70, `mean_fight_seconds` ≥ 35 |
| G3 | Moving matters | `summary.py --wheel-gap` on the demo out | every gap ≥ 0.25 |
| G4 | The arena matters | `summary.py` on the demo out | the summed `hazard_damage` over both sides is ≥ 10% of all damage dealt, and > 0 for each side |
| AG | The Cook doesn't blow itself up | demo out | the Cook's `killed_by_hazard` is under 1 fight in 4 per build |
| — | Round-robin band | `run.sh --suite demo-matrix`, `matrix.py` | every build 0.35–0.65 |
| — | Standalone baseline | `run.sh --suite standalone` | common weapons in the 10–20 DPS range, at roughly equal damage per energy (report misses) |

Each reference build may use `drive.player` `ai`, `kite` or `brawl`, whichever suits it. Record the
choice in `demo.json`.

- [ ] **Step 1: Baseline.** Set the Cook to the starting point, then run `lazy`, `demo`,
  `demo-matrix`, `bodies` and `standalone`. Add row 0 to a new "Cook and arena" tuning-log table in
  the README, with columns for G1–G4, AG and the matrix scores.
- [ ] **Step 2: Tune in rounds.** Change one lever per row, rerun the suites it affects, and log the
  row. Levers, roughly in this order:
  1. The Cook's loadout and HP.
  2. Part numbers (the Rocket point-blank falloff first).
  3. Blast damage and radii.
  4. Set-piece placement.
  5. Drive policies per build.

  Watch the spec's anti-goals in every round:
  - The arena must not decide fights on its own (a death at spawn to an untouched crate, or a
    win-rate skew between sides in mirror fights).
  - No stat wall: if the Cook's HP passes 2000, stop and look for a damage lever instead.
  - Performance: a 60 s fight in the runner stays under about 2 s.

  If the freeze build is the only one outside G2 and the cause is the freeze chain, stop and report
  to the user rather than change rules.
- [ ] **Step 3: Re-pin every suite's `expect`** to the kept values: `lazy` holds G1, `demo` holds G2
  within one fight, and update `demo-matrix`, `bodies` and `mirror`. Update the README's Known-fail
  table for any criterion that still misses.
- [ ] **Step 4: Update tooltips, and the tests that pin changed numbers.** Run
  `godot --headless --path . --script res://tests/run_tests.gd`. Expected: `0 failed`.
- [ ] **Step 5: Update the docs.** `core-mechanics.md` §3.5 describes the arena's set pieces and
  says blasts hurt chariots and chain. `elements-list.md` marks gunpowder, TNT and acid (terrain
  only, not rock) as in the sim.
- [ ] **Step 6: Run every suite once more**, and check that each `ok` is `true` (or listed in
  Known-fail).
- [ ] **Step 7: Commit** (`tune(balance): the Cook, parts and arena tuned together`).
