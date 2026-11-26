# Garage and Battle UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the slice playable. The garage gets a click-to-hold parts strip under a centred chariot, the battle camera shows both chariots up close, the HUD is sharp, and a result panel ends each fight.

**Architecture:** The viewport goes to 1280×720. The world and the chariots draw through a zoom with nearest filtering, and every piece of UI is a Godot Control styled by one code-built Theme. Parts get real cell sizes. An engine-level collision group stops a chariot's own parts from colliding with each other. `ChBattle` gets a real end, so `ChMain` drops its hide-and-retire machinery.

**Tech Stack:** Godot 4.7.2 (GDScript), the `noita_engine` GDExtension (C++17, Box2D v3, scons), and the project's headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-04-garage-battle-ui-design.md`

## Global Constraints

- Run the tests with `godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]`. The output ends `N passed, M failed`, and the exit code is non-zero on a failure. Every task ends with the whole suite green.
- Build the engine with `addons/noita_engine/build.sh`, which writes `addons/noita_engine/bin/libnoita_engine.linux.template_debug.x86_64.so`.
- Viewport 1280×720, stretch mode `canvas_items`, aspect `keep`. Keep `default_texture_filter=0`.
- **No hint or instruction lines on either screen.** In battle: no YOU/ENEMY tags, no event feed or ticker, no "A / D drive" hint.
- No paging in the parts strip. A part is drawn at the garage zoom in its card, in your hand and on the hull.
- Placing a part is click, then click. There is no hold-to-drag.
- Slot and extension positions in `game/data/bodies/*.tres` and `strut.tres` do not change.
- Do not reuse Box2D `groupIndex` for the chariot group. It carries the cell-proxy group.
- Placeholder art only: flat colours from each def's `color`.

## Review Focus

1. **Clicking Fight, or switching body, while holding a part.** The held part must not be lost or duplicated. Nothing leaves the inventory until a drop, so the hold just clears. Pinned in Task 7 (`test_fight_while_holding_keeps_inventory`).
2. **A card whose count is 0.** It stays visible but cannot be picked. Picking the last copy of a part and then dropping it greys out its card. Pinned in Task 7 (`test_pick_empty_refused`).
3. **Pressing "Back to garage" twice in quick succession.** Exactly one garage ends up in the tree and the battle is freed once. Pinned in Task 6 (`test_back_twice_one_garage`).
4. **Wide parts sharing a strut's two extension slots, which are 4 cells apart.** In a real fight the chariot must not fly apart or jitter. Pinned in Task 2 (`test_strut_pair_holds_still`).
5. **A fight that times out with both hulls standing.** It must show the panel with a draw, not hang on the battle screen. Pinned in Task 3 (`test_timeout_is_draw`) and Task 6 (`test_main_draw_panel`).

---

### Task 1: Engine collision group

**Files:**
- Modify: `addons/noita_engine/engine/core/physics.h` (`BodyProps`)
- Modify: `addons/noita_engine/engine/core/physics.cpp` (`body_shape_def`, `PhysicsWorld::PhysicsWorld`, new filter callback)
- Modify: `addons/noita_engine/engine/godot/pixel_rigid_body.h`, `pixel_rigid_body.cpp` (property)
- Test: `tests/engine/test_engine_additions.gd`

**Interfaces:**
- Produces: `PixelRigidBody.collision_group: int`, default 0. Two bodies with the same non-zero group never collide. Every other pair behaves as it does today.

- [ ] **Step 1: Write the failing tests** in `tests/engine/test_engine_additions.gd`. Use `make_world()`, then add two 10×4 `PixelRigidBody` boxes (built with `ChTextures.box`, `pixel_material = &"wood"`, `gravity_scale = 0`) whose centres are 3 cells apart, so they overlap.
  - `test_same_group_bodies_overlap_freely`: both have `collision_group = 1`. After 30 frames, each body has moved by less than 0.5 cells.
  - `test_different_group_bodies_still_collide`: the groups are 1 and 2. After 30 frames, the gap between the centres has grown by more than 1 cell.
  - `test_collision_group_defaults_to_zero`: `PixelRigidBody.new().collision_group == 0`.
- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- collision_group` and `-- group_bodies`. Expected: FAIL, because the property does not exist.
- [ ] **Step 3: Implement.**
  - Add `int collision_group = 0;` to `BodyProps`.
  - In `body_shape_def`, set `sd.enableCustomFiltering = true;`.
  - In the constructor, register a static callback with `b2World_SetCustomFilterCallback(world, &group_filter, this)`. It maps each shape to its handle through `handle_of(b2Shape_GetBody(shape))` and returns `false` only when both handles are live bodies with an equal non-zero `props.collision_group`.
  - The callback may run on Box2D worker threads, so it must only read.
  - Bind `set_collision_group`/`get_collision_group` and `ADD_PROPERTY(Variant::INT, "collision_group")` the way `terrain_collision` does, calling `apply_props()`.
- [ ] **Step 4: Measure overlapping stamps.** Extend `test_same_group_bodies_overlap_freely` so it reads `world.count_materials` over the union of both footprints, both on frame 1 and after 30 frames. If the count changes (stamped cells are lost or duplicated), fix it in this task: same-group bodies must not erase each other's stamped cells. Then assert that the count is stable.
- [ ] **Step 5: Build and run** `addons/noita_engine/build.sh && godot --headless --path . --script res://tests/run_tests.gd`. Expected: build OK and `0 failed`.
- [ ] **Step 6: Commit** with the message `feat(engine): per-body collision group`.

### Task 2: Real part sizes, one group per chariot

**Files:**
- Modify: `game/data/parts/*.tres` (11 files, `size =`)
- Modify: `game/battle/ch_chariot_builder.gd` (`build`, `_body`)
- Test: `tests/battle/test_builder.gd`, plus whatever `tests/battle/*` expectations shift

**Interfaces:**
- Consumes: `PixelRigidBody.collision_group` (Task 1).
- Produces: every chassis and part body of side `s` has `collision_group == s + 1`.

- [ ] **Step 1: Write the failing tests** in `test_builder.gd`.
  - `test_parts_have_real_sizes`: `ChCatalog.load_default()` part sizes equal these exactly. Mace 8×4, Chainsaw 10×4, Flamethrower 8×4, Hearth 6×6, Rocket 8×3, Harpoon 10×3, Ember Battery 5×5, Firebolt 8×4, Ring of Fire 6×6, Freeze Charge 4×4, Strut 3×8, Wheel 12×12.
  - `test_chariot_shares_one_group`: build a Dozer for side 0 and one for side 1. Every body on side 0 has group 1, every body on side 1 has group 2.
  - `test_strut_pair_holds_still`: a Cutter with wheels on slots [0] and [1], a strut on [2], and a Chainsaw on [2,0] and a Flamethrower on [2,1]. Build it on `_ground`, then step 180 frames. Each part's anchor stays within 1.5 cells of where `layout.anchor_of` puts it relative to the chassis, and the chassis turns by less than 0.2 rad over the last 30 frames.
- [ ] **Step 2: Run** `-- test_builder`. Expected: the three new tests FAIL.
- [ ] **Step 3: Implement.** Write `size = Vector2i(w, h)` into each part `.tres`. In `ChChariotBuilder.build`, pass `side + 1` into `_body` as a new parameter `group: int` and set `body.collision_group = group` before `add_child`.
- [ ] **Step 4: Run the whole suite.** Fix the battle tests whose measured expectations moved because parts got real sizes, such as the flamethrower margin pin, AI reach and chain timings. Re-measure each one and update its value and comment. Do not weaken an assertion into a tautology. If a starter build or `dozer_cook` no longer spawns, drives and fights, fix the cause and record it in the commit message. Expected: `0 failed`.
- [ ] **Step 5: Commit** with the message `feat: parts get real sizes; a chariot's parts share a collision group`.

### Task 3: A fight that ends

**Files:**
- Modify: `game/battle/ch_battle.gd` (`start`, `_step`)
- Test: `tests/battle/test_battle.gd`

**Interfaces:**
- Produces:
  - `finished(result)` is emitted exactly once, with a result of `&"win"`, `&"loss"`, `&"draw"` (the time limit ran out) or `&"aborted"`.
  - **`ticking` is already false and `world.simulating` already false when `finished` fires**, so a caller may free the node on any later frame.
  - `FIGHT_TICKS` stays 3600.
  - The hidden-pause branch (`visible != shown`) goes away.

- [ ] **Step 1: Rewrite and add the tests.**
  - `test_finished_emitted_once` becomes `test_fight_stops_at_result`: a win, `results == [&"win"]`, `battle.ticking == false`, `battle.world.simulating == false`, and `battle.ctx.time < FIGHT_SECONDS - 1.0`.
  - `test_timeout_is_draw`: give both sides 100000 HP through `_catalog(...)`, or add a sibling helper. Then `results == [&"draw"]` and `ctx.time` is within one TICK of `FIGHT_SECONDS`.
  - Add `test_finished_after_ticking_stops`: inside the `finished` handler, record `battle.ticking`, and assert that it is `false`.
- [ ] **Step 2: Run** `-- test_battle`. Expected: the three FAIL.
- [ ] **Step 3: Implement.** In the tick loop, `break` once `_step` has produced a result. After the loop, set `ticking = false` and `world.simulating = false`, then emit the stored result, or `&"draw"` if there is none. `_step` stores the result and no longer emits it.
- [ ] **Step 4: Delete the obsolete ChMain tests.** These three in `tests/test_garage.gd` assert that a fight keeps ticking after its result, which is no longer true: `test_main_watchdog_returns`, `test_result_window_returns_over_a_still_ticking_fight` and `test_starting_a_second_fight_retires_the_hidden_one`. Task 6 writes their replacements. Run the whole suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** with the message `feat: a fight stops at its result and freezes the world`.

### Task 4: Screen size, close camera, closer spawns

**Files:**
- Modify: `project.godot` (`[display]`)
- Modify: `game/battle/ch_battle.gd` (`VIEW`, `_camera_at`, new static `camera_frame`)
- Modify: `game/battle/ch_arena_builder.gd` (`SPAWN_LEFT_X`, `SPAWN_RIGHT_X`)
- Create: `tools/screenshot.gd` (a SceneTree script, not a test)
- Test: `tests/battle/test_battle.gd`, `tests/battle/test_arena.gd`

**Interfaces:**
- Produces:
  - `ChBattle.VIEW := Vector2(1280, 720)`, `ZOOM_WIDEST := 4.0` and `ZOOM_CLOSEST := 8.0`.
  - `static func camera_frame(a: Vector2, b: Vector2, pad: Vector2) -> Dictionary` returns `{"at": Vector2, "zoom": float}`. Here `zoom = clamp(min(VIEW.x / box.x, VIEW.y / box.y), ZOOM_WIDEST, ZOOM_CLOSEST)`, snapped down to a multiple of 0.5, where `box` is the a–b span plus `pad` on every side. `at` is clamped so the view `VIEW / zoom` stays inside `ARENA`.
  - `_camera_at` eases the live camera toward `camera_frame`, at a rate of 0.15 per tick on both position and zoom.
  - The spawns are `SPAWN_LEFT_X := 170` and `SPAWN_RIGHT_X := 310`.

- [ ] **Step 1: Write the failing tests.**
  - `test_camera_frames_both`: for a=(170,100), b=(310,100), pad=(48,24), the view rect centred on `at` with size `VIEW / zoom` contains both a±pad and b±pad. The zoom lies in [4, 8] and is a multiple of 0.5.
  - `test_camera_close_when_close`: for a=(230,100), b=(250,100), the zoom is 8.
  - `test_camera_stays_in_arena`: for a=(10,170), b=(30,170), the view rect lies inside `ChBattle.ARENA`.
  - Update `test_arena.gd`'s `SPAWN_LEFT_X`/`SPAWN_RIGHT_X` to 170 and 310.
- [ ] **Step 2: Run** `-- camera` and `-- test_arena`. Expected: FAIL.
- [ ] **Step 3: Implement** `camera_frame` and the eased `_camera_at`, set the spawn constants, and edit the arena builder's comment about the 60-cell clearance to describe the new spawns. In `project.godot`, set `viewport_width=1280`, `viewport_height=720`, `window/stretch/aspect="keep"`, and remove `window/size/mode=2` only if it fights the letterbox.
- [ ] **Step 4: Create `tools/screenshot.gd`.** Base it on the shot script from the design session. It loads `main.tscn`, mounts wheels on [0],[1] and a mace on [3], saves `garage.png`, requests a fight, waits 400 frames, and saves `battle.png` into the directory given in `-- <outdir>`. Run it with `godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- <scratch dir>` and open `battle.png`. Expected: both chariots, wheels and parts are visible in the frame, and the sand is crisp.
- [ ] **Step 5: Run the whole suite.** Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `fix: battle camera frames both chariots up close; 1280x720 letterboxed`.

### Task 5: Shared theme and the battle HUD

**Files:**
- Create: `game/ui/ch_ui.gd` (`class_name ChUi`)
- Create: `game/battle/ch_battle_hud.gd` (`class_name ChBattleHud extends Control`)
- Modify: `game/battle/ch_battle.gd` (`_build_hud`, `_hud_tick`, `_hear`, remove the ticker, `_bar` and `_pips`)
- Test: `tests/battle/test_battle_hud.gd`

**Interfaces:**
- Produces:
  - `ChUi.theme() -> Theme`, built in code and cached. It sets a default font size of 20, `Button` and `PanelContainer` StyleBoxFlats in dark grey (`#1d1d22` panels, `#3c3c46` buttons), and an accent.
  - `ChUi.ACCENT := Color("#e8c35a")`, `ChUi.GO := Color("#b5532d")`, `ChUi.HP_PLAYER := Color("#4fbf5a")` and `ChUi.HP_ENEMY := Color("#d9594d")`.
  - `ChBattleHud.show_state(player: ChChariotRuntime, enemy: ChChariotRuntime) -> void` sets:
    - `player_name.text` to the player's `body_def.display_name`
    - `player_hp.text` to `"%d / %d"`
    - the fill fraction of each HP bar (`ProgressBar.value`, 0–100)
    - `energy_pips`, one per energy unit up to `cap`, with `round(value)` of them lit
    - `waiting.text` to `"%d parts waiting" % queue_size()`, shown only when the queue is non-empty
    - the same name and HP fields for the enemy.

- [ ] **Step 1: Write the failing tests** in `test_battle_hud.gd`, using fake runtimes built the way `test_battle.gd` builds them.
  - `test_hud_shows_hp`: hp 78 of 100 gives `player_hp.text == "78 / 100"` and a player bar value of 78.
  - `test_hud_energy_pips`: cap 6 and value 3.2 give 6 pips, 3 of them lit.
  - `test_hud_waiting_hidden_when_empty`: queue 0 means `waiting.visible == false`. Queue 2 gives `"2 parts waiting"`.
  - `test_battle_has_no_ticker`: after `start`, `battle.hud` has no Label whose text matches an event type name.
- [ ] **Step 2: Run** `-- hud`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `ChBattleHud` lays out in a 1280×720 Control under `$HUD`, with `theme = ChUi.theme()`. The player's block sits at the top left (name, then a 320×20 bar, then pips and waiting) and the enemy's at the top right (name and bar).
  - `ChBattle._build_hud` instances the HUD, and `_hud_tick` calls `show_state`.
  - Delete `ticker_labels`, `ticker_text`, `bars`, `pips`, `_bar` and `_pips`.
  - `_hear` keeps only the pulse.
- [ ] **Step 4: Run the whole suite and `tools/screenshot.gd`.** Expected: `0 failed`. The HUD in `battle.png` is sharp and has no tags, feed or hints.
- [ ] **Step 5: Commit** with the message `feat: sharp battle HUD on a shared theme; ticker removed`.

### Task 6: Result panel, ChMain simplified

**Files:**
- Create: `game/ui/ch_result_panel.gd` (`class_name ChResultPanel extends PanelContainer`)
- Modify: `game/ch_main.gd`
- Test: `tests/test_garage.gd` (the ChMain section)

**Interfaces:**
- Consumes: Task 3's `finished` contract (the fight is stopped when it fires).
- Produces:
  - `ChResultPanel.show_result(result: StringName) -> void`. Its title text is `"You win"`, `"You lose"`, `"Draw: time ran out"` or `"No fight: the battle could not start"`, plus a `back: Button` with the text `"Back to garage"`, and `signal back_pressed`.
  - `ChMain.screen` is one of `&"garage"`, `&"fight"` or `&"result"`, and `ChMain.result_panel: ChResultPanel`. Pressing back frees the battle and the panel and calls `_show_garage()`.
  - Remove `retiring`, `_retire_current`, `_release_retiring`, `_release_battle`'s ticking checks, `_hold_fight`, `RESULT_SECONDS`, `WATCHDOG_TEXT`, `FIGHT_TEXT` and the bottom-left `label`.

- [ ] **Step 1: Write the new ChMain tests.** Task 3 deleted the old ones. Write:
  - `test_main_round_trip` (rewritten): mount and fight with a low-HP enemy, then wait for `screen == &"result"`. The panel title is `"You win"` and the garage is not visible. Call `result_panel.back.pressed.emit()`, and the garage is visible again with the same layout paths and part ids as before the fight. `main.battle == null`.
  - `test_main_draw_panel`: both sides get huge HP, and the title is `"Draw: time ran out"`.
  - `test_back_twice_one_garage`: after a result, emit back twice in the same frame. Exactly one `ChGarage` is a child of main, and nothing errors.
- [ ] **Step 2: Run** `-- main`. Expected: FAIL.
- [ ] **Step 3: Implement.** `_on_finished` builds the panel centred on screen with `ChUi.theme()`. The back handler is idempotent: it returns when `screen != &"result"`.
- [ ] **Step 4: Run the whole suite and `tools/screenshot.gd`.** Extend the tool to also save `result.png` after a forced win. Expected: `0 failed` and a centred panel.
- [ ] **Step 5: Commit** with the message `feat: result panel with Back to garage; ChMain drops hide-and-retire`.

### Task 7: Garage rebuild

**Files:**
- Modify: `game/garage/garage.tscn` (rebuilt for 1280×720)
- Modify: `game/garage/ch_garage.gd`
- Create: `game/garage/ch_part_card.gd` (`class_name ChPartCard extends Button`)
- Test: `tests/test_garage.gd`

**Interfaces:**
- Consumes: `ChUi.theme()` and its colours (Task 5).
- Keeps, unchanged in behaviour: `setup`, `drop_part`, `lift`, `click_part` (flip), `selected_info`, `request_fight` and `fight_requested`.
- Produces:
  - `ZOOM := 6.0` and `CHARIOT_AT := Vector2(640, 300)` (pit centre, in garage-local pixels).
  - `STRIP_ORDER := [&"wheel", &"ice_cream_mace", &"cutter_chainsaw", &"flamethrower", &"hearth", &"cutter_rocket", &"corsair_harpoon", &"ember_battery", &"firebolt_launcher", &"ring_of_fire", &"freeze_charge", &"strut"]`.
  - `held_id: StringName`, which is `&""` when nothing is held.
  - `pick_part(id: StringName) -> bool` holds a carried part. It refuses a count of 0. Picking the held id again clears the hold.
  - `click_pit(pointer: Vector2) -> void`. While holding: a free slot within `MARK_PX` gets `drop_part`, and then the hold clears; anywhere else just clears the hold. While not holding: a mounted part under the pointer is `lift`ed.
  - `right_click_pit(pointer: Vector2) -> void` flips the mounted part under the pointer.
  - `cancel_hold() -> void`.
  - `cycle_body(step: int = 1) -> void`. A `step` of -1 walks backwards.
  - `screen_of(path) -> Vector2`, which is the existing `_at` made public.
  - `card_counts() -> Dictionary`, mapping each id to its carried count for every id in `STRIP_ORDER`.
  - `request_fight` and `cycle_body` call `cancel_hold()` first.

- [ ] **Step 1: Write the failing tests** in `tests/test_garage.gd`. They use a bare `ChGarage` off the tree, as the existing tests do.
  - `test_pick_and_place`: carry 2 wheels on a Cutter, `pick_part(&"wheel")`, then `click_pit(screen_of([0]))`. Slot [0] holds a wheel, `card_counts()[&"wheel"] == 1` and `held_id == &""`.
  - `test_pick_empty_refused`: carrying 0 maces, `pick_part(&"ice_cream_mace")` returns false.
  - `test_click_elsewhere_cancels`: pick, then `click_pit(Vector2(5, 5))`. The hold is cleared and the counts are unchanged.
  - `test_click_mounted_lifts`: mount a strut with a wheel under it, then `click_pit(screen_of([1]))` with nothing held. Both come back.
  - `test_right_click_flips`: `right_click_pit(screen_of([1]))` toggles the flip.
  - `test_cycle_back`: from Cutter, `cycle_body(-1)` lands on Corsair.
  - `test_fight_while_holding_keeps_inventory`: pick a wheel, then `request_fight()`. The hold is cleared and the inventory is identical.
  - `test_drop_onto_strut_extension`: mount a strut on [2], pick a Chainsaw, then `click_pit(screen_of([2, 0]))`, and it mounts there.
  - `test_strip_has_every_part`: the instanced `garage.tscn` has 12 `ChPartCard`s in `STRIP_ORDER`, and a card with count 0 has `disabled == true`.
  - `test_no_hint_labels`: no Label in the instanced scene has text starting "Click" or "Holding".
- [ ] **Step 2: Run** `-- test_garage`. Expected: the new tests FAIL and the existing logic tests still PASS.
- [ ] **Step 3: Build the scene.** The root is a full-rect Control with `theme = ChUi.theme()`.
  - `TopBar`: a 60px tall HBox containing `PrevBody`/`BodyName`/`NextBody`, a `Stats` label (`"HP %d · Energy %d"`), a spacer and a `FightButton` in `ChUi.GO`.
  - `Pit`: a Control filling the middle, which handles `_gui_input`. A left click calls `click_pit`, a right click calls `right_click_pit`, and the pit draws the hull, dashed free slots (the one nearest the pointer, within `MARK_PX`, is filled with `ChUi.ACCENT` at 20% while holding), mounted parts, an outline on the hovered mounted part, and its range circle. Hovering a mounted part fills the InfoPanel.
  - `InfoPanel`: a PanelContainer at the top right of the pit, showing `selected_info` as name, `"Cost %d · Cooldown %.1fs"`, and the hook text. It is hidden when nothing is hovered.
  - `Strip`: a 160px PanelContainer containing a horizontal-only ScrollContainer and an HBox of `ChPartCard`s.
  - `HeldLayer`: the last child, full rect, with `mouse_filter = IGNORE`. It draws the held part at the pointer at `ZOOM`.
  - A left click on any empty part of the root calls `cancel_hold()`.
- [ ] **Step 4: Implement `ChPartCard`.** It has `part_id`, draws the def's colour box (a disc for the wheel) at `ZOOM` with `def.size`, and shows the name plus `"Cost %d"` in the top left and `"×%d"` in the top right. Its width is `max(88, def.size.x * ZOOM + 16)`. `pressed` calls `garage.pick_part(part_id)`, and the card is disabled when its count is 0. Hovering it fills the InfoPanel from the def.
- [ ] **Step 5: Remove** `_process` polling, `left_held`, `drag_id`, `_pick_up`, `_put_down`, `row_labels`, `_inventory_rows`/`_refresh_rows` and `_row_at`.
- [ ] **Step 6: Run the whole suite and `tools/screenshot.gd`.** Expected: `0 failed`. `garage.png` shows the centred hull with its parts at the same scale as the cards, 12 cards in one row, sharp text, and no hint line.
- [ ] **Step 7: Play it.** Run `godot --path .`, then mount wheels and two weapons, flip one, swap the body, fight, win or lose, and go back. Every step works using the mouse plus A/D. Note anything off in the commit message.
- [ ] **Step 8: Commit** with the message `feat: garage with centred chariot and click-to-hold parts strip`.
