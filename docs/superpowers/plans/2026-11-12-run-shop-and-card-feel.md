# Run, Shop and Card Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Balatro-tight card and juice feel, then a real 10-fight run with a 4-stage drag-and-click shop
between fights.

**Architecture:**
- **Part 1 (Tasks 1–3)** changes `ChJuice` beats from spring kicks to additive decaying wiggles, and adds
  `ChCard`, a Control that draws its face under its own transform. The transform covers follow offset, tilt,
  hover, sway, juice and drag. Layout containers keep placing the card's rect, and only the drawing moves.
- **Part 2 (Tasks 4–13)** adds three pure-logic pieces: rarity and tags on defs, a `ChRun` run state and a
  `ChShopPhase` stage machine. All three are tested headless. On top of them come:
  - fight rules threaded into `ChBattle`
  - an embeddable garage
  - an inventory bar
  - a shop screen
  - `ChMain` driving the run

**Tech Stack:** Godot 4.7, GDScript. The headless test runner is `tests/run_tests.gd`, and tests extend `ChTest`.

**Spec:** `docs/superpowers/specs/2026-11-12-run-shop-and-card-feel-design.md`

## Global Constraints

- No new addons or dependencies.
- Every `test_*` method ends with `_complete()` as its last statement (the `ChTest` contract).
- Every screen uses `ChUi.theme()`. New colours go in `ChUi` as constants, never inline on nodes.
- Feedback writes nothing to fight state.
- Minimal HUD:
  - The shop screen shows only the gold readout, the centre-left Garage/Shop toggle, the Next/Fight button
    under the stage content, and the SELL zone.
  - There is no fight counter, no stage label and no capacity counter.
- A drop that fails for any reason returns the card to where it came from. Nothing is ever lost.
- Numbers pinned by the spec:
  - starting gold 20
  - reward 5 for a normal fight, 10 for an elite
  - prices 2 / 6 / 12 by rarity
  - pack entry 3, reroll 3
  - sell value `floor(price / 2)`
  - inventory capacity 5
  - resource options +4 gold or +100 max HP
  - rarity weights 60 / 30 / 10
  - elite HP ×1.25, boss HP ×1.5
  - modifiers: fire ×0.5 / ×0.25, time limit 40 s / 30 s, chains pass 50% / 25%
  - drag threshold 6 px, max tilt 12°, juice beat length T = 0.3 s
- Run tests with `godot --headless -s res://tests/run_tests.gd [-- <file filter>]`. A pass ends with
  `N passed, 0 failed`.

## Review Focus

1. **A drag released over nothing, or outside the window.** The card must glide back and keep its slot.
   Covered by Task 2, `test_drop_rejected_glides_home`.
2. **Gold exactly equal to the price.** The buy succeeds. Gold never goes negative, and one gold short is
   refused. Covered by Task 7, `test_buy_exact_gold`.
3. **A body swap that overflows a full inventory.** The overflow is auto-sold. Mounted + carried + sold
   always equals the parts before the swap. Covered by Task 7, `test_body_swap_overflow_sold`.
4. **A pack opened and then skipped with Next.** The 3 gold is spent and nothing is gained. It can't be
   opened twice, and nothing is taken after Next. Covered by Task 7, `test_pack_skip`.
5. **New run after a loss.** Gold is back to 20, the inventory is empty, the starting kit is mounted, the
   fight index is 0, and no max-HP bonus is carried over. Covered by Task 13, `test_new_run_resets`.

---

## Part 1: Card feel

### Task 1: Juice beats become decaying wiggles

**Files:**
- Modify: `game/feedback/ch_spring.gd`. The default `stiffness := 400.0` and `damping := 38.0` give a damping
  ratio of about 0.95.
- Modify: `game/feedback/ch_juice.gd`
- Modify: `game/feedback/ch_feedback_manager.gd:72`. Change `juice.kick(...)` to `juice.juice_up(...)`.
- Modify: `game/feedback/ch_feedback_profile.gd`. In the comments, the two fields become amplitudes: a scale
  delta and degrees.
- Modify: all 13 files in `game/feedback/profiles/*.tres`
- Test: `tests/feedback/test_juice.gd`. Also update the `kick` callers: `tests/battle/test_builder.gd:478` and
  `tests/test_garage.gd:756,779`.

**Interfaces:**
- Produces:
  - `ChJuice.juice_up(scale_amp: float, rotation_amp_rad: float) -> void`
  - `ChJuice.scale_value() -> float`, which is the spring value plus the wiggle
  - `ChJuice.rotation_value() -> float`
  - `var writes_parent := true`. When it is false, `advance()` steps the beats but doesn't write the parent.
    `ChCard` uses this to compose its own transform.
  - `scale_spring` and `rotation_spring` stay, because `ChPartTooltip` sets `scale_spring.value` for its
    pop-in.
  - Constants: `BEAT_TIME := 0.3`, `SCALE_OMEGA := 50.0`, `ROTATION_OMEGA := 42.0`, `MAX_SCALE_OFFSET := 0.35`,
    `MAX_ROTATION_OFFSET := deg_to_rad(25.0)`.
  - `kick()` is removed.

- [ ] **Step 1: Write the failing tests** in `test_juice.gd`. Replace `test_spring_overshoots`, and add the
  rest:

```gdscript
func test_spring_settles_without_ringing() -> void:
	var spring := ChSpring.new(1.0)
	spring.velocity = 8.0
	var crossings := 0
	var above := spring.value > 1.0
	for i in 60:
		spring.step(DT)
		if (spring.value > 1.0) != above:
			crossings += 1
			above = spring.value > 1.0
	assert_true(crossings <= 1, "near-critical spring crosses rest at most once, got %d" % crossings)
	_complete()

func test_juice_up_is_short() -> void:
	var juice := ChJuice.new()
	juice.juice_up(0.2, 0.1)
	var peak := 0.0
	for i in 18:  # 0.3 s
		juice.advance(DT)
		peak = maxf(peak, absf(juice.scale_value() - 1.0))
	assert_true(peak > 0.08, "a beat visibly pops, peak %s" % peak)
	juice.advance(DT)
	assert_true(absf(juice.scale_value() - 1.0) < 0.01, "and is over after BEAT_TIME")
	assert_true(absf(juice.rotation_value()) < 0.01, "rotation too")
	_complete()

func test_juice_up_starts_at_rest() -> void:
	var juice := ChJuice.new()
	juice.juice_up(0.2, 0.1)
	juice.advance(0.0)
	assert_eq(juice.scale_value(), 1.0, "sin(0) start: no snap on the first frame")
	_complete()

func test_beats_stack_but_clamp() -> void:
	var juice := ChJuice.new()
	for i in 20:
		juice.juice_up(0.2, 0.2)
	var peak := 0.0
	for i in 18:
		juice.advance(DT)
		peak = maxf(peak, absf(juice.scale_value() - 1.0))
	assert_true(peak > 0.2, "stacked beats grow past one beat")
	assert_true(peak <= ChJuice.MAX_SCALE_OFFSET + 0.0001, "but stay bounded")
	_complete()
```

- [ ] **Step 2: Run the juice tests and check they fail.** Run `godot --headless -s res://tests/run_tests.gd
  -- juice`. Expected: FAIL, because `juice_up` and `scale_value` are not defined.

- [ ] **Step 3: Implement it.**
  - A beat is `{t, s, r}`. Each `advance` adds `delta` to `t` and drops a beat once `t >= BEAT_TIME`.
  - The wiggle is `Σ s·sin(SCALE_OMEGA·t)·(1 − t/BEAT_TIME)³` for scale, and the same with `r` and
    `ROTATION_OMEGA` for rotation. Clamp each sum to its max.
  - `scale_value() = scale_spring.value + wiggle_s`.
  - The parent-writing code is unchanged, except that it reads `scale_value()` and `rotation_value()` and
    only runs when `writes_parent` is true.
  - The manager passes `deg_to_rad(beat.rotation_kick_deg)` with a random sign, as it does today.

- [ ] **Step 4: Retune the 13 profiles** (`scale_kick`, `rotation_kick_deg`):

| Profile | scale_kick | rotation_kick_deg |
|---|---|---|
| hover | 0.04 | 3 |
| activate | 0.10 | 6 |
| placed | 0.15 | 8 |
| nudge | 0.06 | 3 |
| tooltip | 0.05 | 2 |
| energy | 0.06 | 3 |
| fired | 0.12 | 6 |
| landed | 0.08 | 4 |
| struck | 0.12 | 10 |
| caught_fire | 0.10 | 6 |
| frozen | −0.08 | 3 |
| thawed | 0.06 | 4 |
| broken | 0.25 | 18 |

  Leave `shake`, the text and the particles untouched.

- [ ] **Step 5: Update the old `kick` callers in the tests.**
  - Replace `juice.kick(a, b)` with `juice.juice_up(0.2, 0.1)`.
  - Replace the assertions on `scale_spring.velocity` with assertions on `scale_value()` changing after one
    `advance(DT)`.
  - Keep each test's intent, which is one juice per target and no double attach.

- [ ] **Step 6: Run the full suite.** Run `godot --headless -s res://tests/run_tests.gd`. Expected:
  `… passed, 0 failed`.

- [ ] **Step 7: Commit.** `git commit -am "feat(feedback): juice beats are short decaying wiggles"`

### Task 2: ChCard, the card that follows, tilts, hovers, sways and drags

**Files:**
- Create: `game/ui/ch_card.gd`
- Test: `tests/ui/test_card.gd`

**Interfaces:**
- Consumes: `ChJuice` from Task 1, with `writes_parent = false`, `scale_value()` and `rotation_value()`.
- Produces: `class_name ChCard extends Control`.
  - Signals:
    - `clicked`
    - `drag_started`
    - `dropped(at: Vector2)`, where `at` is the global pointer
    - `hover_changed(entered: bool)`
  - `var draggable := true`
  - `var offset := Vector2.ZERO`. This is the drawn displacement from the rect's position, and it springs
    toward `_target_offset`.
  - `var tilt := 0.0` (radians)
  - `var dragging := false`
  - `var hovered := false`
  - Input entry points, which `_gui_input` and `_input` call and tests call directly. All take global
    points:
    - `press(at: Vector2)`
    - `move(at: Vector2)`
    - `release(at: Vector2)`
    - `hover(entered: bool)`
  - `advance(delta: float)`, called from `_process`
  - `refuse()`, a rotation-only juice-up
  - `_paint_face()`, a virtual that subclasses draw into. It is called inside `_draw` after
    `draw_set_transform` has been applied around the card's centre.
  - The default face is `draw_style_box(ChUi.flat(ChUi.BUTTON, rim), Rect2(Vector2.ZERO, size))`, where the rim
    is `ChUi.ACCENT` while hovered.
  - Constants:
    - `DRAG_THRESHOLD := 6.0`
    - `MAX_TILT := deg_to_rad(12.0)`
    - `TILT_PER_SPEED := 0.0006` (radians per px/s)
    - `HOVER_LIFT := 6.0`
    - `HOVER_SCALE := 1.06`
    - `DRAG_SCALE := 1.1`
    - `SWAY := deg_to_rad(1.0)`
    - `SWAY_HZ := 0.4`
    - `FOLLOW_STIFFNESS := 500.0`
    - `FOLLOW_DAMPING := 42.0`
    - `DRAG_Z := 50`

- [ ] **Step 1: Write the failing tests** in `test_card.gd`. Build the card with `ChCard.new()`, size 80×120,
  added under `_parent()` and tracked.
  - `test_click_under_threshold`: `press(p)`, `move(p + Vector2(3, 0))`, `release(...)`. Assert that `clicked`
    fired once and `dropped` didn't.
  - `test_drag_past_threshold`: `press(p)`, `move(p + Vector2(10, 0))`. Assert `dragging` is true and
    `drag_started` fired. Then `release(q)`: `dropped` fires with `q`, `dragging` becomes false, and `clicked`
    never fires.
  - `test_drag_follows_with_lag`: drag 200 px right, then run one `advance(DT)`. The offset's x must be above
    0 and below 200. After 60 more `advance(DT)` steps, it must be within 2 px of 200 minus the grab offset.
  - `test_tilt_follows_velocity`: while the offset is moving right, `tilt` is above 0. It never exceeds
    `MAX_TILT`. Once still for 1 s, `absf(tilt)` is below 0.01.
  - `test_drop_rejected_glides_home`: drag 150 px away and `release`, with no owner acting on it. After 60
    `advance(DT)` steps, the offset's length is below 1 and `z_index` is back to 0.
  - `test_layout_move_is_eased`: set `position += Vector2(100, 0)` as a container would. On the next
    `advance(DT)`, the drawn global position (`global_position + offset`) has moved less than 100. Within 1 s
    it reaches the new position.
  - `test_hover_lifts`: `hover(true)` and 30 steps. Assert the offset's y is close to `-HOVER_LIFT` and the
    drawn scale (the `_drawn_scale()` helper) is close to `HOVER_SCALE`.

- [ ] **Step 2: Run the card tests and check they fail.** Run `godot --headless -s res://tests/run_tests.gd
  -- card`. Expected: FAIL, because `ChCard` doesn't exist.

- [ ] **Step 3: Implement `ChCard`.**
  - Store the last `global_position`. When it changes and there's no drag, add the old position minus the
    new one to `offset`. That is how a reorder or a container move eases instead of jumping.
  - The target offset is:
    - while dragging: `pointer − grab_point`, where grab_point is the press point relative to the rect's
      global position
    - otherwise: `(0, −HOVER_LIFT)` when hovered, or zero
  - The offset uses two `ChSpring` instances at the follow constants.
  - `tilt` eases toward `clamp(offset_velocity.x · TILT_PER_SPEED, ±MAX_TILT)`, plus a hover lean of
    `clamp((pointer.x − centre.x)/size.x, −0.5, 0.5) · deg_to_rad(4)`. Add sway as `sin(TAU·SWAY_HZ·t + phase)
    · SWAY`, where phase is random per card.
  - While dragging, `z_index = DRAG_Z`. On release, put it back.
  - In `_draw`, call `draw_set_transform(size/2 + offset, tilt + juice.rotation_value(), Vector2.ONE · s)`,
    where `s = juice.scale_value() · (hover/drag scale)`. Then call `_paint_face()` with the drawing origin
    offset by `-size/2`. Use `queue_redraw()` each frame.
  - Play `Feedback.play(&"hover", self)` when hover starts, `&"activate"` on a click, and `&"placed"` when a
    drag starts. Pass `self`, because the Juice child lives on the card.
  - `_gui_input` handles a left press on the card. `_input` handles motion and release while pressed, so a
    release outside the card, or outside the window, still lands as a `release`.

- [ ] **Step 4: Run the card tests and check they pass.** Run `godot --headless -s res://tests/run_tests.gd
  -- card`. Expected: PASS.

- [ ] **Step 5: Commit.** `git add game/ui/ch_card.gd tests/ui/test_card.gd && git commit -m "feat(ui): ChCard
  follow, tilt, hover, sway and drag"`

### Task 3: The garage strip's cards are ChCards

**Files:**
- Modify: `game/garage/ch_part_card.gd`. It becomes `extends ChCard`, `_draw` becomes `_paint_face`, and the
  `pressed` it used before becomes `clicked`. Remove `Feedback.attach_button(self)`, since ChCard plays its own
  beats. A disabled card (count 0) sets `draggable = false` and ignores `press`.
- Modify: `game/garage/ch_garage.gd`. Change the strip wiring from `pressed` and `mouse_entered` to `clicked`
  and `hover_changed`.
- Test: update `tests/test_garage.gd` wherever it emits `pressed` on a card or reads Button state.

**Interfaces:**
- Produces: `ChPartCard.new(def, on_click: Callable)`. It no longer takes the garage. `on_click` is called with
  no arguments, and the garage passes `pick_part.bind(id)`.
  - `ChPartCard.price := -1`. When it is 0 or more, the cost row reads `"$%d"` instead of the energy cost.
    Task 12 uses this.
  - `ChPartCard.show_count := true`. When it is false, the `×n` count is hidden.
  - `ChPartCard.paint(...)` stays static and unchanged.

- [ ] **Step 1: Update the garage tests** so they drive cards through `card.press(p)` and `card.release(p)` and
  expect `garage.held_id == id`. A count-0 card refuses: `press` and `release` leave `held_id` empty.

- [ ] **Step 2: Run the garage tests and check they fail.** Run `godot --headless -s res://tests/run_tests.gd
  -- garage`. Expected: FAIL.

- [ ] **Step 3: Port `ChPartCard` and the strip wiring** to the interfaces above.

- [ ] **Step 4: Run the full suite.** Expected: `0 failed`. Then launch the game with `godot --path .` and check
  by eye that the strip cards hover-lift, sway and pop on click.

- [ ] **Step 5: Commit.** `git commit -am "feat(garage): strip cards use ChCard"`

---

## Part 2: The run and the shop

### Task 4: Rarity, tags and prices

**Files:**
- Modify: `game/data/ch_part_def.gd` and `game/data/ch_body_def.gd`. Add `var rarity: StringName = &"common"` to
  each.
- Modify: the 12 files in `game/data/parts/*.tres`, adding `rarity` and `tags`. Modify the 3 files in
  `game/data/bodies/*.tres`, adding `rarity`. The values are in the spec's table: Cutter common, Dozer
  uncommon, Corsair rare.
- Create: `game/run/ch_prices.gd`
- Test: `tests/data/test_catalog.gd`, plus a new `tests/run/test_prices.gd`

**Interfaces:**
- Produces: `class_name ChPrices` (static).
  - `price(rarity: StringName) -> int`: common 2, uncommon 6, rare 12.
  - `sell_value(rarity: StringName) -> int` is `price / 2`, rounded down.
  - `PACK := 3`
  - `REROLL := 3`
  - `WEIGHTS := {&"common": 60, &"uncommon": 30, &"rare": 10}`
  - `roll_rarity(rng: RandomNumberGenerator) -> StringName`

- [ ] **Step 1: Write the failing tests.**
  - `test_every_part_has_rarity_and_tags`: load the catalog. Every part's rarity is common, uncommon or rare,
    and `tags` is not empty. Spot-check the table: `flamethrower` has `fire`, `weapon` and `triggered` and is
    uncommon. `cutter_rocket` is rare. `strut` has `tricky`.
  - `test_prices`: price is 2, 6 or 12. `sell_value(&"common") == 1` and `sell_value(&"rare") == 6`.
  - `test_roll_weights`: over 10 000 rolls with seed 1, common falls between 0.57 and 0.63 and rare between
    0.08 and 0.12.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- catalog` and `-- prices`. Expected: FAIL.

- [ ] **Step 3: Implement it.** Add the fields, the .tres values and `ChPrices`.

- [ ] **Step 4: Run the tests and check they pass.** Expected: PASS.

- [ ] **Step 5: Commit.** `git commit -am "feat(data): part and body rarity, tags, prices"`

### Task 5: The 5-slot inventory, reorder, and lift refusal

**Files:**
- Modify: `game/data/ch_inventory.gd`
- Modify: `game/garage/ch_garage.gd`. `lift` refuses when the branch doesn't fit, and `_lift_branches` returns
  the ids that didn't fit instead of dropping them.
- Test: `tests/data/test_inventory.gd` (new) and `tests/test_garage.gd`

**Interfaces:**
- Produces:
  - `ChInventory.CAPACITY := 5`
  - `ChInventory.free_slots() -> int`. It returns a large number when `capacity < 0`.
  - `ChInventory.move(from: int, to: int) -> bool`. It moves within `part_ids` and is false when out of range.
  - `ChInventory.remove_at(index: int) -> StringName`
  - `ChGarage.lift(path) -> bool`. It returns false, changes nothing and plays `refuse` on the piece when
    `layout.subtree_part_ids(node).size() > inventory.free_slots()`.
  - `ChGarage._lift_branches(branches) -> Array[StringName]` returns the overflow. Task 7 sells it.

- [ ] **Step 1: Write the failing tests.**
  - `test_move_reorders`: start from `[a, b, c]`. `move(0, 2)` gives `[b, c, a]`. `move(5, 0)` is false and
    leaves the list unchanged.
  - `test_free_slots`: with capacity 5 and 3 parts, the answer is 2.
  - In the garage, `test_lift_refused_when_branch_does_not_fit`:
    - Set inventory capacity 5 with 4 carried, and mount a strut carrying 2 parts.
    - `lift(strut_path)` is false.
    - The layout still has the strut and its children.
    - The inventory still has 4.

- [ ] **Step 2: Run the tests and check they fail.** Expected: FAIL.

- [ ] **Step 3: Implement it.**

- [ ] **Step 4: Run the tests and check they pass.** Run `-- inventory` and `-- garage`. Expected: PASS.

- [ ] **Step 5: Commit.** `git commit -am "feat(data): 5-slot inventory, reorder, lift refuses overflow"`

### Task 6: ChRun, the run state and the fight sequence

**Files:**
- Create: `game/run/ch_run.gd`
- Test: `tests/run/test_run.gd`

**Interfaces:**
- Consumes: `ChInventory` (Task 5), `ChChariotLayout`, `ChCatalog`.
- Produces: `class_name ChRun extends RefCounted`.
  - State:
    - `var seed: int`
    - `var rng: RandomNumberGenerator`
    - `var fight_index := 0`, which is 0-based and runs to 9
    - `var gold := 20`
    - `var hp_bonus := 0`
    - `var inventory: ChInventory`, at capacity 5
    - `var layout: ChChariotLayout`
    - `var modifiers: Dictionary`, which maps fight index to a modifier StringName
  - `static func start(seed: int, catalog: ChCatalog) -> ChRun` builds:
    - the Cutter body, with wheels on its two lowest slots (the wheel mounts, see the ChBodyDef comment)
      and `cutter_chainsaw` on its first non-wheel slot
    - an empty inventory
    - 20 gold
    - modifiers drawn from `rng` for indices 2, 5, 8 and 9
  - `const MODIFIERS := [&"fire_halved", &"time_limit", &"chains_weak"]`
  - `kind(index: int) -> StringName`. It returns `&"boss"` for 9, `&"elite"` for 2, 5 and 8, and `&"normal"`
    otherwise.
  - `reward(index: int) -> int`: 10 for an elite, 5 for a normal fight, 0 for the boss.
  - `enemy_hp(index: int) -> int`. It interpolates linearly from `FIRST_HP` at index 0 to `LAST_HP := 1500` at
    index 8, then multiplies by 1.25 for an elite and 1.5 for the boss.
    - `FIRST_HP` is a constant that Task 13 tunes.
    - It starts at `500`.
  - `enemy_layout(index: int) -> ChChariotLayout` is a copy of `dozer_cook.tres` with
    `max_hp = enemy_hp(index)`.
  - `fight_seed(index: int) -> int` is `hash([seed, index])`.
  - `player_layout() -> ChChariotLayout` is a copy of `layout` with `max_hp = body hp + hp_bonus`. It reads
    the body's HP through the catalog, so a body swap re-derives it.
  - `rules(index: int) -> ChFightRules` comes from Task 8. Its body is a one-line map from
    `modifiers.get(index)` and `kind(index)`.
  - `is_last(index: int) -> bool`

- [ ] **Step 1: Write the failing tests.**
  - `test_sequence`: `[kind(i) for i in 10]` equals
    `[normal, normal, elite, normal, normal, elite, normal, normal, elite, boss]`.
  - `test_start_kit`: gold is 20 and `inventory.part_ids` is empty. The layout's body is cutter, holding
    exactly two `wheel` and one `cutter_chainsaw`.
  - `test_hp_curve`: `enemy_hp(0) == FIRST_HP` and the curve is non-decreasing across normal fights.
    `enemy_hp(8)` is `round(1500 × 1.25)` and `enemy_hp(9)` is `round(1500 × 1.5)`.
  - `test_modifiers_drawn_for_elites_and_boss`: indices 2, 5, 8 and 9 have a modifier in `MODIFIERS`, and the
    others have none. The same seed gives the same draws.
  - `test_hp_bonus_applies`: with `hp_bonus = 100`, `player_layout().max_hp` equals the cutter's hp plus 100.

- [ ] **Step 2: Run the run tests and check they fail.** Run `-- run`. Expected: FAIL.

- [ ] **Step 3: Implement `ChRun`.** Stub `rules()` until Task 8.

- [ ] **Step 4: Run the run tests and check they pass.** Run `-- run`. Expected: PASS.

- [ ] **Step 5: Commit.** `git add game/run tests/run && git commit -m "feat(run): run state and fight sequence"`

### Task 7: ChShopPhase, the four stages as rules

**Files:**
- Create: `game/run/ch_shop_phase.gd`
- Test: `tests/run/test_shop_phase.gd`

**Interfaces:**
- Consumes: `ChRun` (Task 6), `ChPrices` (Task 4), `ChInventory.free_slots` (Task 5),
  `ChChariotLayout.swap_body` and `subtree_part_ids`.
- Produces: `class_name ChShopPhase extends RefCounted`.
  - `ChShopPhase.new(run: ChRun, catalog: ChCatalog)` credits `run.reward(run.fight_index)` straight away.
    That is stage 1, and it is visible as `credited: int`.
  - `var stage := 2`, which runs 2 to 4, then 5 (done).
  - `var options: Array[Dictionary]`. Each is `{kind: &"shop"|&"pack"|&"resource", theme: StringName,
    resource: &"gold"|&"hp"}`.
  - `var picked: Dictionary`, empty until an option is committed.
  - `var items: Array[Dictionary]`. Each is `{id: StringName, is_body: bool, rarity, price, taken: bool}`.
  - `var rerolled := false`
  - `const THEMES := {&"weapon": [&"weapon"], &"fire": [&"fire"], &"tricky": [&"tricky"], &"passive":
    [&"passive"], &"triggered": [&"triggered"], &"body": []}`. `body` means bodies.
  - `available_themes() -> Array[StringName]` returns the themes with at least 3 distinct matching items.
  - `pick(index: int) -> bool`. It commits the option.
    - shop: rolls 3 items
    - pack: costs `ChPrices.PACK`, and is refused if gold is short, then rolls 3 items
    - resource: grants +4 gold, or +100 `hp_bonus`
  - `buy(item_index: int) -> bool`. It is shop only. It needs enough gold, the item not yet taken, and a free
    slot (bodies need no slot).
  - `take(item_index: int) -> bool`. It is pack only: one item, free, and it needs a free slot for a part.
  - `reroll() -> bool`. It is shop only, once, and costs 3.
  - `sell(inventory_index: int) -> int`. It returns the gold gained. It works at any stage.
  - `next() -> void`. It moves to the next stage, rolls new options and clears picked and items.
  - `done() -> bool` is `stage > 4`.
  - Rolling an item: draw a rarity with `ChPrices.roll_rarity`, then pick uniformly among the theme's items of
    that rarity. If none exist at that rarity, fall back to any rarity in the theme.
  - Buying or taking a body calls `layout.swap_body`. Overflow ids go into the inventory until it is full. The
    rest are sold for `sell_value` each and listed in `var auto_sold: Array[StringName]` so the screen can
    beat them.

- [ ] **Step 1: Write the failing tests.** Seed the run with 7.
  - `test_stage1_credits_reward`: at fight_index 2 (an elite), `credited == 10` and gold is 30.
  - `test_option_rules`: across 50 seeds and every stage:
    - option 0 and option 1 have different themes
    - neither is `resource`
    - neither shares a theme with the previous stage's options 0 and 1
    - option 2's kind is `resource`
    - every theme is in `available_themes()`
  - `test_themes_threshold`: `available_themes()` equals the set {weapon, fire, tricky, passive, triggered,
    body}.
  - `test_buy_exact_gold`: with gold equal to the price, `buy` is true and gold is 0. Then on another item with
    gold one short of its price, `buy` is false and gold is unchanged.
  - `test_buy_refused_when_full`: with 5 carried, buying a part is false and gold is unchanged.
  - `test_pack_skip`:
    - `pick(pack)` costs 3.
    - A second `pick` is false.
    - After `next()`, `take(0)` is false and the inventory is unchanged.
  - `test_pack_one_take`: the first `take` is true and the second is false.
  - `test_reroll_once`: the first is true and costs 3, the second is false. The items change for at least one
    seed out of ten.
  - `test_sell_half`: selling a rare part adds 6 and frees a slot.
  - `test_body_swap_overflow_sold`:
    - Start with the inventory full.
    - Buy a body whose swap returns overflow.
    - Mounted + carried + `auto_sold` equals the part count before the buy.
    - Gold rose by the sum of the sell values.
  - `test_resource_hp`: picking the hp resource sets `run.hp_bonus` to 100.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- shop_phase`. Expected: FAIL.

- [ ] **Step 3: Implement `ChShopPhase`.** Use `run.rng` for every random draw.

- [ ] **Step 4: Run the tests and check they pass.** Run `-- shop_phase`. Expected: PASS.

- [ ] **Step 5: Commit.** `git commit -am "feat(run): four-stage shop phase rules"`

### Task 8: Fight rules (modifiers), banner and countdown

**Files:**
- Create: `game/battle/ch_fight_rules.gd`
- Modify:
  - `game/battle/ch_battle.gd`: `start(..., rules: ChFightRules = null)`
  - `game/battle/ch_battle_context.gd`: `var rules`, the fire multiplier in `deal_hit` and in the burn tick on
    side 1
  - `game/battle/ch_event_bus.gd`: the chain filter
  - `game/battle/ch_battle_hud.gd`: the banner and countdown
  - `game/run/ch_run.gd`: `rules()`
- Test: `tests/battle/test_fight_rules.gd`

**Interfaces:**
- Produces: `class_name ChFightRules extends RefCounted`.
  - `var modifier: StringName = &""`
  - `var fire_mult := 1.0`
  - `var tick_limit := ChBattle.FIGHT_TICKS`
  - `var chain_pass := 1.0`
  - `static func of(modifier: StringName, boss: bool) -> ChFightRules`:
    - `fire_halved`: 0.5, or 0.25 for the boss
    - `time_limit`: 40 s, or 30 s for the boss, × 60 ticks
    - `chains_weak`: 0.5, or 0.25 for the boss
  - `banner_text() -> String`: `"Fire damage halved"`, `"Kill it in 40 s"`, `"Chains weakened"`, using the
    boss numbers when they apply. It is empty for no modifier.
  - `ChEventBus.chain_pass := [1.0, 1.0]`, indexed by listener side, plus `var rng`. A delivery to a listener
    whose `listener.part.side` (read duck-typed and skipped when absent) has a pass below 1 goes through only
    when `rng.randf() < pass`. `ChBattleFeedback` has no `part`, so it always hears.
  - `ChBattleHud.show_banner(text: String)` shows the text for 2 s, then frees it.
  - `ChBattleHud.show_countdown(seconds_left: int)`. A Label is created on the first call and only exists in a
    time-limit fight.
  - `ChRun.rules(index)` returns `ChFightRules.of(modifiers.get(index, &""), kind(index) == &"boss")`.

- [ ] **Step 1: Write the failing tests.**
  - `test_of_numbers`: check every row of the table above.
  - `test_fire_mult_on_player_fire_hit`:
    - Build a context with a fake side-0 `flamethrower` source, as the existing behaviour tests do (see
      `tests/battle/test_behaviours_fire.gd`), and `rules.fire_mult = 0.5`.
    - `deal_hit` for 40 costs the enemy 20 HP.
    - A side-0 `cutter_chainsaw` hit costs the full damage.
    - A side-1 fire hit on the player costs the full damage.
  - `test_burn_mult_on_enemy`: one second of burning on side 1 with `fire_mult` 0.5 costs half of what it costs
    with 1.0.
  - `test_chain_filter`:
    - Use `chain_pass = [0.0, 1.0]`.
    - A side-0 listener never hears.
    - A side-1 listener hears.
    - A listener with no `part` hears.
  - `test_tick_limit`: a battle started with `tick_limit = 30` and nobody dying finishes within 30 ticks with
    `&"draw"`. Use the drivers and pressers seams from `test_battle.gd` to keep both chariots idle.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- fight_rules`. Expected: FAIL.

- [ ] **Step 3: Implement it.**
  - The `FIGHT_TICKS` loop in `start` uses `rules.tick_limit`.
  - Each tick of a time-limit fight calls
    `hud.show_countdown(ceili((tick_limit - tick) / 60.0))`.
  - At start, if `rules.banner_text() != ""`, call `hud.show_banner(...)`.
  - A null `rules` means `ChFightRules.new()`.

- [ ] **Step 4: Run the full suite.** Expected: `0 failed`. Existing fights are unchanged.

- [ ] **Step 5: Commit.** `git commit -am "feat(battle): elite and boss fight rules, banner, countdown"`

### Task 9: The result panel speaks run

**Files:**
- Modify: `game/ui/ch_result_panel.gd`
- Test: `tests/ui/test_result_panel.gd` (new)

**Interfaces:**
- Produces: `ChResultPanel.show_result(result: StringName, last_fight := false)`. The title and the button text
  follow this table:

| Result | Title | Button |
|---|---|---|
| `win`, not the last fight | "You win" | "Continue" |
| `win`, the last fight | "Run won" | "New run" |
| `loss` or `draw` | "Run over" | "New run" |
| `aborted` | keeps today's text | "Retry" |

  - `var ends_run: bool` is true for the loss and draw rows and for the last win.
  - The signal `back_pressed` stays.

- [ ] **Step 1: Write the failing test.** `test_titles` checks the four cases: title, button text and
  `ends_run`.
- [ ] **Step 2: Run it and check it fails.** Run `-- result_panel`. Expected: FAIL.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run it and check it passes.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "feat(ui): result panel for runs"`

### Task 10: The garage becomes embeddable, with drag on and off the pit

**Files:**
- Modify: `game/garage/ch_garage.gd` and `game/garage/garage.tscn`. Remove the strip, the body buttons, the stats
  and top bar, the Fight button, `fight_requested`, `cycle_body`, `BODIES`, `STRIP_ORDER`, `card_counts` and
  `request_fight`.
- Modify: `game/garage/ch_pit_piece.gd`. Mounted pieces can be dragged.
- Test: `tests/test_garage.gd`. Delete the tests for the removed features and add the new ones.

**Interfaces:**
- Consumes: `ChInventory.free_slots` and `ChGarage.lift() -> bool` (Task 5), `ChCard.refuse` semantics.
- Produces:
  - `ChGarage.setup(inventory, layout, catalog)` is unchanged.
  - `ChGarage.slot_at(global: Vector2) -> Array`. It returns a free slot path near the point, or `[]`. It is
    the drop-zone test for an inventory card. It wraps `_slot_near` with a global-to-local conversion.
  - `ChGarage.hold(id: StringName)` is the old `pick_part` without the count check. The bar's click calls it.
  - `ChGarage.mount_from_inventory(index: int, path) -> bool`. It takes `inventory.part_ids[index]`, places
    it, and on refusal puts the part back at the same index.
  - `signal piece_dropped(path: Array[int], at: Vector2)`. A mounted piece dragged past 6 px and released emits
    this. The pit draws the lifted piece under the pointer while it is held.
  - `signal changed`, emitted after any mount, lift or flip, so the bar refreshes.

- [ ] **Step 1: Write the failing tests.**
  - `test_mount_from_inventory`: the part leaves the inventory at that index and the layout holds it at the
    path.
  - `test_mount_refused_restores`: on an occupied path, the inventory is unchanged and in the same order.
  - `test_slot_at_global`: the screen point of a free marker maps back to its path. A point far from any
    marker gives `[]`.
  - `test_piece_drag_emits`: press on a mounted piece, move 10 px and release. `piece_dropped` fires with that
    path. Under 6 px it is a click, which is today's lift or flip.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- garage`. Expected: FAIL.

- [ ] **Step 3: Implement it.** `garage.tscn` keeps the pit only. The pit stays centred at `CHARIOT_AT`, moved
  up so the bottom bar fits under it. The builder picks the exact y.

- [ ] **Step 4: Run the full suite.** Expected: `0 failed`. `ChMain` still uses the garage until Task 13. Leave
  `ChMain` compiling by giving it a temporary Fight key: Enter calls the existing fight path. Task 13 removes
  that key.

- [ ] **Step 5: Commit.** `git commit -am "refactor(garage): embeddable pit with drag on and off"`

### Task 11: The inventory bar and the sell zone

**Files:**
- Create: `game/shop/ch_inventory_bar.gd`
- Test: `tests/shop/test_inventory_bar.gd`

**Interfaces:**
- Consumes: `ChPartCard` (Task 3), `ChInventory.move`, `remove_at` and `CAPACITY` (Task 5),
  `ChPrices.sell_value` (Task 4).
- Produces: `class_name ChInventoryBar extends PanelContainer`. It is anchored to the bottom, with 5 slot
  rects and one `ChPartCard` per carried part in its slot, plus a SELL zone at the right.
  - `setup(inventory: ChInventory, catalog: ChCatalog)`
  - `refresh()` rebuilds or repositions cards. Existing cards keep their nodes so they ease, not snap.
  - `slot_index_at(global: Vector2) -> int` returns 0–4, or −1.
  - `over_sell(global: Vector2) -> bool`
  - `highlight(card_def: ChPartDef)` and `clear_highlight()`. While a card is dragged, the accepting zones get
    a `ChUi.ACCENT` rim. Over SELL, the zone's label reads `"+$%d"` with the sell value.
  - Signals:
    - `card_clicked(index: int)`
    - `card_dropped(index: int, at: Vector2)`. The screen routes this to reorder, sell, mount or refuse.
  - `sell_label: Label`, which reads "SELL" at rest.

- [ ] **Step 1: Write the failing tests.**
  - `test_cards_match_inventory`: 3 carried means 3 cards, in order, with empty slots drawn and no counter
    label.
  - `test_slot_and_sell_hit`: each slot's centre maps to its index. The SELL rect's centre is `over_sell`.
  - `test_refresh_keeps_nodes`: after `inventory.move(0, 2)` and `refresh()`, the same three card instances
    remain, now in the new order.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- inventory_bar`. Expected: FAIL.

- [ ] **Step 3: Implement it.** Show cards with `show_count = false`. Leave the layout to the builder, within
  the spec sketch: cards to the left, SELL to the right.

- [ ] **Step 4: Run the tests and check they pass.** Expected: PASS.

- [ ] **Step 5: Commit.** `git add game/shop tests/shop && git commit -m "feat(shop): inventory bar and sell
  zone"`

### Task 12: The shop screen

**Files:**
- Create: `game/shop/ch_shop_screen.gd`
- Test: `tests/shop/test_shop_screen.gd`

**Interfaces:**
- Consumes:
  - `ChShopPhase` (Task 7)
  - `ChInventoryBar` (Task 11)
  - `ChGarage.setup`, `slot_at`, `mount_from_inventory`, `hold`, `piece_dropped` and `changed` (Task 10)
  - `ChPartCard.price` (Task 3)
  - `ChCard` (Task 2)
- Produces: `class_name ChShopScreen extends Control`, covering the full 1280×720.
  - `setup(run: ChRun, catalog: ChCatalog)` makes the `ChShopPhase`, which credits stage 1. The gold label pops
    with the `energy` beat and the text `"+%d"`.
  - `signal fight_requested`
  - Children:
    - `gold_label` at the top right, reading `"Gold %d"`
    - `toggle: Button` on the centre-left. It reads "Garage" while the shop is shown and "Shop" while the
      garage is shown.
    - `middle: Control`, which holds either the stage view or the embedded `ChGarage`
    - `next_button: Button` under the stage content. It reads "Next →", and after stage 4 it reads "Fight".
    - `bar: ChInventoryBar`
  - Stage view:
    - Before a pick, it shows 3 `ChCard` option faces. Each names its theme and kind ("Fire shop", "Weapon
      pack", "+4 gold", "+100 max HP"). Clicking one calls `phase.pick`, and a refusal calls `card.refuse()`.
    - After a shop pick, it shows 3 `ChPartCard`s with `price` set, plus a "Reroll $3" button. A body item
      draws through `ChPitPiece.show_hull`'s paint or the builder's equivalent.
    - After a pack pick, it shows 3 cards with no price.
  - Routing:
    - A shop or pack item dropped on the bar, or clicked, goes to `phase.buy` or `phase.take`. Success refreshes
      the bar and plays `placed` on the new card. Failure calls `refuse()`.
    - A bar card dropped on SELL goes to `phase.sell`.
    - A bar card dropped on another slot goes to `inventory.move`.
    - A bar card dropped on the garage while it is shown goes to `garage.slot_at`, then
      `garage.mount_from_inventory`.
    - A bar card clicked while the garage is shown goes to `garage.hold`.
    - A `piece_dropped` over the bar goes to `garage.lift`. A refusal is handled inside the garage.
    - Anything else has nothing to do, so the card glides home.
  - Auto-sold parts from a body buy each pop a `"+$%d"` on the gold label.
  - Next calls `phase.next()`. When `phase.done()` is true, it emits `fight_requested`.
  - The toggle keeps all phase state. It only swaps which child of `middle` is visible.

- [ ] **Step 1: Write the failing tests.** Drive them through the routing methods, which the signals call:
  `_on_item_dropped(i, at)`, `_on_bar_dropped(i, at)`, `_on_piece_dropped(path, at)` and `_on_next()`.
  - `test_drag_buy`: dropping a shop item at the bar's slot centre lowers gold by its price and adds the part to
    the inventory.
  - `test_drop_item_elsewhere_does_nothing`: gold and inventory are unchanged.
  - `test_bar_to_sell`: gold rises by `sell_value` and the inventory shrinks.
  - `test_bar_reorder`: dropping card 0 on slot 2 reorders the inventory.
  - `test_bar_to_pit_mounts`: with the garage shown, dropping on a free slot's screen point mounts the part.
  - `test_toggle_keeps_stage`: pick an option, toggle twice, and `phase.stage` and `phase.items` are unchanged.
  - `test_next_to_fight`: three `_on_next()` calls make the next button read "Fight". The fourth emits
    `fight_requested`.
  - `test_minimal_hud`: the only Labels in the screen's own chrome (outside the cards, the bar slots and the
    tooltip) are `gold_label` and the bar's `sell_label`.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- shop_screen`. Expected: FAIL.

- [ ] **Step 3: Implement it.** Every Button gets `Feedback.attach_button`.

- [ ] **Step 4: Run the tests and check they pass.** Expected: PASS.

- [ ] **Step 5: Commit.** `git commit -am "feat(shop): shop screen with drag and click routing"`

### Task 13: ChMain runs the run, and fight 1 is tuned

**Files:**
- Modify: `game/ch_main.gd`. Replace the garage loop and remove `STARTER_PARTS` and `STARTER_WHEELS`.
- Modify: `game/run/ch_run.gd`. Tune `FIRST_HP`.
- Test: `tests/test_smoke.gd` or a new `tests/run/test_main_run.gd`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `ChMain` holds `run: ChRun`.
  - `screen` is one of `&"fight"`, `&"result"` or `&"shop"`.
  - `_init` calls `_new_run()`. That is `ChRun.start(randi(), catalog)` followed by `_start_battle()`, so the
    run opens straight into fight 1.
  - A battle starts with `start(run.player_layout(), run.enemy_layout(i), catalog, run.fight_seed(i),
    run.rules(i))`.
  - When the result panel is pressed:
    - if `ends_run`, call `_new_run()`
    - if aborted, call `_start_battle()`
    - otherwise, go to `fight_index += 1` and then `_show_shop()`
  - The shop's `fight_requested` calls `_start_battle()`.

- [ ] **Step 1: Write the failing tests** in `test_main_run.gd`. Drive `ChMain` through its handlers with the
  battle stubbed: call `_on_finished(result, battle)` directly, as the current smoke test does.
  - `test_opens_in_fight`: after `ChMain.new()`, `screen` is `&"fight"` and `run.fight_index` is 0.
  - `test_win_goes_to_shop`: a win followed by back gives screen `&"shop"`, fight_index 1, and gold 25.
  - `test_new_run_resets`:
    - Change gold, the inventory and `hp_bonus`, then report a loss and press back.
    - The result is a fresh run: gold 20, an empty inventory, the starting kit, fight_index 0 and
      `hp_bonus` 0.
  - `test_boss_win_ends_run`: at index 9, a win shows "Run won", and back starts a new run.

- [ ] **Step 2: Run the tests and check they fail.** Run `-- main_run`. Expected: FAIL.

- [ ] **Step 3: Implement it.** Remove the temporary Enter key from Task 10.

- [ ] **Step 4: Tune `FIRST_HP`.**
  - Use the balance runner (`tests/balance/test_scenario.gd`; follow its existing scenario pattern) to run the
    starting kit against the cook at `enemy_hp(0)` over 10 seeds.
  - Lower `FIRST_HP` until the starting kit wins at least 8 of the 10.
  - Record the chosen value and the win count in a comment beside the constant.

- [ ] **Step 5: Run the full suite.** Expected: `0 failed`. Then play by eye with `godot --path .`:
  - fight 1
  - the shop: buy by drag, buy by click, sell, reorder, mount from the bar and lift back
  - fight 2

- [ ] **Step 6: Commit.** `git commit -am "feat(main): the run loop, fight 1 tuned"`
