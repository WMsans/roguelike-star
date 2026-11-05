# Feedback System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One central feedback manager that makes battle parts, the chassis, garage cards, pit parts and UI buttons pop and wobble Balatro-style on every event, with pop-up text, pixel particles and screen shake.

**Architecture:** A `Feedback` autoload (`ChFeedbackManager`) plays named kinds described by `ChFeedbackProfile` resources. Each target gets a `ChJuice` child that holds two damped springs (scale, rotation) and applies them to its parent; a kind "kicks" those springs. In battle, each physics body stops drawing itself and a `Visual` Sprite2D child carries the art and the juice; `ChBattleFeedback` turns bus events into kinds. Shake goes through Phantom Camera, text through GodotRichTextLabel2, battle particles through `PixelWorld.spawn_visual_particles`.

**Tech Stack:** Godot 4.7.2, GDScript, noita_engine GDExtension, Phantom Camera v0.11.0.4, GodotRichTextLabel2 (richtext2).

**Spec:** `docs/superpowers/specs/2026-11-05-feedback-system-design.md`

## Global Constraints

- Godot 4.7 Forward Plus; run tests with `godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]`. Output ends `N passed, M failed`; every task ends with the whole suite at `0 failed`.
- Tests extend `ChTest`, every `test_*` calls `_complete()` last, built nodes go through `_track()`.
- **No sound.** No audio player, bus, stream or profile field anywhere.
- **No hit-stop.** Nothing pauses ticks, the world, projectiles, the tree or `Engine.time_scale`.
- **Feedback writes nothing to fight state:** no collision shape, mass, body transform, `ChPartRuntime`/`ChChariotRuntime` field, energy, or sand cell. Only `Visual` nodes, `ChJuice`, overlay nodes, camera noise and visual particles change.
- Battle particles only via `spawn_visual_particles`, never `spawn_particles`. Hard cap **24** per play; skip particles entirely when `(particles_material + particles_visual) > 0.75 * get_max_particles()` (from `world.get_stats()`).
- Third-party code limited to Phantom Camera and GodotRichTextLabel2. If either fails its Task 1 check on 4.7, **stop and report to the user**; do not substitute another addon.
- Status markers in `ChBattle._draw_markers` (freeze tint, burn outline, broken X) stay. The fire pulse ring goes.
- The car-flip problem is out of scope.

## Review Focus

- A target freed mid-feedback (part broken and freed, garage freed by ChMain, pit piece removed by a lift): every queued spring/pop-up/particle must survive a freed target without errors. Test in Task 3 and Task 9.
- Rapid repeats (Flamethrower 9 hits in 2.25 s, a Hearth ring): springs must stay bounded, not blow up. Test in Task 2.
- A hit on the hull (`target_part == null`) must wobble the target chassis, not the attacker's. Test in Task 8.
- A full particle pool: feedback must not starve Flamethrower/Chainsaw. Test in Task 5.
- Pop-up pool exhaustion (many hits in one frame): oldest label is recycled, never an unbounded node count. Test in Task 4.

---

### Task 1: Install and vet the two addons

**Files:**
- Create: `addons/phantom_camera/` (from tag `v0.11.0.4` of `ramokz/phantom-camera`, folder `addons/phantom_camera` only)
- Create: `addons/richtext2/` (from tag `v1.14` of `chairfull/GodotRichTextLabel2`, folder `addons/richtext2` only; record the tag or commit SHA used in the commit message)
- Modify: `project.godot` (`[editor_plugins] enabled` lists both `plugin.cfg`; `[autoload] PhantomCameraManager="*res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd"`, the same path and name the plugin's `plugin.gd` registers)
- Test: `tests/test_addons.gd`

**Interfaces:**
- Produces: global classes `PhantomCamera2D`, `PhantomCameraHost`, `PhantomCameraNoiseEmitter2D`, `PhantomCameraNoise2D`, `RicherTextLabel`; autoload `PhantomCameraManager`.

- [ ] **Step 1: Write the failing tests** in `tests/test_addons.gd`:
  - `test_phantom_camera_loads`: a `Camera2D` with a `PhantomCameraHost` child and a `PhantomCamera2D` (priority 1, `follow_mode` NONE) under a tracked `_parent()`; set `pcam.global_position = Vector2(100, 50)` and `pcam.zoom = Vector2(4, 4)`; await 5 `process_frame`s; `assert_near(camera.global_position.x, 100.0, 0.5)` and `assert_near(camera.zoom.x, 4.0, 0.01)`.
  - `test_noise_emitter_moves_camera`: same rig plus a `PhantomCameraNoiseEmitter2D` with a `PhantomCameraNoise2D` (amplitude 10), `duration = 0.3`; call `emit()`; over 10 frames assert `is_emitting()` and that the camera's `get_screen_center_position()` differs from `(100, 50)` on at least one frame; after 40 more frames assert not emitting.
  - `test_richer_text_label_loads`: a `RicherTextLabel` under a tracked `CanvasLayer`, `bbcode = "[jump]-12[]"`, await 2 frames; `assert_true(label.get_parsed_text().contains("-12"))` (use the property/method name the addon actually exposes for the source text; adjust only the accessor, not the assertion).
- [ ] **Step 2: Run** `godot --headless --path . --script res://tests/run_tests.gd -- addons`. Expected: FAIL (classes not found).
- [ ] **Step 3: Install** both folders and edit `project.godot` as above. Open the project once headless (`godot --headless --path . --import`) so the `.uid`/import files are generated.
- [ ] **Step 4: Run** `-- addons`, then the whole suite. Expected: `0 failed`, and no new script errors at load. If any addon test cannot pass on 4.7, stop and report which and why.
- [ ] **Step 5: Commit** `chore(addons): add Phantom Camera v0.11.0.4 and RichTextLabel2 <tag/sha>`.

---

### Task 2: Springs and the juice node

**Files:**
- Create: `game/feedback/ch_spring.gd`, `game/feedback/ch_juice.gd`
- Test: `tests/feedback/test_juice.gd`

**Interfaces:**
- Produces:
  - `class_name ChSpring extends RefCounted`: `var value: float`, `var velocity: float`, `var rest: float`, `var stiffness := 320.0`, `var damping := 14.0`; `func _init(rest_in: float)`; `func step(delta: float) -> void` (semi-implicit Euler, sub-stepped at ≤ 1/120 s so a long frame stays stable; `value` is clamped to `rest ± MAX_OFFSET` where `MAX_OFFSET := 2.0`).
  - `class_name ChJuice extends Node`: node name always `"Juice"`; `var scale_spring := ChSpring.new(1.0)`, `var rotation_spring := ChSpring.new(0.0)` (radians); `func kick(scale_impulse: float, rotation_impulse: float) -> void` (adds to the two velocities); `func advance(delta: float) -> void` (steps both springs and applies to the parent); `_process(delta)` calls `advance`. `static func of(target: Node) -> ChJuice` (the target's `Juice` child or null); `static func attach(target: CanvasItem) -> ChJuice` (returns the existing one or adds a new one).
  - Apply rule: parent `Node2D` → `scale = Vector2.ONE * value`, `rotation = value`; parent `Control` → `pivot_offset = size * 0.5` then the same. Squash: `scale.y` uses `1.0 + (value - 1.0) * 0.6` so a pop is slightly wider than tall.

- [ ] **Step 1: Write the failing tests:**
  - `test_spring_rests`: a `ChSpring(1.0)` stepped 60 × 1/60 stays at exactly 1.0.
  - `test_spring_returns_after_kick`: velocity 8; after 2 s of 1/60 steps `absf(value - 1.0) < 0.01` and `absf(velocity) < 0.05`.
  - `test_spring_overshoots`: velocity 8 on rest 1.0; record min value over 1 s; assert min `< 1.0` (bouncy, not overdamped).
  - `test_kicks_stack`: peak of one `kick(6, 0)` < peak of two kicks 1/60 s apart.
  - `test_spring_bounded_under_spam`: 135 kicks of `(6, 3)` one per 1/60 step (a Flamethrower burst's worth); every value stays within `rest ± 2.0` and is finite.
  - `test_long_frame_stable`: velocity 8, one `step(0.5)`; value finite and within bounds.
  - `test_juice_applies_to_node2d` / `test_juice_applies_to_control`: attach to a tracked `Node2D` / a 100×40 `Control`, `kick(5, 2)`, `advance(1/60)`; scale.x ≠ 1, rotation ≠ 0; for the Control `pivot_offset == Vector2(50, 20)`.
  - `test_attach_is_idempotent`: `attach` twice returns the same node; target has one `Juice` child.
- [ ] **Step 2: Run** `-- juice`. Expected: FAIL.
- [ ] **Step 3: Implement** `ChSpring` and `ChJuice` to the interfaces above.
- [ ] **Step 4: Run** `-- juice`, then the suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat(feedback): springs and the juice node`.

---

### Task 3: Profiles and the feedback manager (wobble only)

**Files:**
- Create: `game/feedback/ch_feedback_profile.gd`, `game/feedback/ch_feedback_manager.gd`, `game/feedback/profiles/<kind>.tres` (one per kind below)
- Modify: `project.godot` (`[autoload] Feedback="*res://game/feedback/ch_feedback_manager.gd"`)
- Test: `tests/feedback/test_feedback_manager.gd`

**Interfaces:**
- Produces:
  - `class_name ChFeedbackProfile extends Resource` with exported: `scale_kick: float`, `rotation_kick_deg: float` (sign randomised per play), `text: String` (may contain `%d` for `amount`), `text_color: Color`, `particle_count: int`, `particle_color: Color`, `particle_speed: float`, `shake: float` (0..1).
  - `class_name ChFeedbackManager extends Node` (autoload name `Feedback`):
    - `const KINDS := [&"fired", &"landed", &"struck", &"caught_fire", &"frozen", &"thawed", &"broken", &"energy", &"activate", &"hover", &"placed", &"nudge"]`
    - `func profile(kind: StringName) -> ChFeedbackProfile` (loads `res://game/feedback/profiles/<kind>.tres`, cached; unknown kind → `push_warning`, null)
    - `func play(kind: StringName, target: CanvasItem, overrides := {}) -> void` — no-op on a null/freed target or unknown kind; kicks `ChJuice.of(target)` if present (does not attach one); later tasks add text/particles/shake here. Overrides keys: `amount: int`, `text: String`, `color: Color`.
    - `func attach_button(button: BaseButton) -> void` — `ChJuice.attach(button)`, `pressed → play(&"activate", button)`, `mouse_entered → play(&"hover", button)`; idempotent.
    - `var rng := RandomNumberGenerator.new()` for the rotation sign (tests may seed it).

Starting profile values (designer's starting point; tune by play):

| kind | scale_kick | rot° | text | particles (count, colour) | shake |
|---|---|---|---|---|---|
| fired | 6 | 8 | — | 6, `#ffe08a` | 0.05 |
| landed | 4 | 6 | — | — | 0 |
| struck | 5 | 14 | `-%d`, `#ff6b5a` | 10, `#ffb070` | 0.15 |
| caught_fire | 5 | 10 | `BURN!`, `#ff8a3d` | 12, `#ff5a1f` | 0.05 |
| frozen | -4 | 4 | `FROZEN`, `#8fd4ff` | 10, `#cfefff` | 0.05 |
| thawed | 3 | 6 | — | 6, `#bfe6ff` | 0 |
| broken | 9 | 25 | `BROKEN`, `#ffffff` | 24, part colour | 0.45 |
| energy | 3 | 4 | `+%d`, `#e8c35a` | 4, `#e8c35a` | 0 |
| activate | 5 | 8 | — | — | 0 |
| hover | 2 | 4 | — | — | 0 |
| placed | 7 | 10 | — | 8, `#e8c35a` | 0 |
| nudge | 3 | 3 | — | — | 0 |

- [ ] **Step 1: Write the failing tests:**
  - `test_every_kind_has_a_profile`: for each of `KINDS`, `Feedback.profile(kind) != null`.
  - `test_play_kicks_juice`: tracked Node2D with `ChJuice.attach`; `Feedback.play(&"fired", node)`; `juice.scale_spring.velocity == 6.0` and `absf(juice.rotation_spring.velocity) == deg_to_rad(8)`.
  - `test_play_without_juice_is_safe` and `test_play_on_freed_target_is_safe`: no error, no crash (target freed with `free()` before the call).
  - `test_unknown_kind_is_ignored`: `play(&"nope", node)` leaves the juice at rest.
  - `test_attach_button_wires_press_and_hover`: a tracked `Button`; `attach_button` twice; `button.pressed.emit()` → juice scale velocity 5; `mouse_entered.emit()` → +2 more; exactly one `Juice` child and one connection each.
- [ ] **Step 2: Run** `-- feedback_manager`. Expected: FAIL.
- [ ] **Step 3: Implement** the resource, the 12 `.tres` files with the table's values, the manager, and the autoload entry.
- [ ] **Step 4: Run** `-- feedback_manager`, then the suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat(feedback): profiles and the Feedback autoload`.

---

### Task 4: Pop-up text

**Files:**
- Create: `game/feedback/ch_popups.gd`
- Modify: `game/feedback/ch_feedback_manager.gd` (owns one `ChPopups`; `play` calls it when the profile or overrides give text)
- Test: `tests/feedback/test_popups.gd`

**Interfaces:**
- Produces: `class_name ChPopups extends CanvasLayer` (`layer = 50`, child of the `Feedback` autoload): `const POOL := 32`; `const LIFE := 0.8`; `func pop(text: String, color: Color, screen_at: Vector2) -> RicherTextLabel`; `func active() -> Array[RicherTextLabel]`; `func advance(delta: float) -> void` (`_process` calls it).
- Placement: `screen_at = target.get_global_transform_with_canvas().origin`, which already includes the battle camera, so popups are screen-space and sized in screen pixels (font size 28, outline 6 black) whatever the camera's zoom.
- Motion (own Tween-free code, driven by `advance` so tests are deterministic): rise 60 px over `LIFE` with ease-out, random x drift ±20 px, scale pop 0.4 → 1.25 → 1.0 over the first 0.15 s, fade out over the last 0.25 s. Text wrapped as `"[b][jump]%s[][]"` in RichTextLabel2 bbcode (use the tag syntax the addon actually takes, as verified in Task 1).
- Pool exhaustion: when all 32 are active, the oldest is recycled.

- [ ] **Step 1: Write the failing tests:**
  - `test_pop_shows_text`: `pop("-12", Color.RED, Vector2(100, 100))`; one active label whose source text contains `-12`, visible, near `(100, 100)`.
  - `test_pop_expires`: after `advance` totalling 0.85 s, `active()` is empty and the label is hidden.
  - `test_pool_recycles_oldest`: 40 pops; `active().size() == 32`; total `RicherTextLabel` children `== 32`; the first 8 texts are gone.
  - `test_play_struck_pops_amount`: `Feedback.play(&"struck", node, {"amount": 12})` → an active popup containing `-12`; `play(&"hover", node)` adds none.
- [ ] **Step 2: Run** `-- popups`. Expected: FAIL.
- [ ] **Step 3: Implement** `ChPopups` and the manager hook (`text % amount` when the text has `%d`, `overrides.text` wins).
- [ ] **Step 4: Run** `-- popups`, then the suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat(feedback): pooled pop-up text`.

---

### Task 5: Particles with a budget

**Files:**
- Create: `game/feedback/ch_feedback_particles.gd`
- Modify: `game/feedback/ch_feedback_manager.gd`
- Test: `tests/feedback/test_feedback_particles.gd`

**Interfaces:**
- Produces:
  - `class_name ChFeedbackParticles extends RefCounted`: `const CAP := 24`; `const POOL_SHARE := 0.75`; `static func budget(world: PixelWorld, wanted: int) -> int` (0 when `(particles_material + particles_visual) > POOL_SHARE * get_max_particles()`, else `mini(wanted, CAP)`); `static func burst_world(world: PixelWorld, at: Vector2, profile: ChFeedbackProfile, color: Color) -> int` (calls `spawn_visual_particles(color, at, Vector2(0, -profile.particle_speed), n, 1.2, 0.5, 1.0, true)` once with `n = budget(...)`; returns `n`).
  - Manager: `func bind_world(world: PixelWorld, scope: Node) -> void`, `func unbind_world() -> void`. Bodies are children of `ChBattle`, not of the world, so `scope` is the battle node: `play` uses `burst_world` at `target.global_position` (battle space is cell space) when a world is bound and `scope.is_ancestor_of(target)`; otherwise a one-shot `CPUParticles2D` on the `ChPopups` layer at the target's screen point (`one_shot`, `emitting = true`, `amount = mini(count, CAP)`, freed on `finished`). Colour = `overrides.color` else `profile.particle_color`. Default `particle_speed` 30 cells/s in battle.

- [ ] **Step 1: Write the failing tests** (worlds via `ChTest.make_world`, tracked):
  - `test_cap_is_24`: a profile asking 500 → `burst_world` returns 24 and `get_stats().particles_visual` rises by ≤ 24.
  - `test_full_pool_skips`: `set_max_particles(100)`, spawn 80 material particles with `spawn_particles`; `budget(world, 10) == 0`; `burst_world` adds no visual particles.
  - `test_feedback_never_writes_cells`: `count_materials` over a 40×40 rect around the burst point is identical before and after a `broken` burst plus 120 world steps.
  - `test_ui_burst_uses_cpu_particles`: no world bound; `play(&"placed", control)` adds one `CPUParticles2D` under the popup layer; it is freed after it finishes (advance frames ≥ its lifetime + 0.1 s).
- [ ] **Step 2: Run** `-- feedback_particles`. Expected: FAIL.
- [ ] **Step 3: Implement** as above.
- [ ] **Step 4: Run** `-- feedback_particles`, then the suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat(feedback): budgeted particles`.

---

### Task 6: Split look from collision in battle

**Files:**
- Modify: `game/battle/ch_chariot_builder.gd` (`_body`), `game/battle/ch_part_runtime.gd`, `game/battle/ch_chariot_runtime.gd`
- Test: `tests/battle/test_builder.gd` (add tests)

**Interfaces:**
- Produces:
  - Every body the builder makes (chassis and parts) gets `self_modulate = Color(1, 1, 1, 0)` and a `Sprite2D` child named `"Visual"` with the same `texture`, `centered = true`, and a `ChJuice` attached to the Visual.
  - `ChChariotBuilder.visual_of(body: Node) -> Node2D` (static; the `Visual` child or null).
  - `ChPartRuntime.visual: Node2D` (set by the builder) and `ChChariotRuntime.chassis_visual: Node2D`.

- [ ] **Step 1: Write the failing tests:**
  - `test_bodies_hide_and_carry_a_visual`: build a layout with a wheel and a box part; for the chassis and every part: `body.self_modulate.a == 0`, `visual_of(body)` is a `Sprite2D` with `texture == body.texture` and a `ChJuice`; `part.visual == visual_of(part.body)`; `rig.chassis_visual` likewise.
  - `test_visual_does_not_change_collision`: build the same layout twice, once as-is and once with the visual removed right after build (`visual.free()`); step the world 60 frames; chassis `get_mass()` and each part's mass are equal between builds (the shape comes from the texture, untouched).
  - `test_kicked_visual_leaves_body_alone`: with `world.simulating = false`, read a part body's `global_transform`; kick its visual's juice `(9, 3)` and `advance(0.1)`; the body's `global_transform` is unchanged and its `scale == Vector2.ONE`, while the visual's `scale != Vector2.ONE`.
- [ ] **Step 2: Run** `-- builder`. Expected: FAIL.
- [ ] **Step 3: Implement** in `_body` (after `add_child`) and set the two runtime fields in `build`.
- [ ] **Step 4: Run** `-- builder`, then the suite. Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat(battle): parts draw through a juiced visual, collision untouched`.

---

### Task 7: Battle camera through Phantom Camera, with shake

**Files:**
- Modify: `game/battle/battle.tscn` (add `PhantomCameraHost` under `Camera`; add `PCam` (`PhantomCamera2D`, priority 10, follow_mode NONE) and `Shake` (`PhantomCameraNoiseEmitter2D` with a `PhantomCameraNoise2D`) under the root)
- Modify: `game/battle/ch_battle.gd` (`_camera_at` writes `pcam.global_position` and `pcam.zoom` instead of the `Camera2D`; reads its "from" state from `pcam`), `game/feedback/ch_feedback_manager.gd`
- Test: `tests/battle/test_battle.gd` (update `test_camera_first_tick_is_the_shot_in_a_real_fight` to read `battle.pcam`; add one test)

**Interfaces:**
- Consumes: `camera_frame`, `camera_eased` (unchanged, still static and pure).
- Produces: `ChBattle.pcam: PhantomCamera2D`; manager `func bind_shake(emitter: PhantomCameraNoiseEmitter2D) -> void`, `func unbind_shake() -> void`; `play` with `profile.shake > 0` and a bound emitter sets `noise.amplitude = 12.0 * shake`, `duration = 0.08 + 0.25 * shake`, then `emit()`. Overlapping shakes: the larger amplitude wins while one is playing.

- [ ] **Step 1: Update/write tests:** the real-fight first-tick test reads `pcam.global_position`/`pcam.zoom`; new `test_shake_plays_through_the_emitter`: start a fight (existing helpers), `Feedback.play(&"broken", player.chassis_visual)`; `battle.get_node("Shake").is_emitting()` is true; the fight still finishes with a result (`test_battle_finishes` shape).
- [ ] **Step 2: Run** `-- battle`. Expected: the new test FAILS.
- [ ] **Step 3: Implement**; `ChBattle.start` calls `Feedback.bind_shake($Shake)` and `Feedback.bind_world(world, self)` after the world is built; `_exit_tree` calls `unbind_shake()` and `unbind_world()`.
- [ ] **Step 4: Run** `-- battle`, then the suite. Expected: `0 failed`, all four camera tests still green.
- [ ] **Step 5: Commit** `feat(battle): camera through Phantom Camera, feedback shake`.

---

### Task 8: Battle events into feedback

**Files:**
- Create: `game/battle/ch_battle_feedback.gd`
- Modify: `game/battle/ch_battle.gd` (remove `pulses`, `PULSE_SECONDS`, `_hear`, `_subscribe_hud`, `hud_listener` and the pulse drawing in `_draw_markers`; create and subscribe a `ChBattleFeedback` instead)
- Test: `tests/battle/test_battle_feedback.gd`

**Interfaces:**
- Consumes: `ChEvent` types; `ChBattleContext.enemy_of(part)`; `ChPartRuntime.visual`; `ChChariotRuntime.chassis_visual`; `ChBattleHud.player_bar` / `enemy_bar`; `Feedback.play`.
- Produces: `class_name ChBattleFeedback extends RefCounted`: `func _init(ctx: ChBattleContext, hud: ChBattleHud)`; `func subscribe() -> void` (one listener key = `self`, subscribes to the 7 event types); `func on_event(event: ChEvent) -> void`.
- Mapping (spec table):
  - `part_fired` → `fired` on `source.visual`
  - `hit` → `landed` on `source.visual`; `struck` with `{"amount": data.hp_damage}` on `data.target_part.visual`, or on `ctx.enemy_of(source).chassis_visual` when `target_part` is null; plus `nudge` on the struck side's HP bar (`player_bar` for side 0, `enemy_bar` for side 1; bars get `ChJuice.attach` in `_init`)
  - `caught_fire` / `frozen` / `thawed` → same-named kind on `source.visual`
  - `part_broken` → `broken` on `source.visual` with `{"color": source.def.color}`
  - `energy_gained` → `energy` on `source.visual` with `{"amount": int(event.data.get("amount", ChEmberBattery.GAIN))}` (the Ember Battery, the only emitter today, sends no payload)
  - a source/target with no live visual is skipped silently.

- [ ] **Step 1: Write the failing tests** (build two real chariots with the existing builder helpers; drive `on_event` with hand-made `ChEvent`s):
  - `test_fire_kicks_the_firing_part`: juice scale velocity on `source.visual` > 0; the other parts' juices at rest.
  - `test_hit_kicks_attacker_and_target`: both visuals kicked; a popup containing `-7` for `hp_damage = 7`; the struck side's HP bar juice kicked.
  - `test_hull_hit_wobbles_the_enemy_chassis`: `target_part = null` → `ctx.enemy_of(source).chassis_visual`'s juice is kicked, the attacker's chassis is not.
  - `test_caught_fire_and_fired_differ`: `caught_fire` pops `BURN!`; `part_fired` pops nothing.
  - `test_feedback_writes_no_fight_state`: snapshot every part's `integrity, cooldown_left, charges_left, burning, freeze, broken`, each chariot's `hp` and `energy.value`, each body's `global_transform`, `linear_velocity`, `get_mass()`, and `world.get_stats().particles_material`; call `on_event` once for each of the 7 types; snapshot again with the world not stepped; all equal.
  - `test_no_pulse_left`: `ChBattle` has no `pulses` property (`"pulses" not in battle`).
- [ ] **Step 2: Run** `-- battle_feedback`. Expected: FAIL.
- [ ] **Step 3: Implement** `ChBattleFeedback`; in `ChBattle.start`, replace `_subscribe_hud()` with `ChBattleFeedback.new(ctx, hud).subscribe()` held in a member.
- [ ] **Step 4: Run** `-- battle_feedback`, then the whole suite (the real-fight chain tests in `test_battle.gd` must still pass inside their existing frame budgets). Expected: `0 failed`.
- [ ] **Step 5: Run the game** (`godot --path .`, Fight) and watch one fight: parts pop on fire, hits pop numbers, breaks shake. Note any profile value changed during tuning in the commit.
- [ ] **Step 6: Commit** `feat(battle): bus events drive part feedback`.

---

### Task 9: Split the garage pit into nodes

**Files:**
- Create: `game/garage/ch_pit_piece.gd`
- Modify: `game/garage/ch_garage.gd` (`_draw`, `_draw_held`, every `queue_redraw()` that follows a layout/hover change)
- Test: `tests/test_garage.gd` (add tests)

**Interfaces:**
- Produces:
  - `class_name ChPitPiece extends Node2D`: `func show_part(def: ChPartDef, flipped: bool) -> void`, `func show_hull(def: ChBodyDef) -> void`; `_draw` paints at the origin with `ChPartCard.paint` (part) or the hull rect (hull), plus the flip notch for a flipped part; `ChJuice.attach(self)` in `_init`.
  - Garage tree, built in `_enter_tree` as the **first** child of `$Pit` so InfoPanel, Strip and HeldLayer stay on top: `PitView` (Node2D, `position = -_pit.position` so children use garage-local pixels) → `Hull` (ChPitPiece) → `Markers` (Node2D, `draw` → `_draw_markers`, the free-slot dashed squares and the near-slot fill) → `Parts` (Node2D) → `Hover` (Node2D, `draw` → `_draw_hover`, the hover box and range circle).
  - `ChGarage.piece_at(path: Array[int]) -> ChPitPiece` (null if none); `ChGarage.hull_piece() -> ChPitPiece`.
  - `func _sync_pit() -> void`: reuses a piece whose path and part_id are unchanged (keeps its spring state), creates pieces for new paths at `_box_at(screen_of(path), def).get_center()`, frees pieces whose path is gone or whose part changed, redraws `Markers` and `Hover`. Every place that changed the layout, hover or held state and called `queue_redraw()` calls `_sync_pit()` instead. `ChGarage._draw` keeps nothing of the pit.

- [ ] **Step 1: Write the failing tests:**
  - `test_pit_pieces_match_layout`: after `drop_part` of two parts, `piece_at(path).position == _box_at(screen_of(path), def).get_center()` for each, and `Parts` has exactly 2 children.
  - `test_piece_survives_unrelated_change`: kick the piece at path A, then drop a part at path B; `piece_at(A)` is the same instance and its juice velocity is unchanged.
  - `test_lift_frees_subtree_pieces`: lift a strut carrying an extension; both pieces gone, no errors, and a pending juice kick on them does not error on the next frames.
  - `test_cycle_body_rebuilds_hull`: after `cycle_body(1)`, `hull_piece()` shows the new body's size.
  - `test_pit_draw_order`: `$Pit.get_child(0)` is `PitView`; `Markers` index < `Parts` index < `Hover` index.
- [ ] **Step 2: Run** `-- garage`. Expected: FAIL.
- [ ] **Step 3: Implement** as above.
- [ ] **Step 4: Run** `-- garage`, then the suite (all existing garage and round-trip tests still green). Expected: `0 failed`.
- [ ] **Step 5: Screenshot** the garage with `tools/screenshot.gd` (as the previous UI plan did) and compare with a shot from before the change: same layout, parts above markers, hover on top.
- [ ] **Step 6: Commit** `refactor(garage): pit parts and hull as nodes`.

---

### Task 10: Garage and UI feedback

**Files:**
- Modify: `game/garage/ch_garage.gd`, `game/garage/ch_part_card.gd`, `game/ui/ch_result_panel.gd`
- Test: `tests/feedback/test_ui_feedback.gd`

**Interfaces:**
- Consumes: `Feedback.attach_button`, `Feedback.play`, `ChGarage.piece_at`, `hull_piece`.
- Wiring:
  - `ChPartCard._init` → `Feedback.attach_button(self)` (press = `activate`, hover = `hover`).
  - Garage top bar `PrevBody`, `NextBody`, `FightButton` → `attach_button` in `_enter_tree`.
  - `drop_part` success → `play(&"placed", piece_at(path))` after `_sync_pit()`.
  - `lift` success → `play(&"activate", <card for the lifted root part's id>)`.
  - `cycle_body` → `play(&"placed", hull_piece())`.
  - `ChResultPanel` back button → `attach_button`.
  - The garage has no camera: `play` skips shake when no emitter is bound, so nothing shakes in the garage (the garage kinds have `shake = 0` anyway).

- [ ] **Step 1: Write the failing tests:**
  - `test_card_press_and_hover_kick`: set-up garage (the existing test helper); `card.pressed.emit()` kicks its juice; `mouse_entered.emit()` kicks it again.
  - `test_drop_pops_the_new_piece`: `drop_part` → `piece_at(path)` juice velocity > 0; a `CPUParticles2D` was added to the popup layer.
  - `test_lift_pops_the_card`: lift a mounted wheel → the wheel card's juice is kicked.
  - `test_cycle_pops_the_hull`, `test_top_bar_and_back_buttons_juiced`: each has a `Juice` child and kicks on `pressed.emit()`.
  - `test_round_trip_with_feedback`: the existing `test_main_round_trip` flow passes with the garage freed mid-wobble (kick a piece, then go to fight on the same frame), with no errors.
- [ ] **Step 2: Run** `-- ui_feedback`. Expected: FAIL.
- [ ] **Step 3: Implement** the wiring.
- [ ] **Step 4: Run** `-- ui_feedback`, then the whole suite. Expected: `0 failed`.
- [ ] **Step 5: Play the loop** (`godot --path .`): garage → place, lift, flip, cycle → Fight → result → Back. Every press and placement bounces; nothing jitters at rest; no errors in the output.
- [ ] **Step 6: Commit** `feat(ui): garage cards, pit and buttons use feedback`.
