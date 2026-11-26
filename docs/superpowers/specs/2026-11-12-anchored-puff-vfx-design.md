# Pixel VFX: anchored puffs — design

## Intent

The emitter split (2026-11-12-pixel-vfx-emitter-split) is right: nothing emitted rides a mover.
But it took the baked look away with the bug. A bolt's trail is now 3 single-cell particles per
tick at one point per 2.5 cells of flight — a dotted 1-cell thread where a shaped cloud used to be.
Baked sheets and the pool draw the same 1-cell pixels; the sheet's mass came from *count and
arrangement*, and that is what is missing.

Jeremy picked **anchored puffs** over fattening the pool stream or adding per-particle size to the
engine: keep the art, and get the split by dropping each puff where the emitter *was*.

## Design

### A puff is a one-shot baked effect the world owns

`tools/fx/chariot/puff.js`: one compact, roughly radial one-shot — origin at the puff's centre, so
`ChFx.spawn(world, puff, at, dir)` puts the puff on the point that asked for it, and `face()` only
leans it along flight. Same pixelfx recipe twice through the palette option, baked as two entries:

- `puff_fire` — a flame wisp, fire palette.
- `puff_smoke` — the same shape in the smoke greys, for the rocket.

Both layers are wanted, not one: the rock of smoke under a hot wisp on top. Every bolt drops both,
alternating — no per-part trail tuning, so no field for one.

Nothing new in `ChFx`: `spawn` already refuses a parent that moves, which is exactly the rule a puff
needs. Each puff is a one-shot, so it `queue_free`s itself on its last frame.

### ChProjectile: drop a puff every N cells

Each physics frame the bolt adds the distance it flew to an accumulator; while the accumulator is
over `PUFF_EVERY` (8 cells) it spawns the next puff of `TRAIL_FX` (`[&"puff_fire", &"puff_smoke"]`,
taken in turn) at `global_position - flight_dir * PUFF_OFFSET` — a few cells back, where a sheet's
trail would begin — and subtracts 8. Distance rather than time, so a lobbed bolt and a straight one
both get a continuous stream, and a paused or slow frame cannot stack puffs.

`trail_color: Color` goes, and with it both behaviours' `TRAIL_COLOUR`: one trail recipe, shared.

The pool trail stays as it is: the anchored puffs are the mass, the pool particles are the moving
sparks on top of it. Two layers of one system, not two systems.

### The bolt keeps its disc

`core` stays unset by both behaviours: every bolt flies as `ChTextures.disc(CORE_DIAMETER, …)` in
its launcher's colour. That is the emitter's body, and a body may ride its own emitter.

### Flamethrower: puffs at the nozzle

`spawn` a `puff_fire` at the nozzle every ~0.05 s of a burst and keep no reference: the plume's
shape stays the sim's own fire particles, the puffs thicken where the fuel leaves the barrel, and a
part broken mid-burst needs no teardown because there is no node to hold. The material emission
numbers do not move, so the reach test and the balance runs read an unchanged fight.

### Budget

Puffs are nodes, not pool particles, so `ChFeedbackParticles` does not see them. They are bounded by
construction instead: a fixed life and a cadence in cells → at most `life * speed / 8` live per bolt
(~15 for a rocket at 0.7 s of puff life) and ~15 for a flame at `PUFF_GAP` 0.05 s. If that ever shows,
the knob is `PUFF_EVERY`, not a new cap.

## Tests

- `test_bolt_puffs_are_dropped_and_then_stay_put` — a firing rocket leaves puffs under the world, and
  a puff's `global_position` is the same ten ticks later. This is the regression the "refuses a
  parent" test cannot give: it fails if anything emitted ever rides the mover again.
- `test_bolt_puffs_clean_themselves_up` — once the bolt is gone, no `ChFx` is left under the world.
- `test_flamethrower_burst_drops_puffs_at_the_nozzle` and, on a break, none after it.
- The existing visual-pool assert stays: the trail's sparks are still particles.

## Assets

Baking needs the pixelfx checkout (`git clone https://github.com/patch-gg/pixelfx <dir>`), then
`node tools/fx/bake.mjs <dir>` and `godot --headless --import` — same workflow as the last commit.
The puff recipe borrows `fire/_lib.js`'s `firePuff` / `smokePuff`, as the deleted flamethrower
source did.

## What is left to the builder

Puff size, life, cadence and the two palettes, set by eye against a real frame
(`tools/screenshot.gd`, not a test).
