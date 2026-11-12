# Anchored Puff VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the bolts and the flamethrower their baked-pixel mass back as puffs that are dropped into the
world where the emitter was, so no emitted pixel ever rides a mover.

**Architecture:** A new pixelfx recipe (`tools/fx/chariot/puff.js`) bakes two compact, centre-origin one-shot
sheets — `puff_fire` and `puff_smoke`. `ChProjectile` drops one into the `PixelWorld` every 8 cells of flight
(distance, not time), alternating the two; each puff is a `ChFx` one-shot that frees itself. The existing pool
trail stays underneath as the moving sparks. The flamethrower drops `puff_fire` at the nozzle on a timer and
holds no reference, so a break needs no teardown. `ChFx` is unchanged: it already refuses any parent but the
world, which is exactly why the puffs cannot ride anything.

**Tech Stack:** Godot 4.7, GDScript; pixelfx (Node) at bake time only. Tests are `tests/run_tests.gd`, methods
extend `ChTest`.

**Spec:** `docs/superpowers/specs/2026-11-12-anchored-puff-vfx-design.md`

## Global Constraints

- 1 sheet pixel = 1 cell. The battle camera stays between `ZOOM_WIDEST` 4.0 and `ZOOM_CLOSEST` 4.5, so a puff
  must be drawn at cell size, never scaled up in Godot.
- Every `test_*` method ends with `_complete()` as its last statement.
- `ChFx.spawn` parents to the `PixelWorld` and nothing else. Do not add a parent override.
- Balance does not move: the flamethrower's material particle counts, speed, spread and reach, the bolts'
  `SPEED` / `GRAVITY` / `LIFE`, and every damage number stay as they are.
- Puffs are nodes, not pool particles: nothing here goes through `ChFeedbackParticles.budget`, and a full
  pool must not stop the trail from being drawn.
- pixelfx is a bake-time checkout and is not committed. Only the baked `textures/fx/*.png`, their `.import`
  files and `textures/fx/fx.json` land in the repo.
- Suite: `godot --headless -s res://tests/run_tests.gd`, green at branch head with 314 passed. Report any
  pre-existing failure you find rather than fixing it inside a task.

## Review Focus

- A bolt at full speed (160 cells/s) crossing a 60 Hz tick: the cadence is in cells, so the stream must read
  continuous and a paused fight must drop nothing.
- The pool past 75% full: `ChFeedbackParticles.budget` returns 0 and the sparks stop, and the puffs must still
  appear.
- A long fight with two rockets and a firebolt in the air: puff count stays bounded per bolt and every puff
  frees itself on its last frame.
- A flamethrower broken mid-burst: no puff appears after the break, and the fire particle count is unchanged.
- A bolt that hits or leaves the arena mid-flight: puffs it already dropped stay where they are and fade; the
  bolt's own free takes nothing with it.

---

### Task 1: Bake the puff sheets

**Files:**
- Create: `tools/fx/chariot/puff.js`
- Modify: `tools/fx/bake.mjs` (the `FX` map)
- Create: `textures/fx/puff_fire.png`, `textures/fx/puff_smoke.png`, and their `.import` files
- Modify: `textures/fx/fx.json`

**Interfaces:**
- Produces: two effect ids, `&"puff_fire"` and `&"puff_smoke"`, playable through the existing
  `ChFx.spawn(world, &"puff_fire", at, dir)` with `meta.loop == false`, 12 frames at 30 fps, frame 20×20,
  pivot at the frame's centre. Later tasks name these ids and nothing else.

- [ ] **Step 1: Confirm the toolchain (already run once — repeat only if the checkout is gone)**

`git clone --depth 1 https://github.com/patch-gg/pixelfx /tmp/pixelfx` then
`node tools/fx/bake.mjs /tmp/pixelfx`. Expected: the nine existing sheets re-bake and print their frame
counts, and `git status textures/fx` is clean. This was run at branch head with a clean result, so the
checkout in `/tmp/pixelfx` matches the sheets in the repo. If a re-run now differs, stop and report.

- [ ] **Step 2: Write the recipe**

`tools/fx/chariot/puff.js` — one compact, roughly radial one-shot. The meta is fixed:

```js
export const meta = {
  name: "Puff",
  desc: "One small puff of an emitter's trail: a hot wisp cooling through the fire palette, or the same shape in smoke greys.",
  tags: ["puff", "trail", "smoke", "fire", "one-shot", "chariot"],
  size: [20, 20],
  origin: [10, 10],
  duration: 0.4,
  loop: false,
  fps: 30,
  bg: "sky",
  options: { kind: "fire", seed: 4, palette: ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"] },
};
```

`draw(p, t, o)` draws five puffs staggered over the first 0.12 s: puff *i* is born at `t0 = i * 0.03`, has
`k = 1 - (t - t0) / 0.4` (skip while `t < t0` or `k <= 0`), starts within a cell of the centre, drifts outward
and up at `vx = ±(2..6)` and `vy = -(6..14)` cells per second, and grows as it ages. `kind: "fire"` draws it
with `firePuff(p, x, y, k, size, frac, H)` from `../fire/_lib.js` with `size` in `1.4 .. 3.2`; `kind: "smoke"`
draws the same offsets with `smokePuff(p, x, y, k, size, hex(o.palette[2]), true, 0.8)`. Colours come from
`fit(o.palette, 8)` for fire and from the same palette for smoke. Randomness comes from `rng(meta.options.seed, i)`
so every bake is byte-identical. No `p.glow` larger than the frame: a trail puff must not light the arena.

- [ ] **Step 3: Add the two bake entries**

In `tools/fx/bake.mjs`'s `FX` map, next to the `chariot/*` entries:

```js
  puff_fire: ["chariot/puff", {}],
  puff_smoke: ["chariot/puff", { kind: "smoke", palette: ["#1a171c", "#26222e", "#3d3846", "#5a5463", "#7e7887", "#a7a1ad", "#d0cad2", "#f1ecee"] }],
```

- [ ] **Step 4: Bake and import**

`node tools/fx/bake.mjs /tmp/pixelfx` — expected: `puff_fire` and `puff_smoke` each print `12f 20x20`, and no
other sheet's line changes. Then `godot --headless --import`, expected: exit 0, and
`textures/fx/puff_fire.png.import` and `textures/fx/puff_smoke.png.import` exist.

- [ ] **Step 5: Check the manifest and the frames by eye**

`python3 -c "import json;m=json.load(open('textures/fx/fx.json'));print(m['puff_fire'],m['puff_smoke'])"` —
expected: both `loop: false`, `frames: 12`, `size: [20, 20]`, `pivot: [10, 10]`. Then open the two PNGs and
confirm each frame is a small wisp centred on its 20×20 cell, not a cropped or offset shape.

- [ ] **Step 6: Commit**

```bash
git add tools/fx/chariot/puff.js tools/fx/bake.mjs textures/fx/puff_fire.png textures/fx/puff_fire.png.import \
  textures/fx/puff_smoke.png textures/fx/puff_smoke.png.import textures/fx/fx.json
git commit -m "feat(fx): bake the trail puff, fire and smoke"
```

---

### Task 2: The bolt drops a puff every eight cells

**Files:**
- Modify: `game/battle/ch_projectile.gd`
- Modify: `game/battle/behaviours/ch_firebolt.gd` (delete `TRAIL_COLOUR` and the line that sets it)
- Modify: `game/battle/behaviours/ch_rocket.gd` (same)
- Test: `tests/battle/test_behaviours_ranged.gd`

**Interfaces:**
- Consumes: `&"puff_fire"` / `&"puff_smoke"` from Task 1, and the existing `ChFx.spawn(parent, fx, at, dir)`.
- Produces: `ChProjectile` without `trail_color`; the trail is unconditional and owned by the bolt.

- [ ] **Step 1: Write the failing tests**

In `tests/battle/test_behaviours_ranged.gd`, add a helper and three tests beside the existing bolt test:

```gdscript
# The world's own baked effects: a puff is one of these, and the muzzle flash is another.
func _fx(world: PixelWorld) -> Array:
	var found: Array = []
	for child in world.get_children():
		if child is ChFx:
			found.append(child)
	return found

func _is_puff(node: ChFx) -> bool:
	var path := node.texture.resource_path
	return path.ends_with("puff_fire.png") or path.ends_with("puff_smoke.png")
```

- `test_bolt_drops_a_puff_every_eight_cells` — fire the rocket, take the bolt, let it fly 24 frames, then:
  `_fx(world)` filtered by `_is_puff` is at least 2; both of the first two puffs are puffs; and the two
  positions are `8.0` cells apart (`is_equal_approx(puffs[1].position.distance_to(puffs[0].position), 8.0)`).
- `test_a_dropped_puff_never_moves_again` — record `puffs[0].global_position` and `puffs[0].rotation`, let the
  bolt fly 10 more frames, assert both are unchanged. This is the regression the emitter-split bug needs: it
  fails if any emitted pixel ever rides the bolt again.
- `test_puffs_appear_even_when_the_pool_is_full` — before firing, fill the pool past the budget's share with
  `world.spawn_visual_particles(Color.WHITE, ORIGIN, Vector2.ZERO, int(world.get_max_particles()))`; assert
  `ChFeedbackParticles.budget(world, 1) == 0`, then fire and assert a puff still appears.
- `test_puffs_free_themselves` — fire, let the bolt hit or expire, then await 40 frames and assert no `ChFx`
  under the world is a puff.

Also update `test_bolt_trail_is_particles_and_the_bolt_stays_visible`: delete the
`assert_true(bolt.trail_color.a > 0.0, ...)` line, since the field is going.

- [ ] **Step 2: Run them to make sure they fail**

`godot --headless -s res://tests/run_tests.gd -- ranged` — expected: failures naming the new tests (no puffs
exist; `trail_color` may still resolve, which is why the field's removal is their real failure).

- [ ] **Step 3: Implement the cadence in `game/battle/ch_projectile.gd`**

Replace `trail_color` and its constants with:

```gdscript
var _puff_owed: float = 0.0  # cells flown since the last puff
var _puff_turn: int = 0  # which of TRAIL_FX the next puff is
```

```gdscript
# The trail is a chain of puffs, each born where the bolt was and left in the world's keeping: the emitter
# moves, the pixels do not. Distance rather than time, so a lobbed bolt and a straight one both read
# continuous, and a paused fight drops nothing.
const TRAIL_FX := [&"puff_fire", &"puff_smoke"]  # taken in turn, so a stream is a wisp of flame in smoke
const PUFF_EVERY := 8.0  # cells between puffs
const PUFF_OFFSET := 3.0  # cells behind the bolt's nose, where a trail begins
```

In `_physics_process`, after `global_position = to`, call `_drop_puffs(from.distance_to(to))`. Keep
`_throw_trail()` as it is, so the pool sparks stay.

```gdscript
func _drop_puffs(flew: float) -> void:
	# Only the world may own a baked effect, and a puff is one: it stays where it was born.
	_puff_owed += flew
	while _puff_owed >= PUFF_EVERY:
		_puff_owed -= PUFF_EVERY
		var back := bolt_velocity.normalized() * PUFF_OFFSET
		if ChFx.spawn(battle.world, TRAIL_FX[_puff_turn], global_position - back, bolt_velocity) != null:
			_puff_turn = (_puff_turn + 1) % TRAIL_FX.size()
```

- [ ] **Step 4: Delete the behaviours' colour**

In `ch_firebolt.gd` and `ch_rocket.gd`: remove the `TRAIL_COLOUR` const and its comment, and the
`bolt.trail_color = TRAIL_COLOUR` line. One trail recipe, shared; nothing per part is left to say.

- [ ] **Step 5: Run the tests**

`godot --headless -s res://tests/run_tests.gd -- ranged` — expected: every test in the file passes. Then
`godot --headless -s res://tests/run_tests.gd` — expected: 314 + the new tests, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add game/battle/ch_projectile.gd game/battle/behaviours/ch_firebolt.gd \
  game/battle/behaviours/ch_rocket.gd tests/battle/test_behaviours_ranged.gd
git commit -m "feat(vfx): a bolt drops its trail as puffs the world owns"
```

---

### Task 3: The flamethrower thickens its nozzle with puffs

**Files:**
- Modify: `game/battle/behaviours/ch_flamethrower.gd`
- Test: `tests/battle/test_behaviours_fire.gd`

**Interfaces:**
- Consumes: `&"puff_fire"` from Task 1.
- Produces: nothing other tasks use; the behaviour still exposes no `jet` field and needs no `teardown()`.

- [ ] **Step 1: Write the failing tests**

In `tests/battle/test_behaviours_fire.gd`, reuse the existing `_fx_nodes(world)` helper:

- `test_flamethrower_burst_drops_puffs_at_the_nozzle` — the mid-burst case (`FLAME_MID_BURST_TICKS`), then
  assert at least one `ChFx` under the world whose `texture.resource_path` ends with `puff_fire.png`, and that
  its `position` is within `NOZZLE + 12` cells of `part.anchor_world()`.
- `test_breaking_a_firing_flamethrower_stops_its_puffs` — count the puffs, `at.break_part(flame, ctx)`, run 30
  more ticks like the existing burst test, assert the count did not rise.
- Update `test_flamethrower_burst_is_the_sim_own_flame`: it asserts `_fx_nodes(world).size() == 0`. Change it
  to assert every `ChFx` under the world is a `puff_fire` sheet — the flame is still the sim's own particles,
  and the only baked thing left is a puff, which is not a jet.

- [ ] **Step 2: Run them to make sure they fail**

`godot --headless -s res://tests/run_tests.gd -- fire` — expected: the two new tests fail, and the updated
flame test fails on the stray puffs it does not expect yet.

- [ ] **Step 3: Implement the nozzle puff**

Add to `ch_flamethrower.gd`:

```gdscript
# The plume's shape is the sim's own fire particles. This is only mass where the fuel leaves the barrel: a
# puff the world keeps, so a rig that rolls mid-burst drags no tail with it and a break needs no teardown.
const PUFF_GAP := 0.05  # seconds between puffs: ~10 live over a burst, overlapping into a plume
var puff_left := 0.0  # seconds until the next nozzle puff
```

In `fire()`, set `puff_left = 0.0`. In `process()`, after the `burst_left` bookkeeping and before the material
spawn, spend the timer:

```gdscript
	puff_left -= delta
	if puff_left <= 0.0:
		puff_left += PUFF_GAP
		ChFx.spawn(ctx.world, &"puff_fire", nozzle, part.facing())
```

`nozzle` is the local the material spawn already computes — use it, do not recompute the anchor.

- [ ] **Step 4: Run the tests**

`godot --headless -s res://tests/run_tests.gd -- fire` — expected: all pass, including the unchanged reach and
break tests. Then the full suite — expected: 0 failed.

- [ ] **Step 5: Look at it**

Run the fight (`tools/screenshot.gd`) at a real frame with a rocket and a flame firing and check the spec's
open knobs by eye: puff size, `PUFF_EVERY`, `PUFF_OFFSET`, `PUFF_GAP`. Change only those constants; if the look
needs a different recipe, that is a new bake, not a code tweak.

- [ ] **Step 6: Commit**

```bash
git add game/battle/behaviours/ch_flamethrower.gd tests/battle/test_behaviours_fire.gd
git commit -m "feat(vfx): the flamethrower's plume gets its mass back at the nozzle"
```
