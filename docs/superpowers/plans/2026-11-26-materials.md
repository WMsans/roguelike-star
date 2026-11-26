# Materials and the Sim (Stage 2 of All Parts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the sand sim the materials, hardness, wind, sparks, batteries and one explosion event that the 169 parts of Stage 4 build on, with the arena using some of them.

**Architecture:**
- Engine (C++, `addons/noita_engine`): a `hardness` per material, a `dig` limit on `explode`, an `explode_dig` per explosive material, and a `blow` call that pushes gas-class cells. Everything else is GDScript.
- Data: eight new `PixelMaterial`s and new reactions in `game/materials/`, listed in `game_set.tres`.
- `ChHazards` grows into the one place blasts become damage. It holds the three blast sizes, ownership (charges a part spawned, chains off owned blasts) and the `EXPLOSION` event. `ChBattleContext.explode` is the entry point for part-made blasts.
- `ChSparks` (new, GDScript) floods a spark through water and steel, shocks the holders it reaches, lights explosives, and runs the batteries once a status second.

**Tech Stack:** Godot 4, GDScript, the `noita_engine` GDExtension (C++, scons via `addons/noita_engine/build.sh`), the repo's headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-25-all-parts-design.md` (Stage 2, "Constraints", and "Carried from Stage 1"). Material and reaction rules come from `docs/design-doc/elements-list.md` §3–§7.

## Global Constraints

- Run one file's tests: `godot --headless --path . -s res://tests/run_tests.gd -- <file-name-filter>`. Run the whole suite without the filter. It must end `N passed, 0 failed` at the end of every task. Run `godot --headless --path . --import` once first, and again after adding a `.tres`.
- After any C++ change, rebuild with `addons/noita_engine/build.sh` (it must print `Build OK`). The built `.dylib` is git-ignored, so only sources are committed.
- Fights stay deterministic for a seed. Nothing here draws a random number. Cell scans are row-major from a rect's top-left, and floods are breadth-first in the neighbour order right, left, down, up.
- Parts never give Flame, Freeze, Acid, Wet, Oil or Shock directly (parts-list §1.3). Sparks are sim: `ChSparks` giving Shock is the sim's contact rule, not a part's.
- Every damage goes through `ChBattleContext.deal_hit` or `ChHazards`. Every announcement goes through `ctx.bus`.
- Player and enemy run on the same rules. Nothing here checks a side except ownership, which records one.
- In a `.tres`, never put a `#` comment line before a property: the parser drops the property that follows it (`game/materials/frost.tres` explains). Comments go last or nowhere.
- Hardness per material, exactly (`elements-list.md` §3): sand 1, gunpowder 1, dirt 2, wood 3, coal 3, tnt 3, ice 4, battery 4, rock 5, steel 7, obsidian 8. Every liquid, gas and fire is 0. Concrete stays `indestructible`.
- Blast sizes, exactly:

  | Size | radius | dig | damage at centre | power |
  |---|---|---|---|---|
  | `small` | 5 | 2 | 6 | 150 |
  | `medium` | 8 | 4 | 60 | 250 |
  | `large` | 12 | 6 | 300 | 400 |

  Material → size: gunpowder small, flammable_gas medium, tnt large.

## Review Focus

1. **A spark loop that never ends.** Two shocked chariots stand in one puddle. Shock must still decay to 0 once nothing new arrives. Ruling: a Shock **status** sends sparks that light explosives but shock nobody (Task 4 tests it).
2. **The idle arena goes off on its own.** A battery spark must never reach TNT, gunpowder or a conductor that touches them. After 60 s with nobody firing, the sim reports no material blast (Task 5 tests it).
3. **Wind at the edge of the world.** A `blow` rect that crosses the arena border or an unloaded chunk moves nothing into a wall and doesn't crash (Task 1 tests it).
4. **Ownership with both sides' blasts overlapping.** It must be decided the same way every time: the earliest-registered owned disc that contains the blast wins (Task 3 tests it).
5. **A huge conductor.** A spark into the arena's water or a long steel rail stops at `MAX_CELLS` and still shocks what it reached (Task 4 tests it).

---

### Task 1: Engine: hardness, dig-limited blasts, and wind

**Files:**
- Modify: `addons/noita_engine/engine/core/material.h`, `addons/noita_engine/engine/core/material.cpp` (compile the two new fields)
- Modify: `addons/noita_engine/engine/core/particles.h`, `addons/noita_engine/engine/core/particles.cpp` (`explode` gains `dig`)
- Modify: `addons/noita_engine/engine/godot/pixel_material.h/.cpp` (two properties)
- Modify: `addons/noita_engine/engine/godot/pixel_world.h/.cpp` (`explode` binding, `blast`, `detonate_lit`, new `blow`)
- Test: `tests/engine/test_engine_additions.gd`

**Interfaces:**
- Produces:
  - `PixelMaterial.hardness: int` (default 0).
  - `PixelMaterial.explode_dig: int` (default -1). This is the dig limit a lit cell of this material blasts with. -1 digs everything, today's behaviour.
  - `PixelWorld.explode(position: Vector2i, radius: int, power: float, dig: int = -1) -> int`. A cell with `hardness > dig` is left alone when `dig >= 0`. Explosive cells in the radius are still lit whatever their hardness. Indestructible cells are untouched as now. Existing three-argument calls keep today's behaviour.
  - Each `take_blasts()` entry gains `"dig": int`.
  - `PixelWorld.blow(rect: Rect2i, velocity: Vector2i) -> int` answers the cells moved.
    - Every gas-class cell (`MatClass::Gas`, which includes fire, smoke, steam, frost, and the new gases) inside `rect` moves up to `|velocity.x|` cells along x, then up to `|velocity.y|` along y.
    - Each step goes into an Empty cell only and stops at the first non-empty one.
    - Cells keep their flags, temperature and life.
    - Cells are visited against the direction of travel, so none moves twice in one call.
    - Main thread only, like `explode`.

- [ ] **Step 1: Write the failing tests** in `tests/engine/test_engine_additions.gd`, using its own `_make_world` set. Add materials with `hardness` set, for example a `steel`-like solid with hardness 7, and give rock hardness 5 and sand hardness 1 in that helper.
  - `test_explode_dig_spares_harder_cells`: a disc half rock (5), half steel (7). `explode(c, 8, 300, 6)` leaves every steel cell and removes the rock.
  - `test_explode_dig_default_digs_all`: the same setup with no 4th argument removes both.
  - `test_explode_dig_still_lights_explosives`: TNT given hardness 3 inside `explode(c, 8, 300, 0)` is lit, and after `step` a `"tnt"` blast is queued.
  - `test_lit_blast_uses_explode_dig`: TNT with `explode_dig = 4` next to steel (7) and rock (5). Once lit and stepped, the queued blast has `dig == 4` and the steel remains.
  - `test_blow_moves_gas_only`: smoke, a sand pile and a rock wall in a rect. After `blow(rect, Vector2i(5, 0))` the smoke moved +5 in x, nothing else moved, and the answer equals the smoke count.
  - `test_blow_stops_at_walls`: smoke 2 cells from a rock wall, blown +5. It ends next to the wall and no rock cell changed.
  - `test_blow_across_the_border`: a rect reaching past the arena edge and into unloaded space. It doesn't crash, every border cell is still border material, and it answers ≥ 0.
- [ ] **Step 2: Run them to see them fail.** Run `godot --headless --path . -s res://tests/run_tests.gd -- engine_additions`. Expected: they fail because `hardness`, `explode_dig` and `blow` don't exist.
- [ ] **Step 3: Implement.**
  - Fields:
    - Add `int hardness = 0; int explode_dig = -1;` to `MaterialDef` and `CompiledMaterial`, and carry them through compilation.
    - Add both to `PixelMaterial`, mirroring how `explode_radius` is bound in commit `1396466`.
  - `::explode`:
    - Takes `int dig` after `power`.
    - The explosive branch stays first.
    - Then `if (dig >= 0 && def.hardness > dig) continue;`.
  - `PixelWorld::blast` takes `dig` and stores it in the entry. `detonate_lit` passes `def.explode_dig`. Bind `explode` with `DEFVAL(-1)`.
  - Write `blow`:
    - Clamp the velocity to ±64 per axis.
    - Visit only cells whose chunk is loaded.
    - Move a cell with the same grid write `explode` uses, so the chunk wakes.
  - Rebuild with `addons/noita_engine/build.sh`.
- [ ] **Step 4: Run the tests.** Run `addons/noita_engine/build.sh` and then the whole suite. Expected: `Build OK`, then `N passed, 0 failed`.
- [ ] **Step 5: Commit** with `feat(engine): material hardness, dig-limited blasts, and blow for wind`.

---

### Task 2: The new materials and reactions

**Files:**
- Create in `game/materials/`:
  - Materials: `spark.tres`, `battery.tres`, `steel.tres`, `acid_gas.tres`, `coal.tres`, `flammable_gas.tres`, `dirt.tres`, `obsidian.tres`.
  - Reactions: `lava_frost.tres`, `acid_dirt.tres`, `acid_coal.tres`, `acid_steel.tres`, `acid_battery.tres`.
- Modify:
  - Every existing solid and powder `.tres` gets its `hardness`.
  - `gunpowder.tres` gets `explode_dig = 2`, `tnt.tres` gets `explode_dig = 6`.
  - In the four `acid_*.tres`, `a_into` becomes `&"acid_gas"`.
  - `game_set.tres`.
  - `game/battle/ch_statuses.gd` (`GAIN_RATES`).
  - `game/battle/ch_battle_context.gd` (`ACID_EATS`).
- Test: `tests/test_materials.gd`, `tests/battle/test_status_second.gd`

**Interfaces:**
- Consumes: Task 1's `hardness`, `explode_dig`.
- Produces: material names `&"spark"`, `&"battery"`, `&"steel"`, `&"acid_gas"`, `&"coal"`, `&"flammable_gas"`, `&"dirt"`, `&"obsidian"` in the game set.

Material values. Colours are placeholders. Classes: 1 solid, 2 powder, 4 gas.

| Material | class | Key properties |
|---|---|---|
| spark | 4 | density 0.1, colour (1, 0.95, 0.5), emission (1, 0.95, 0.6) energy 2.0, light_opacity 0.0, lifetime 6. No temperature: it's the visible arc, `ChSparks` does the work |
| battery | 1 | density 2.2, colour (0.25, 0.45, 0.3), emission (0.4, 0.9, 0.5) energy 0.3, collision_solid, hardness 4 |
| steel | 1 | density 7.8, colour (0.62, 0.65, 0.7), collision_solid, conductivity 0.3, hardness 7 |
| acid_gas | 4 | density 0.35, colour (0.55, 0.85, 0.3), light_opacity 0.05, lifetime 150 |
| coal | 1 | density 1.4, colour (0.12, 0.11, 0.1), collision_solid, ignite_temperature 300, burn_life 240, burn_heat 700, hardness 3 |
| flammable_gas | 4 | density 0.15, colour (0.7, 0.8, 0.3), light_opacity 0.05, ignite_temperature 100, burn_heat 600, explode_radius 8, explode_power 250, explode_dig 4. No lifetime: it pools until lit |
| dirt | 2 | density 1.5, colour (0.42, 0.3, 0.18), collision_solid, light_opacity 0.9, hardness 2 |
| obsidian | 1 | density 2.6, colour (0.16, 0.1, 0.22), collision_solid, hardness 8 |

Reactions:
- `lava_frost` is `a = lava, b = frost, a_into = obsidian, b_into = "", probability 0.5`.
- `acid_dirt`, `acid_coal` and `acid_battery` are `a = acid, b = <it>, a_into = acid_gas, b_into = "", probability 0.15`.
- `acid_steel` is the same with probability 0.03.

GDScript tables:
- `GAIN_RATES` gains `&"acid_gas": [ACID, 1]`. Spark is not in it: `ChSparks` gives spark Shock on reach (Task 4).
- `ACID_EATS` becomes `[sand, dirt, wood, coal, gunpowder, tnt, battery, steel]`. That's elements §4's list without rock, which the arena's acid cistern relies on. Ruling: the Acid status dissolves by this list, not by hardness.

- [ ] **Step 1: Write the failing tests** in `tests/test_materials.gd`, each with `make_world()` and capped tick loops in the file's existing style.
  - `test_hardness_values`: load each material in `game_set.tres` and assert the hardness table from Global Constraints, plus 0 for every liquid and gas.
  - `test_lava_and_frost_make_obsidian`: lava next to a frost column. Within 300 ticks `count_materials` shows obsidian.
  - `test_acid_dissolving_releases_acid_gas`: acid on sand. Within 300 ticks acid_gas appears.
  - `test_lit_flammable_gas_is_a_medium_blast`: a sealed rock pocket of flammable_gas plus one fire cell. Within 300 ticks `take_blasts()` holds an entry with material `flammable_gas`, radius 8 and dig 4.
  - `test_coal_outburns_wood`: equal blocks of coal and wood lit together. Wood is gone first, and coal is still there.
  - `test_tnt_blast_spares_steel`: a lit TNT crate inside a steel box. After the blast, the steel cells remain.
  - Add one to `test_status_second.gd`: `test_acid_gas_gives_one_acid`, a part whose sample rect holds acid_gas gains 1 Acid at the status second.
- [ ] **Step 2: Run them to see them fail.** Run with the `-- materials` and `-- status_second` filters. Expected: unknown material errors and failed asserts.
- [ ] **Step 3: Add the `.tres` files and the table changes.** Run `godot --headless --path . --import`.
- [ ] **Step 4: Run the tests.** Run the whole suite. Expected: `N passed, 0 failed`. If an old arena test breaks because gunpowder now digs only up to hardness 2 (the seam's wood plank survives), the chain test is the authority. Change the arena's plank only if the chain itself stops, and say so in the report.
- [ ] **Step 5: Commit** with `feat(materials): spark, battery, steel, acid gas, coal, flammable gas, dirt, obsidian`.

---

### Task 3: One explosion event, blast sizes and ownership

**Files:**
- Modify: `game/battle/ch_hazards.gd` (sizes, ownership, Block, the event)
- Modify: `game/battle/ch_battle_context.gd` (`explode`, `own_charge`, a `hazards` instance, charge pruning in the status second)
- Modify: `game/battle/ch_event.gd` (`EXPLOSION`)
- Test: `tests/battle/test_hazards.gd`, a new `tests/battle/test_explosions.gd`

**Interfaces:**
- Consumes: Task 1's `explode(..., dig)` and the blast entry's `dig`, plus Task 2's `flammable_gas`.
- Produces:
  - `ChHazards.SIZES := {&"small": {...}, &"medium": {...}, &"large": {...}}` with keys `radius, dig, damage, power`, values from Global Constraints. `ChHazards.MATERIAL_SIZE := {&"gunpowder": &"small", &"flammable_gas": &"medium", &"tnt": &"large"}`. This replaces `BLAST_DAMAGE`.
  - `ChHazards` becomes an instance (`ctx.hazards`, made in `ChBattleContext._init`), because ownership is state. `ctx.tick` calls `hazards.apply(self, world.take_blasts())`.
  - `ChBattleContext.explode(source: ChPartRuntime, at: Vector2i, size: StringName, damage: int, dig := -1) -> void` is a part-made blast. It runs these steps now, in order:
    1. Call `world.explode(at, radius, power, dig if dig >= 0 else size's dig)`.
    2. Emit `EXPLOSION` with owner `source.side`.
    3. Record an owned disc.
    4. For each living chariot on the **other** side whose hull box is within the radius, call `deal_hit(source, chariot.chassis, roundi(damage * falloff))` when that is above 0, and push it as material blasts do.

    The `&""` entry this leaves in the queue is skipped by `apply`, as today. Ruling: a part's own blast never hurts its own chariot.
  - `ChBattleContext.own_charge(rect: Rect2i, side: int) -> void` records explosive cells a part spawned. `hazards` drops a charge at a status second once `count_materials(rect.grow(CHARGE_MARGIN))` holds no gunpowder, tnt or flammable_gas. `CHARGE_MARGIN := 4`.
  - A drained material blast's owner is decided by the first rule that matches:
    1. The first registered charge whose `rect.grow(CHARGE_MARGIN)` contains the position.
    2. The earliest-recorded owned disc, from the last `CHAIN_WINDOW := 0.5` s of `ctx.time`, that contains the position.
    3. Otherwise -1 (unowned).

    An owned material blast records its own disc, so a chain carries ownership. Discs older than the window are dropped.
  - Material blast damage:
    - The hull's HP goes through the body's Block: `ChDamage.hit_body(hp, damage, 1.0, block)`, then the Block is written back and `STATUS_LOST` is emitted when it runs out, the same way `deal_hit` does it.
    - The parts inside the radius still lose `BLAST_WEAR` of the damage dealt as integrity.
    - `HAZARD_HIT` stays as it is.
  - `ChEvent.EXPLOSION` has `side` = owner (-1 when unowned), `position` = centre, and data `{size, radius, dig, owner, material, source}`. `source` is the part for a part-made blast and null otherwise. There is one per part-made blast and one per drained material blast, owned or not.

- [ ] **Step 1: Write the failing tests.** Update `test_hazards.gd`: its `TNT` constant reads `ChHazards.SIZES[&"large"].damage`, and it calls `ctx.hazards.apply`. Add to it:
  - `test_blast_damage_spends_body_block`: a hull with 100 Block, a TNT blast at the centre. Block goes to 0, HP falls by 200, and `STATUS_LOST` names block.
  - `test_medium_blast_for_flammable_gas`: a hand-made `flammable_gas` entry deals `SIZES.medium.damage` at the centre.

  New `test_explosions.gd`:
  - `test_part_blast_emits_one_owned_explosion`: `ctx.explode(part, at, &"large", 80)` emits exactly one EXPLOSION with owner = part's side, size large, radius 12, and source = part.
  - `test_part_blast_hits_only_the_enemy`: both hulls inside the radius. Only the enemy's HP falls, by `deal_hit`'s amount, and a HIT with source = part is emitted.
  - `test_part_blast_digs_by_size`: in a real `make_world`, a large part blast next to steel and rock removes the rock and leaves the steel.
  - `test_charge_ownership`: `own_charge(rect, 1)`, then a `tnt` entry at a position inside the rect. The EXPLOSION has owner 1.
  - `test_chain_ownership_carries_and_expires`:
    - An owned part blast at A, then a material entry inside A's radius at +0.2 s gets owner = A's side.
    - A third entry inside the second's radius at +0.6 s from A but +0.4 s from the second is also owned.
    - An entry inside only A's radius at +0.6 s is unowned.
  - `test_overlapping_owners_first_wins`: an owned disc of side 0 recorded first, then side 1, both containing the point. The entry gets owner 0.
  - `test_unowned_terrain_blast`: an entry nowhere near anything owned emits EXPLOSION with owner -1 and side -1.
  - `test_spent_charge_is_dropped`: `own_charge` over an empty rect. After one status second it no longer claims a blast there.
- [ ] **Step 2: Run them to see them fail.** Run with the `-- hazards` and `-- explosions` filters.
- [ ] **Step 3: Implement** per the Interfaces above. Move the shared push and falloff into one helper both paths use. Update `tools/balance/ch_fight_stats.gd` and `ch_battle_feedback.gd` only if they break; both read `HAZARD_HIT`, which is unchanged.
- [ ] **Step 4: Run the whole suite.** Expected: `N passed, 0 failed`. Also run `tools/balance/run.sh tools/balance/suites/smoke.json` and expect it to finish without errors.
- [ ] **Step 5: Commit** with `feat(battle): one explosion event with sizes and ownership; blasts spend Block`.

---

### Task 4: Sparks and batteries

**Files:**
- Create: `game/battle/ch_sparks.gd` (`class_name ChSparks`)
- Modify: `game/battle/ch_battle_context.gd` (a `sparks` instance, battery sparks at the start of `_status_second`, Shock's cell effect in `_status_cells`)
- Modify: `game/ui/ch_keywords.gd` (Shock's text)
- Test: new `tests/battle/test_sparks.gd`

**Interfaces:**
- Consumes: Task 2's `spark`, `battery`, `steel`, `flammable_gas`, and `ctx.give_status`, `ctx.touching` and `holder.sample_rect()` from Stage 1.
- Produces:
  - Constants: `ChSparks.CONDUCTORS := [&"water", &"steel"]`, `EXPLOSIVES := [&"gunpowder", &"tnt", &"flammable_gas"]`, `SPARK_SHOCK := 2`, `MAX_CELLS := 600`, `ARC_CELLS := 24`.
  - `ChSparks.discharge(ctx: ChBattleContext, seeds: Array[Vector2i], shock := true) -> Array` answers the holders shocked, in holder order: each chariot by side, its body, then its parts in mount order.
    1. Flood breadth-first from `seeds` through 4-connected `CONDUCTORS` cells, at most `MAX_CELLS` cells including the seeds. The reached set is the seeds plus the flooded cells.
    2. Every `EXPLOSIVES` cell 4-adjacent to the reached set, or in it, is replaced by `&"fire"`, which lights it through the sim.
    3. Up to `ARC_CELLS` air cells 4-adjacent to the reached set become `&"spark"`, so the arc can be seen.
    4. When `shock` is true, every living holder (body and unbroken parts, both sides) whose `sample_rect()` contains a reached cell gets `give_status(holder, SHOCK, SPARK_SHOCK)` once per discharge. Stage 1's jump rule then runs as usual.
  - `ChSparks.add_battery(ctx, rect: Rect2i) -> void` records the battery cells now in `rect`.
  - `ChSparks.second(ctx) -> void` runs once a status second, before the holders are snapshotted.
    - Every recorded battery cell that is now air becomes `&"acid"` and is forgotten. That's elements §4: a broken battery leaks acid where it stood.
    - A cell that became anything else is forgotten.
    - Each battery block with cells left then discharges once with its remaining cells as seeds, `shock = true`.
  - Shock's cell effect, in `_status_cells`: a holder with Shock > 0 calls `discharge(ctx, conductor and explosive cells in its sample_rect, false)`, if there are any.
    - Ruling: a Shock status's spark lights explosives through water and steel but shocks nobody, so two shocked chariots in one puddle can't feed each other forever.
    - Shock keyword text, appended: "A shocked part sets off gunpowder and TNT through touching water or steel."

- [ ] **Step 1: Write the failing tests** in `tests/battle/test_sparks.gd`, with a real `make_world` and the chariot helpers the Stage 1 status tests use.
  - `test_spark_through_water_shocks_a_part_in_it`: a water strip from a seed to a part's sample rect. That part gains 2 Shock, and a part on dry ground gains none.
  - `test_spark_through_steel`: the same along a steel rail.
  - `test_spark_does_not_cross_air_or_sand`: a gap of sand in the strip. The far part gains nothing.
  - `test_spark_shocks_each_holder_once`: a part whose rect holds 30 reached cells gains exactly 2.
  - `test_spark_lights_gunpowder_and_tnt`: gunpowder at the end of a steel rail. After the discharge and up to 300 ticks, a `gunpowder` blast is queued.
  - `test_spark_flood_is_capped`: water larger than `MAX_CELLS` with a part at the far end. That part gets no Shock, a part beside the seed does, and the call returns.
  - `test_battery_sparks_every_second`: a battery block touching a part's sample rect. The part gains 2 Shock at each of 2 status seconds, net of decay.
  - `test_broken_battery_leaks_acid`: register a battery, clear two of its cells to air, run one status second. Those two cells are acid.
  - `test_shock_status_lights_but_does_not_shock`:
    - Two parts, one per side, in one shallow puddle, one holding 5 Shock.
    - After 10 status seconds both hold 0 Shock.
    - Gunpowder in the puddle's rim was lit.
  - `test_spark_arc_is_visible`: after a discharge in water under air, `count_materials` around it shows spark cells, and they're gone after 30 ticks.
- [ ] **Step 2: Run them to see them fail.** Run with `-- sparks`.
- [ ] **Step 3: Implement** `ChSparks` and the context hooks per the Interfaces above. Read `ctx.chariots` for holders. Make no new events: Stage 4 adds "battery broke" when a part needs it.
- [ ] **Step 4: Run the whole suite.** Expected: `N passed, 0 failed`.
- [ ] **Step 5: Commit** with `feat(battle): sparks through water and steel, batteries that spark and leak`.

---

### Task 5: The arena gets batteries, steel and water, and the docs catch up

**Files:**
- Modify: `game/battle/ch_arena_builder.gd` (`build` returns `"batteries": Array[Rect2i]` as well)
- Modify: `game/battle/ch_battle.gd` (register each battery rect through `ctx.sparks.add_battery` after the context is made)
- Modify: `docs/design-doc/elements-list.md` (§3 "In the sim today", §6 Shock row), and in `docs/superpowers/specs/2026-11-25-all-parts-design.md` the "Carried from Stage 1" acid design check, which now notes the Acid list ruling
- Test: `tests/battle/test_arena.gd`

**Interfaces:**
- Consumes: Task 2's materials and Task 4's `ChSparks.add_battery`.
- Produces: the arena dictionary key `"batteries"`.

Placement is the builder's, mirrored like everything else. It must meet these, which are the tests:
- Each half has at least one battery block (about 4×3), one steel run of at least 12 cells, and one water pool.
- No liquid on the driving line (x 140–340) is 2 cells deep. Keep the file's existing reason comment in mind.
- No battery block, and no conductor connected to one, touches TNT, gunpowder or flammable gas.
- The existing arena tests still pass.

- [ ] **Step 1: Write the failing tests** in `test_arena.gd`.
  - `test_arena_has_batteries_steel_and_water`: count each per half from `build`'s world, and check that `"batteries"` lists the battery rects.
  - `test_idle_arena_never_blows`: build, register the batteries in a bare context, then step 60 s of sim with status seconds and no chariots. `take_blasts()` never yields a material blast.
  - `test_battery_spark_stays_off_explosives`: flood from each battery's cells with `ChSparks`' rule (`shock = false`). No reached cell is next to an explosive.
  - Extend the existing shallow-liquid test, or add one, to cover the new water.
- [ ] **Step 2: Run them to see them fail.** Run with `-- arena`.
- [ ] **Step 3: Place the pieces and register the batteries.**
- [ ] **Step 4: Run the whole suite and the smoke run.** Run the whole suite and `tools/balance/run.sh tools/balance/suites/smoke.json`. Expected: `N passed, 0 failed`, and the smoke run finishes.
- [ ] **Step 5: Update the docs.**
  - In `elements-list.md` §3, rewrite "In the sim today" to list what now exists: the eight new materials, hardness, wind (`blow`), sparks through water and steel, batteries, and the blast sizes and their dig.
  - In §6, add the Shock ruling: a Shock status's spark lights explosives and shocks nobody.
- [ ] **Step 6: Commit** with `feat(arena): batteries, steel and water; elements-list catches up with the sim`.
