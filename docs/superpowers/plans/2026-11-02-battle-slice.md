# Chariot Battle Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable loop of garage → one battle against a fixed enemy chariot in a walled sand arena → result → garage, with the 12 slice parts and their chains working.

**Architecture:** Pure-logic GDScript modules handle data, layout, energy, events and damage, and are unit-tested headless. A thin runtime layer turns a `ChariotLayout` into jointed `PixelRigidBody`s in a `PixelWorld` running in arena mode, and part behaviours drive weapons through a shared `BattleContext`. The garage is a standalone scene with an `Inventory`/`ChariotLayout`-in, `fight_requested(layout)`-out API, so the later shop can wrap it.

**Tech Stack:** Godot 4.7.2 (`/usr/bin/godot`), GDScript, `addons/noita_engine` GDExtension (C++17, built with `addons/noita_engine/build.sh`).

**Spec:** `docs/superpowers/specs/2026-11-02-battle-slice-design.md`

## Global Constraints

- All game code lives under `res://game/`; tests live under `res://tests/`. Nothing in `res://game/` references `res://addons/noita_engine/demo/`; copy what's needed.
- Don't reuse the addon's global class names: `PixelCharacter`, `CharacterSystem`, `CarController`, `TexturesUtil`. All game `class_name`s are prefixed `Ch` (e.g. `ChPartDef`).
- Only HP reaching 0 ends a battle. Part damage lasts for one fight only.
- Energy: a body defines its cap and regen. **Driving is paid first**, then the FIFO queue of ready parts. Driving with too little energy is ignored, not queued. Driving costs 2 energy/s, flat.
- Placeholder numbers: Cutter HP 500, cap 20, regen 6; Dozer HP 500, cap 20, regen 5; Corsair HP 600, cap 24, regen 5. CATS power 5 → 1 energy, power 10 → 2 energy.
- A hit on a part lowers chariot HP by the full damage *and* wears the part's integrity. Multipliers apply to the HP damage.
- Parts fire the way they face. Flip is per slot (left/right only). The enemy layout is mirrored.
- Layout is a tree. Children fall with a broken parent, and move with their parent on body swap.
- Arena: 480×180 cells, concrete walls on the sides and bottom; sand/wood/water surface, rock below with lava pools, no caves.
- C++ changes to the addon are additive only. Body and joint behaviour stays unchanged.
- Viewport 320×180, nearest filtering (already set in `project.godot`).

## Review Focus

1. **A layout with no wheels, or with wheels mounted off the ground.** The chariot must spawn, fight and fire with no errors; driving input just does nothing. → Task 9 test `test_wheelless_chariot_spawns_and_fires`.
2. **Energy starvation while driving is held.** Holding a direction with regen ≤ drive cost must never deadlock: when the direction is released, queued parts fire in FIFO order. → Task 5 test `test_release_drive_drains_queue_in_order`.
3. **A part breaking mid-fight while it has queued energy requests or children.** It must leave the queue, and its children must also break and leave. No orphan joints, no null access in later ticks. → Task 10 test `test_break_removes_from_queue_and_cascades`.
4. **Both chariots reaching 0 HP on the same tick** (e.g. Ring of Fire hits itself and the enemy). The result must be a defined outcome — a loss for the player — not a crash or a stuck battle. → Task 15 test `test_simultaneous_death_is_loss`.
5. **Body swap onto a body with fewer slots.** Parts that don't fit return to inventory as whole subtrees (children travel with their parent); nothing is silently lost. → Task 4 test `test_swap_to_smaller_body_returns_leftovers_whole`.

---

## File Structure

```
addons/noita_engine/engine/core/material.h          (modify: indestructible field)
addons/noita_engine/engine/core/particles.cpp       (modify: explode skips indestructible)
addons/noita_engine/engine/godot/pixel_material.*   (modify: indestructible property)
addons/noita_engine/engine/godot/pixel_world.*      (modify: arena_border_material, count_materials)
tests/run_tests.gd            headless runner: finds tests/**/test_*.gd, runs test_* methods
tests/ch_test.gd              base class with assert helpers and world fixture helpers
game/materials/*.tres         game material set (copied + concrete, frost, ice) and reactions
game/data/ch_part_def.gd      PartDef resource
game/data/ch_body_def.gd      BodyDef resource
game/data/ch_slot_node.gd     one placed part in a layout tree
game/data/ch_chariot_layout.gd layout resource + tree ops, reseat, mirror
game/data/ch_inventory.gd     part-id list with capacity
game/data/ch_catalog.gd       loads defs by id from game/data/parts, game/data/bodies
game/data/parts/*.tres, game/data/bodies/*.tres, game/data/enemies/dozer_cook.tres
game/battle/ch_event.gd, ch_event_bus.gd      events and bus with proximity filter
game/battle/ch_energy.gd                      energy pool + FIFO queue
game/battle/ch_damage.gd                      pure damage rules
game/battle/ch_part_runtime.gd                per-part state: cooldown, integrity, status
game/battle/ch_chariot_runtime.gd             HP, parts, bodies, joints for one side
game/battle/ch_chariot_builder.gd             layout → bodies + joints in a PixelWorld
game/battle/ch_battle_context.gd              what behaviours can touch
game/battle/behaviours/ch_behaviour.gd + one file per part
game/battle/ch_arena_builder.gd               terrain fill
game/battle/ch_enemy_ai.gd                    drive decision
game/battle/battle.tscn + ch_battle.gd        scene, HUD, win/lose
game/garage/garage.tscn + ch_garage.gd        garage UI
game/main.tscn + ch_main.gd                   garage ↔ battle flow (set as main scene)
```

---

### Task 1: Headless test runner

**Files:**
- Create: `tests/run_tests.gd`, `tests/ch_test.gd`, `tests/test_smoke.gd`

**Interfaces:**
- Produces: `class_name ChTest extends RefCounted` with `assert_eq(a, b, msg := "")`, `assert_true(c, msg := "")`, `assert_near(a: float, b: float, eps := 0.001, msg := "")`, and `make_world(arena := Rect2i(0, 0, 480, 180)) -> PixelWorld` (async: adds a `PixelWorld` with the game material set under the runner's root, waits until `is_area_ready(arena)`; usable once Task 3 lands). Test methods may be coroutines (`await`).
- Run command, used by every later task: `godot --headless --path . --script res://tests/run_tests.gd [-- filter]`. The output ends with `N passed, M failed`, and the exit code is non-zero on any failure.

- [ ] **Step 1:** Write `tests/test_smoke.gd` with `test_passes()` → `assert_eq(1 + 1, 2)` and `test_fails_on_purpose()` → `assert_eq(1, 2)`.
- [ ] **Step 2:** Run `godot --headless --path . --import`, then the run command. Expected: the runner doesn't exist yet, so it errors.
- [ ] **Step 3:** Implement `run_tests.gd` (`extends SceneTree`, walks `res://tests/`, instantiates each `test_*.gd`, calls each `test_*` method with `await`, catches failures recorded by `ChTest`, `quit(1)` on any failure). A filter argument after `--` matches the file name.
- [ ] **Step 4:** Run. Expected: `1 passed, 1 failed`, exit code 1. Delete `test_fails_on_purpose`, rerun. Expected: `1 passed, 0 failed`, exit 0.
- [ ] **Step 5:** Commit `test: headless test runner`.

### Task 2: Engine — indestructible materials, arena border, material counts

**Files:**
- Modify: `addons/noita_engine/engine/core/material.h` (add `bool indestructible = false` to the material def and compiled material), `engine/godot/pixel_material.{h,cpp}` (bound property `indestructible`), `engine/core/particles.cpp` `explode()` (skip cells whose material is indestructible: `continue` before `grid.set`).
- Modify: `engine/godot/pixel_world.{h,cpp}` — new property `arena_border_material: StringName = &"rock"` (used instead of the hard-coded `"rock"` for the arena path's `BoxGenerator`; same error if missing). New method `count_materials(rect: Rect2i) -> Dictionary`, returning `{material_name: count}` for every non-air cell in the rect, plus a key `&"burning"` with the count of cells having `FLAG_BURNING`. Cells off loaded chunks are skipped.
- Test: `tests/engine/test_engine_additions.gd`

**Interfaces:**
- Produces: `PixelMaterial.indestructible: bool`, `PixelWorld.arena_border_material: StringName`, `PixelWorld.count_materials(Rect2i) -> Dictionary`.

- [ ] **Step 1:** Write tests that build a `PixelMaterialSet` in code: rock, concrete (`indestructible = true`), sand.
  - `test_explode_spares_indestructible`: `fill_rect(Rect2i(10,10,20,20), &"concrete")`, `explode(Vector2i(20,20), 8, 300)`, step 2 ticks → `get_material_at(Vector2i(20,20)) == &"concrete"`.
  - `test_arena_border_material`: with `arena_border_material = &"concrete"` and `arena = Rect2i(0,0,64,64)` → `get_material_at(Vector2i(-1, 10)) == &"concrete"`.
  - `test_count_materials`: `fill_rect(Rect2i(5,5,4,4), &"sand")` → `count_materials(Rect2i(0,0,20,20))[&"sand"] == 16`, and `&"burning"` is `0`.
- [ ] **Step 2:** Run with filter `engine`. Expected: FAIL (unknown property/method).
- [ ] **Step 3:** Implement the C++ above, then `cd addons/noita_engine && ./build.sh`.
- [ ] **Step 4:** Run with filter `engine`. Expected: 3 passed.
- [ ] **Step 5:** Commit `feat(engine): indestructible materials, arena border, count_materials`.

### Task 3: Game material set (concrete, frost, ice)

**Files:**
- Create: `game/materials/game_set.tres` plus copies of rock, wood, sand, water, oil, lava, fire, steam, smoke and the reactions water_lava, water_fire, fire_oil (paths rewritten to `res://game/materials/`). New: `concrete.tres` (solid, `indestructible = true`, no ignite, high conductivity 0), `frost.tres` (gas, `fixed_temperature = true`, `base_temperature = -60`, `lifetime = 40`, decays to air), `ice.tres` (solid, `high_temperature = 1`, `high_into = &"water"`, conductivity 0.4). Modify the copied `water.tres`: `low_temperature = 0`, `low_into = &"ice"`.
- Modify: `tests/ch_test.gd` `make_world` to load `game_set.tres` and set `arena_border_material = &"concrete"`.
- Test: `tests/test_materials.gd`

- [ ] **Step 1:** Tests:
  - `test_frost_freezes_water`: fill water `Rect2i(100,100,10,10)`, frost circle above it with radius 6, step ≤ 300 ticks → at least one `ice` in `count_materials`.
  - `test_fire_thaws_ice`: ice block next to fire, step ≤ 300 → `water` or `steam` present.
  - `test_border_is_concrete`: `get_material_at(Vector2i(-1, 90)) == &"concrete"`.
- [ ] **Step 2:** Run with filter `materials`. Expected: FAIL.
- [ ] **Step 3:** Create the `.tres` files above. Tune frost temperature and conductivity until the tests pass within the tick bounds.
- [ ] **Step 4:** Run. Expected: 3 passed.
- [ ] **Step 5:** Commit `feat: game material set with concrete, frost, ice`.

### Task 4: Data model and layout operations

**Files:**
- Create: `game/data/ch_part_def.gd`, `ch_body_def.gd`, `ch_slot_node.gd`, `ch_chariot_layout.gd`, `ch_inventory.gd`
- Test: `tests/data/test_layout.gd`

**Interfaces (Produces):**
- `ChPartDef extends Resource`: `id: StringName`, `display_name: String`, `tags: PackedStringArray`, `energy_cost: int`, `cooldown: float` (s; 0 = passive), `damage: int`, `integrity: int = 100`, `proximity_range: float` (cells; 0 = none), `charges: int = -1` (−1 = unlimited), `extension_slots: PackedVector2Array` (relative to the part anchor, +x = facing), `size: Vector2i` (cells), `color: Color`, `material: StringName`, `behaviour: Script`, `hook_text: String`.
- `ChBodyDef extends Resource`: `id`, `display_name`, `hp: int`, `energy_cap: int`, `energy_regen: float`, `size: Vector2i`, `material: StringName`, `color: Color`, `slots: PackedVector2Array` (body-local cells; origin = body centre, +x = forward).
- `ChSlotNode extends Resource`: `part_id: StringName`, `flipped: bool`, `children: Dictionary[int, ChSlotNode]` (extension slot index → node).
- `ChChariotLayout extends Resource`: `body_id: StringName`, `slots: Dictionary[int, ChSlotNode]` (body slot index → node). Methods:
  - `place(path: Array[int], part_id: StringName) -> bool`. A path is a list of slot indices: `[2]` is body slot 2, and `[2, 0]` is extension slot 0 of the part in body slot 2. Fails if occupied or the parent is missing.
  - `remove(path: Array[int]) -> ChSlotNode` (the detached subtree).
  - `toggle_flip(path: Array[int]) -> void`
  - `get_node(path) -> ChSlotNode`
  - `all_paths() -> Array` (depth-first)
  - `anchor_of(path, catalog: ChCatalog) -> Vector2` (body-local position, accounting for parent flips: a child's extension offset x is negated when its parent is flipped)
  - `swap_body(new_body: ChBodyDef, catalog: ChCatalog) -> Array[ChSlotNode]` (leftover subtrees)
  - `mirrored() -> ChChariotLayout` (deep copy with every `flipped` inverted, used for the enemy facing left; the battle also mirrors body x)
  - `subtree_part_ids(node) -> Array[StringName]`
- `ChInventory extends Resource`: `capacity: int = -1` (−1 = unlimited), `part_ids: Array[StringName]`, `add(id) -> bool`, `take(id) -> bool`, `has(id) -> bool`.

`swap_body` algorithm (not fixed by the tests): collect every top-level `(old_index, old_pos, subtree)`. Build all pairs `(old, new_slot)` with distance `old_pos.distance_to(new.slots[j])`, sort ascending, and greedily assign unused old/new pairs. Unassigned subtrees are returned whole. Children keep their extension indices.

`ChCatalog` is defined in Task 4b below but is needed here by `anchor_of`/`swap_body`. The tests use a hand-built catalog: `ChCatalog.from_defs(parts: Array[ChPartDef], bodies: Array[ChBodyDef])`.

- [ ] **Step 1:** Tests (with a test catalog of body A with slots `[(-10,0),(10,0),(0,-6)]`, body B with slots `[(9,0),(-9,0)]`, and part `strut` with extensions `[(0,-6),(4,-6)]`):
  - `test_place_and_nested_place`: `place([0], &"strut")` → true; `place([0,1], &"mace")` → true; `place([0], &"mace")` → false; `place([1,0], &"mace")` → false.
  - `test_remove_returns_subtree`: after the above, `remove([0])` returns a node with 1 child; `get_node([0]) == null`.
  - `test_flip_mirrors_child_anchor`: strut at `[1]`, child at `[1,1]`; `anchor_of([1,1]) == Vector2(14,-6)`; after `toggle_flip([1])`, `== Vector2(6,-6)`.
  - `test_swap_body_nearest`: A with parts at `[0]` and `[1]` (strut + child at `[1,0]`), swap to B → the part from A's slot 1 `(10,0)` lands at B slot 0 `(9,0)` with its child intact; the part from `(-10,0)` lands at B slot 1; leftovers empty.
  - `test_swap_to_smaller_body_returns_leftovers_whole` (Review Focus 5): A with all 3 slots filled, the strut in `[2]` with a child → swap to B → 1 leftover subtree; if it's the strut, it still has its child.
  - `test_mirrored_inverts_flips`: `mirrored().get_node([0]).flipped == !original`.
  - `test_inventory_capacity`: capacity 1 → `add` true, then false; `take` of a missing id → false.
- [ ] **Step 2:** Run with filter `layout`. Expected: FAIL.
- [ ] **Step 3:** Implement the classes above, plus the minimal `ChCatalog.from_defs`, `part(id) -> ChPartDef`, `body(id) -> ChBodyDef` in `game/data/ch_catalog.gd`.
- [ ] **Step 4:** Run. Expected: 7 passed.
- [ ] **Step 5:** Commit `feat: chariot layout data model`.

### Task 4b: Catalog content (bodies, parts, enemy)

**Files:**
- Modify: `game/data/ch_catalog.gd`, adding `static func load_default() -> ChCatalog` (scans `res://game/data/parts/` and `res://game/data/bodies/`).
- Create: `game/data/bodies/{cutter,dozer,corsair}.tres`, `game/data/parts/{ice_cream_mace,cutter_chainsaw,flamethrower,hearth,cutter_rocket,corsair_harpoon,ember_battery,firebolt_launcher,ring_of_fire,freeze_charge,wheel,strut}.tres` (with `behaviour` left null until Tasks 12–14 set it), `game/data/enemies/dozer_cook.tres` (`ChChariotLayout`: Dozer; two Wheels on the two lowest slots; Hearth, Harpoon facing forward, Mace).
- Test: `tests/data/test_catalog.gd`

Placeholder values (the spec's numbers where it gives them, the rest are my starting tuning):

| id | cost | cooldown | damage | other |
|---|---|---|---|---|
| ice_cream_mace | 1 | 1.0 | 20 | reach 6 |
| cutter_chainsaw | 2 | 0.5 | 20 | reach 14 |
| flamethrower | 2 | 3.0 | 45 total | burst 1 s |
| hearth | 2 | 4.0 | 45 total | charge 1 s |
| cutter_rocket | 2 | 1.0 | 30 | blast r 6 |
| corsair_harpoon | 1 | 5.0 | 5 | range 120 |
| ember_battery | 0 | 0 | — | +3 energy per `caught_fire`, internal cooldown 0.5 s |
| firebolt_launcher | 1 | 2.0 | 25 | charges 5, blast r 8 |
| ring_of_fire | 4 | 6.0 | 10 per contact | radius 24 |
| freeze_charge | 0 | 0 | — | proximity_range 24 |
| wheel | 0 | 0 | — | diameter 12 |
| strut | 0 | 0 | — | extension_slots 2 |

Bodies: Cutter 30×10 with 4 slots; Dozer 30×18 round-ish with 6 slots around the edge (2 low); Corsair 48×10 with 7 slots, top-heavy (high centre of mass via slot placement). HP, cap and regen are as in Global Constraints.

- [ ] **Step 1:** Tests: `test_all_ids_load` (12 parts, 3 bodies, all non-null); `test_spec_numbers` (Dozer `hp == 500`, `energy_cap == 20`, `energy_regen == 5.0`; Corsair `hp == 600`; mace `energy_cost == 1`; chainsaw `energy_cost == 2`; ring_of_fire `energy_cost == 4`; firebolt `charges == 5`; strut `extension_slots.size() == 2`); `test_enemy_layout_valid` (every path's part id exists in the catalog, and 2 nodes are `&"wheel"`).
- [ ] **Step 2:** Run with filter `catalog`. Expected: FAIL.
- [ ] **Step 3:** Create the resources.
- [ ] **Step 4:** Run. Expected: 3 passed.
- [ ] **Step 5:** Commit `feat: slice bodies, parts, enemy data`.

### Task 5: Energy system

**Files:** Create `game/battle/ch_energy.gd`. Test: `tests/battle/test_energy.gd`

**Interfaces (Produces):** `ChEnergy extends RefCounted`:
- `_init(cap: float, regen: float, drive_cost: float = 2.0)`
- `value: float` (starts at cap)
- `request(requester: Object, cost: float) -> void` (enqueue; a requester already queued is ignored)
- `cancel(requester: Object) -> void`
- `tick(delta: float, driving: bool) -> Dictionary` with `{ "drove": bool, "paid": Array[Object] }`
- `queue_size() -> int`

Tick order: (1) add `regen * delta` clamped to cap; (2) if `driving`, pay `drive_cost * delta` if affordable → `drove = true`, else `drove = false`; (3) pay the queue head while it's affordable, in FIFO order. The head blocks later entries (strict FIFO).

- [ ] **Step 1:** Tests:
  - `test_regen_clamps_to_cap`
  - `test_request_paid_immediately_when_affordable` (`paid` contains the requester; value drops by the cost)
  - `test_fifo_strict` (value 0; request A cost 3, then B cost 1; regen 2/s; after 1 s neither is paid; after 1.5 s total only A is paid; B is paid next)
  - `test_driving_paid_first` (value 1, drive cost 2, regen 0, request cost 1 queued: `tick(0.5, true)` → `drove` true, `paid` empty)
  - `test_drive_ignored_without_energy` (value 0, regen 0 → `drove` false, nothing queued for driving)
  - `test_release_drive_drains_queue_in_order` (Review Focus 2: regen 2, drive 2, queue A, B; tick 1 s driving → nothing paid; tick 3 s not driving → paid order `[A, B]`)
  - `test_cancel_removes`
- [ ] **Step 2:** Run with filter `energy`. Expected: FAIL.
- [ ] **Step 3:** Implement `ChEnergy`.
- [ ] **Step 4:** Run. Expected: 7 passed.
- [ ] **Step 5:** Commit `feat: energy pool with drive-first FIFO queue`.

### Task 6: Event bus with proximity

**Files:** Create `game/battle/ch_event.gd`, `game/battle/ch_event_bus.gd`. Test: `tests/battle/test_event_bus.gd`

**Interfaces (Produces):**
- `ChEvent extends RefCounted`: `type: StringName`, `side: int` (0 = player, 1 = enemy), `source: Object` (a `ChPartRuntime` or null), `position: Vector2` (world), `data: Dictionary`. Constants: `PART_FIRED`, `HIT`, `CAUGHT_FIRE`, `FROZEN`, `THAWED`, `PART_BROKEN`, `CELLS_CUT`, `ENERGY_GAINED` (`StringName`s of the same lowercase names).
- `ChEventBus extends RefCounted`:
  - `subscribe(listener: Object, type: StringName, callback: Callable, proximity_of: Object = null, range: float = 0.0)`. When `proximity_of` is set, the callback fires only if `event.source` is on the same side and `event.source.anchor_world().distance_to(proximity_of.anchor_world()) <= range`.
  - `unsubscribe_all(listener)`
  - `emit(event: ChEvent)`. Delivery is synchronous. Events emitted from inside a callback are queued and delivered after the current one (breadth-first). There is a hard limit of 256 deliveries per outer `emit`, beyond which the rest are dropped with a `push_warning`, to stop infinite chains.

- [ ] **Step 1:** Tests: `test_global_subscriber_receives`; `test_proximity_filters_by_range_and_side` (two fake sources with `anchor_world()` at distances 10 and 30; range 24 → only the near one); `test_nested_emits_breadth_first` (A's callback emits X; B is subscribed to both; order recorded = `[A_event, B_event, X]`); `test_chain_cap` (a self-re-emitting callback stops at 256 and doesn't hang); `test_unsubscribe_all`.
- [ ] **Step 2:** Run with filter `event_bus`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 5 passed.
- [ ] **Step 5:** Commit `feat: event bus with proximity filter and chain cap`.

### Task 7: Damage rules

**Files:** Create `game/battle/ch_damage.gd`. Test: `tests/battle/test_damage.gd`

**Interfaces (Produces):** `ChDamage` (static functions only):
- `hit_part(target_hp: int, part_integrity: int, damage: int, multiplier: float = 1.0, wear_ratio: float = 0.5) -> Dictionary` with `{ "hp": int, "integrity": int, "hp_damage": int }`. HP loses `round(damage * multiplier)`. Integrity loses `round(damage * wear_ratio)` (the multiplier does **not** apply to wear). Both are clamped at 0.
- `hit_body(target_hp, damage, multiplier := 1.0) -> int` (new HP)
- `burn_tick(hp: int, burning_parts: int, delta: float, dps := 5.0) -> float` (HP after burning; damage applies once if any part is burning, not per part)
- `shatter_multiplier(target_frozen: bool) -> float` (3.0 or 1.0)

- [ ] **Step 1:** Tests: `test_hit_part_full_hp_and_wear` (`hit_part(500, 100, 20)` → hp 480, integrity 90); `test_multiplier_hp_only` (×3 → hp 440, integrity 90); `test_clamps_zero`; `test_burn_once_not_per_part` (3 burning parts, 1 s → hp −5); `test_shatter`.
- [ ] **Step 2:** Run with filter `damage`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 5 passed.
- [ ] **Step 5:** Commit `feat: damage rules`.

### Task 8: Part runtime and status from sampling

**Files:** Create `game/battle/ch_part_runtime.gd`. Test: `tests/battle/test_part_runtime.gd`

**Interfaces (Produces):** `ChPartRuntime extends RefCounted`:
- Fields: `def: ChPartDef`, `side: int`, `path: Array[int]`, `flipped: bool`, `integrity: int`, `cooldown_left: float`, `charges_left: int`, `burning: bool`, `freeze: float` (0..1), `broken: bool`, `body: PixelRigidBody`, `joint: Node` (null for none), `parent: ChPartRuntime`, `children: Array[ChPartRuntime]`, `behaviour: ChBehaviour`.
- `anchor_world() -> Vector2` (`body.global_position`)
- `facing() -> Vector2` (the body's +x rotated by its rotation, negated if flipped)
- `is_frozen() -> bool` (`freeze >= 1.0`)
- `apply_sample(counts: Dictionary, delta: float, bus: ChEventBus) -> void`:
  - burning = `counts.get(&"fire",0) + counts.get(&"lava",0) + counts.get(&"burning",0) >= 3`
  - water `>= 6` extinguishes
  - frost/ice adds `0.6 * delta` per 4 cells, capped at 1.0; with none present it decays at `0.25 * delta`
  - lava wears integrity `20 * delta`
  - on the transitions not-burning → burning, freeze reaching 1.0, and leaving frozen, emits `CAUGHT_FIRE`, `FROZEN`, `THAWED` respectively
- `sample_rect() -> Rect2i` (the part's world AABB grown by 2 cells)
- `tick_cooldown(delta) -> bool` (true when it reaches 0; a frozen part's cooldown pauses; passive parts with cooldown 0 never become ready)

- [ ] **Step 1:** Tests using fake counts dicts (no world needed): `test_catches_fire_emits_once`; `test_water_extinguishes`; `test_freeze_builds_and_emits_frozen`; `test_thaw_emits`; `test_frozen_pauses_cooldown`; `test_lava_wears_integrity`.
- [ ] **Step 2:** Run with filter `part_runtime`. Expected: FAIL.
- [ ] **Step 3:** Implement. Use a fake `body` (an object with `global_position` and `global_rotation`) in the tests; the runtime only reads those.
- [ ] **Step 4:** Run. Expected: 6 passed.
- [ ] **Step 5:** Commit `feat: part runtime status from sand sampling`.

### Task 9: Chariot builder and runtime

**Files:** Create `game/battle/ch_chariot_runtime.gd`, `game/battle/ch_chariot_builder.gd`, `game/battle/ch_textures.gd` (procedural `box`/`disc`, copied from the addon demo helper under a new name). Test: `tests/battle/test_builder.gd`

**Interfaces:**
- Consumes: `ChChariotLayout`, `ChCatalog`, `ChPartRuntime`, `ChEnergy`.
- Produces: `ChChariotRuntime extends RefCounted`: `side`, `body_def`, `hp: int`, `energy: ChEnergy`, `chassis: PixelRigidBody`, `parts: Array[ChPartRuntime]` (depth-first), `wheels() -> Array[ChPartRuntime]`, `drive(direction: float) -> void` (sets wheel motors; frozen or broken wheels get the motor disabled with speed 0), `is_dead() -> bool`.
- `ChChariotBuilder.build(world: PixelWorld, parent: Node, layout: ChChariotLayout, catalog: ChCatalog, side: int, origin: Vector2, mirror_x: bool) -> ChChariotRuntime`. The chassis is one `PixelRigidBody` from `ChBodyDef`. Each part is its own `PixelRigidBody` at `origin + anchor` (x negated when `mirror_x`). Wheels get a `PixelWheelJoint` (motor torque 3e6, frequency 5, as in the addon's car demo). Other parts get a `PixelRevoluteJoint` with `enable_limit = true`, `lower_angle = 0`, `upper_angle = 0`. Children joint to their parent part's body, not to the chassis. A part's `behaviour` is instantiated from `def.behaviour` if set.

- [ ] **Step 1:** Integration tests (`make_world`, then fill the bottom 20 rows with rock):
  - `test_builds_bodies_and_joints` (Dozer + 2 wheels + strut with one child → 5 `PixelRigidBody`, 4 joints; the child's joint `body_a` is the strut's body)
  - `test_settles_on_ground` (step 120 ticks → chassis y is above the rock and roughly stable: |Δy| < 1 over the last 10 ticks)
  - `test_drive_moves_right` (`drive(1.0)` for 120 ticks → chassis x increased > 5)
  - `test_wheelless_chariot_spawns_and_fires` (Review Focus 1: a layout with only a mace → builds; `drive(1.0)` doesn't error; parts list size 1)
  - `test_mirror_x_flips_anchor` (part at body-local +10 x ends up at origin.x − 10)
- [ ] **Step 2:** Run with filter `builder`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 5 passed.
- [ ] **Step 5:** Commit `feat: build jointed chariots from layouts`.

### Task 10: Battle context, part breaking, behaviour base

**Files:** Create `game/battle/ch_battle_context.gd`, `game/battle/behaviours/ch_behaviour.gd`. Modify `ch_chariot_runtime.gd`, adding `break_part(part)`. Test: `tests/battle/test_context.gd`

**Interfaces (Produces):**
- `ChBehaviour extends RefCounted`: `part: ChPartRuntime`; overridable `setup(ctx: ChBattleContext)` (subscribe here), `fire(ctx) -> void` (called once energy is paid), `process(ctx, delta) -> void`, `modify_hit(ctx, hit: Dictionary) -> void` (passives that alter an outgoing hit from a nearby part, e.g. Freeze Charge).
- `ChBattleContext extends RefCounted`: `world: PixelWorld`, `bus: ChEventBus`, `chariots: Array[ChChariotRuntime]` (index = side), `catalog`, `time: float`, `own(part) -> ChChariotRuntime`, `enemy_of(part) -> ChChariotRuntime`, `part_of_body(body: Object) -> ChPartRuntime` (also resolves a chassis to a sentinel `null` part plus its chariot through `chariot_of_body(body)`).
  - `deal_hit(source: ChPartRuntime, target_body: Object, damage: int, extra := {}) -> void`. This is the single damage entry point. It builds `hit = {source, target_part, target_chariot, damage, multiplier: 1.0, freeze: 0.0}`, calls `modify_hit` on every behaviour on the source's side whose `proximity_range` covers the source, then the source's own behaviour, then applies `ChDamage.hit_part`/`hit_body`, adds `hit.freeze` to the target part, emits `HIT`, and breaks the target part when its integrity reaches 0.
  - `tick(delta: float, drive_input: Array[float]) -> void` runs, per chariot: the sample → `apply_sample` → cooldowns → `energy.request` for ready parts → `energy.tick` (paid parts: `behaviour.fire`, reset cooldown, decrement charges, emit `PART_FIRED`) → `behaviour.process` → burn damage via `ChDamage.burn_tick` → `drive`.
- `ChChariotRuntime.break_part(part, ctx)`: marks it broken; calls `energy.cancel` for it; unsubscribes its behaviour; frees its joint so the body falls; emits `PART_BROKEN`; recurses into its children.

- [ ] **Step 1:** Tests (world-backed; behaviours are test doubles):
  - `test_ready_part_requests_and_fires` (a double that counts `fire` calls; cooldown 1 s, cost 1; 2.1 s of ticks → 2 fires)
  - `test_break_removes_from_queue_and_cascades` (Review Focus 3: the energy is at 0 and the strut's child is queued; break the strut → the child is broken too, `queue_size() == 0`, two `PART_BROKEN` events; 60 more ticks raise no errors)
  - `test_deal_hit_applies_modifiers_in_range` (a double modifier sets `multiplier = 2` with range 24: in range → HP drops 2× damage; out of range → 1×)
  - `test_burning_damages_hp_once`
- [ ] **Step 2:** Run with filter `context`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 4 passed.
- [ ] **Step 5:** Commit `feat: battle context, hit pipeline, part breaking`.

### Task 11: Arena builder

**Files:** Create `game/battle/ch_arena_builder.gd`. Test: `tests/battle/test_arena.gd`

**Interfaces (Produces):** `ChArenaBuilder.build(world: PixelWorld, rng_seed: int) -> Dictionary` with `{ "spawn_left": Vector2, "spawn_right": Vector2 }`. The world must use `arena = Rect2i(0, 0, 480, 180)` and `arena_border_material = &"concrete"`. Layers, top to bottom:
- air down to a surface line around y = 110 (a gentle noise of ±6)
- 6–10 rows of sand, with 2 wood patches (about 20×6) and 2 water pools (about 30×6) sunk into the surface, kept away from the spawn zones
- rock from about y = 125 to 179, with 2 lava pools (about 24×8) at y ≈ 140–160 under the middle third

The spawns are at x = 60 and x = 420, 30 cells above the surface.

- [ ] **Step 1:** Tests: `test_walls_concrete_and_indestructible` (`explode` at (2, 120) radius 10 → `get_material_at(Vector2i(-1,120)) == &"concrete"`); `test_layers_present` (`count_materials` over the arena has sand, wood, water, rock and lava all > 0); `test_no_caves` (every column has no air below its first solid/powder cell, except where water or lava are); `test_spawns_above_surface`.
- [ ] **Step 2:** Run with filter `arena`. Expected: FAIL.
- [ ] **Step 3:** Implement with `fill_rect`/`fill_circle`/`set_cell`, using a `FastNoiseLite` seeded by `rng_seed` for the surface.
- [ ] **Step 4:** Run. Expected: 4 passed.
- [ ] **Step 5:** Commit `feat: walled sand arena`.

### Task 12: Melee and passive behaviours (Mace, Chainsaw, Freeze Charge, Ember Battery, Wheel, Strut)

**Files:** Create `game/battle/behaviours/{ch_mace,ch_chainsaw,ch_freeze_charge,ch_ember_battery}.gd` and set `behaviour` in the matching part `.tres`. Wheel and Strut need no behaviour. Test: `tests/battle/test_behaviours_melee.gd`

**Interfaces:** Consumes `ChBehaviour`, `ChBattleContext.deal_hit`, `ChEventBus`.

Behaviour rules:
- **Melee reach** (my call: the spec suggested a new C++ contact query; the existing per-body hit signal only fires on contact begin, so reach is done geometrically instead). On `fire`, test the reach box (`def` reach × part height, extending along `facing()` from the part's edge) against every enemy body's AABB. Hit the nearest one through `deal_hit`.
- **Mace:** on `modify_hit` for its own hits, if the target part `is_frozen()`, set `multiplier *= ChDamage.shatter_multiplier(true)` and set `target_part.freeze = 0` after the hit (emit `THAWED`).
- **Chainsaw:** on `fire`, also `world.spawn_particles(&"fire", tip, facing*40, 4, 0.6)` as sparks, and emit `CELLS_CUT` (Chainsaw cuts from contact are hits; terrain cutting uses `explode(tip, 2, 50)` when no body is in reach and the tip touches solid ground).
- **Freeze Charge:** passive. `modify_hit` adds `hit.freeze += 0.5` for hits from same-side parts within `proximity_range` 24; the context then adds it to the target part's `freeze`.
- **Ember Battery:** subscribes globally to `CAUGHT_FIRE` (both sides). It adds 3 energy to its own chariot (clamped to cap) and emits `ENERGY_GAINED`, with an internal cooldown of 0.5 s.

- [ ] **Step 1:** Tests (world-backed; two chariots 20 cells apart on rock):
  - `test_mace_hits_in_reach_only`
  - `test_mace_shatters_frozen` (target freeze 1.0 → HP loss = 60, freeze reset)
  - `test_freeze_charge_freezes_wheel` (a mace within 24 of a freeze charge hits a wheel twice → wheel `is_frozen()`; enemy `drive(1)` → no motor speed on that wheel)
  - `test_freeze_charge_out_of_range_no_effect`
  - `test_ember_battery_gains_on_any_caught_fire` (emit `CAUGHT_FIRE` from the enemy side → energy +3; a second emit within 0.5 s → +0)
  - `test_chainsaw_sparks_emit_cells_cut`
- [ ] **Step 2:** Run with filter `behaviours_melee`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 6 passed.
- [ ] **Step 5:** Commit `feat: melee and passive part behaviours`.

### Task 13: Ranged behaviours (Rocket, Firebolt, Harpoon)

**Files:** Create `game/battle/behaviours/{ch_rocket,ch_firebolt,ch_harpoon}.gd`, `game/battle/ch_projectile.gd`. Test: `tests/battle/test_behaviours_ranged.gd`

**Interfaces (Produces):** `ChProjectile extends Node2D`: `setup(ctx, source: ChPartRuntime, velocity: Vector2, gravity: float, on_impact: Callable)`. Each physics frame it moves and checks the segment with `world.raycast(prev, next)`. On a hit it calls `on_impact(result: Dictionary)` (the raycast dict, with `collider` when a body is hit) and frees itself. It also frees itself after 3 s or when leaving the arena.

Behaviour rules:
- **Rocket:** straight projectile at 160 cells/s along `facing()`. On impact: `explode(pos, 6, 300)`; `deal_hit` if a body is hit. Subscribes globally to `CAUGHT_FIRE`: each event sets `part.cooldown_left *= 0.5` (Ignition).
- **Firebolt:** a lobbed projectile (60° up from facing, 110 cells/s, gravity 120). On impact: `explode(pos, 8, 300)`, `fill_circle(pos, 4, &"fire")`, `deal_hit` if a body is hit. It uses `charges_left` (5); at 0 it never requests energy again.
- **Harpoon:** `world.raycast(anchor, anchor + facing*120, RAY_BODIES | RAY_SOLID)`. If the collider is an enemy body, `deal_hit(5)` and, for 1.5 s, `apply_force` that body toward the harpoon anchor (with an equal and opposite force on own chassis). A `Line2D` is drawn while attached.

- [ ] **Step 1:** Tests: `test_rocket_explodes_and_damages`; `test_rocket_ignition_halves_cooldown`; `test_firebolt_charges_run_out` (after 5 fires `charges_left == 0`, and a 6th ready tick makes no energy request); `test_firebolt_starts_fire` (`count_materials` near the impact has fire or burning > 0 within 10 ticks); `test_harpoon_pulls_enemy_closer` (the distance between chassis decreases over 1.5 s compared with a no-harpoon control); `test_harpoon_misses_out_of_range`.
- [ ] **Step 2:** Run with filter `behaviours_ranged`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 6 passed.
- [ ] **Step 5:** Commit `feat: ranged part behaviours`.

### Task 14: Fire emitter behaviours (Flamethrower, Hearth, Ring of Fire)

**Files:** Create `game/battle/behaviours/{ch_flamethrower,ch_hearth,ch_ring_of_fire}.gd`. Test: `tests/battle/test_behaviours_fire.gd`

Behaviour rules:
- **Flamethrower:** for 1 s after `fire`, each tick `spawn_particles(&"fire", nozzle, facing*90, 3, 0.25)`. Its direct damage of 45 is spread over the burst (via the reach test at 40 cells, ticking `deal_hit` 9 × 5). The burn itself comes from the sim.
- **Hearth:** on `fire`, it starts a 1 s charge (a visual tint), then for 3 s it places fire cells into air cells in a 2-cell ring around the own chassis AABB, every 0.25 s. Enemy bodies whose AABB overlaps that ring get `deal_hit(5)` per pulse (45 total over 9 pulses).
- **Ring of Fire:** an expanding ring from the part's anchor, radius 0 → 24 over 1 s. Each 0.1 s it fills fire into air cells on the ring circumference, and `deal_hit(10)` once per body (**both sides, own chassis included**) the first time the ring crosses it.

- [ ] **Step 1:** Tests: `test_flamethrower_sets_target_burning` (an enemy part within 30 cells → its `burning` becomes true within 1.5 s, and a `CAUGHT_FIRE` event is seen); `test_hearth_damages_touching_enemy_only_after_charge`; `test_ring_of_fire_hits_self_and_enemy_once_each`; `test_ember_battery_pays_for_own_hearth` (chain 3: own Hearth + Ember Battery → an `ENERGY_GAINED` event within 3 s).
- [ ] **Step 2:** Run with filter `behaviours_fire`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 4 passed.
- [ ] **Step 5:** Commit `feat: fire emitter behaviours`.

### Task 15: Battle scene (HUD, AI, win/lose)

**Files:** Create `game/battle/ch_enemy_ai.gd`, `game/battle/ch_battle.gd`, `game/battle/battle.tscn`. Test: `tests/battle/test_battle.gd`

**Interfaces (Produces):**
- `ChEnemyAI.decide(self_x: float, target_x: float, preferred_range: float) -> float` (−1, 0 or 1). Moves toward the target until |dx| ≤ preferred_range, then 0. `preferred_range` is the shortest weapon reach on the chariot (Harpoon range counts only when the Harpoon is ready).
- `ChBattle extends Node2D`: `start(player_layout: ChChariotLayout, enemy_layout: ChChariotLayout, catalog: ChCatalog, seed: int) -> void`; `signal finished(result: StringName)` with `&"win"` or `&"loss"`; `result_for(player_dead: bool, enemy_dead: bool) -> StringName` (static; both dead → `&"loss"`). Input actions: `ui_left`/`ui_right` plus A/D, added to the InputMap at runtime if missing.
- **HUD** (CanvasLayer at 320×180): HP bars for both sides, the player's energy bar with queue-size pips, a short event ticker (the last 4 events as text), and per-part markers drawn at each part (a red outline when burning, a blue tint when frozen, an X when broken). On each `PART_FIRED`/`ENERGY_GAINED` from the player, a 0.2 s pulse on that part. This addresses the "chains you can see" anti-goal.
- **Camera:** a `Camera2D` at the midpoint of both chassis. It zooms out so both fit, clamped to the arena.

- [ ] **Step 1:** Tests: `test_ai_approaches_then_holds`; `test_simultaneous_death_is_loss` (Review Focus 4: `result_for(true, true) == &"loss"`); `test_battle_finishes` (headless: player Cutter + Rocket vs. the enemy with HP overridden to 30, simulated up to 60 s of ticks → `finished` emitted once with `&"win"`); `test_finished_emitted_once` (ticks continue after the end → no second emit).
- [ ] **Step 2:** Run with filter `battle`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: 4 passed.
- [ ] **Step 5:** Commit `feat: battle scene with HUD, enemy AI and result`.

### Task 16: Garage scene and main flow

**Files:** Create `game/garage/ch_garage.gd`, `game/garage/garage.tscn`, `game/ch_main.gd`, `game/main.tscn`. Modify `project.godot` so `run/main_scene` is `res://game/main.tscn`. Test: `tests/test_garage.gd`

**Interfaces (Produces):**
- `ChGarage extends Control`: `setup(inventory: ChInventory, layout: ChChariotLayout, catalog: ChCatalog)`; `signal fight_requested(layout: ChChariotLayout)`. These are the logic methods the UI calls and the tests use: `drop_part(part_id, path) -> bool` (takes from inventory and places), `lift(path)` (returns the whole subtree to inventory), `click_part(path)` (toggles the flip), `cycle_body()` (Cutter → Dozer → Corsair → Cutter, via `swap_body`, with leftovers added to inventory), `selected_info(path) -> Dictionary` (`{name, cost, cooldown, hook_text, range}`).
- **UI:** the body is drawn at 3× zoom in the centre with slot markers, and an empty extension-slot marker appears when its parent is placed. The inventory is a list on the left (drag source). A click on a placed part flips it. Hovering shows the info panel, and the proximity range is drawn as a circle. Buttons: "Body ▶" and "Fight".
- `ChMain extends Node`: holds the `ChInventory` (unlimited capacity, holding 2 of each part and 4 wheels) and the current layout. It shows the garage, swaps to the battle on `fight_requested` (with the enemy `dozer_cook.tres`), shows the result for 2 s on `finished`, then returns to the garage with the layout unchanged.

- [ ] **Step 1:** Tests: `test_drop_takes_from_inventory`; `test_lift_returns_subtree` (strut + child lifted → both ids back in inventory); `test_click_flips`; `test_cycle_body_keeps_parts_and_returns_leftovers`; `test_fight_emits_layout_copy` (the emitted layout is not the same instance, so the battle can't mutate the garage's layout).
- [ ] **Step 2:** Run with filter `garage`. Expected: FAIL.
- [ ] **Step 3:** Implement the logic, then the UI on top of it.
- [ ] **Step 4:** Run the whole suite: `godot --headless --path . --script res://tests/run_tests.gd`. Expected: all tests pass, `0 failed`.
- [ ] **Step 5:** Manual check: `godot --path .`. Build Corsair + Chainsaw + Ember Battery + Rocket + Freeze Charge near the front, with 2 wheels, then fight. Confirm by eye that chains 1–3 from the spec §5.6 are visible (the event ticker shows `caught_fire` → `energy_gained`; an enemy wheel shows frozen; the Mace pulse does triple damage). Record what you saw in the commit message.
- [ ] **Step 6:** Commit `feat: garage and main loop`.

---

## Deviations from the spec

- **Melee hit detection is geometric in GDScript, not a new C++ contact query.** The engine already emits `hit(other, point, normal, speed)` per body, but only when a contact begins. The weapons fire on cooldowns, so a reach-box test at fire time matches the design better and needs no engine change. The C++ additions are therefore `indestructible`, `arena_border_material` and `count_materials`. `count_materials` is new and is needed so that sampling the status of ~12 parts every tick isn't hundreds of `get_material_at` calls.
