# Pixel VFX: split the emitter from the particles — design

## Intent

The battle's VFX come from pixelfx sprite sheets baked offline (`tools/fx/bake.mjs` → `textures/fx/`),
played by one `ChFx` `Sprite2D`. A baked effect's particle positions live *inside* its frames,
relative to the sheet origin, so the node's transform carries the whole already-emitted cloud: any
effect parented to a mover rides it rigidly. Jeremy wants the emitter and the particles split, so
that once a particle is out, nothing about the emitter's transform changes it.

## Goals

- The three effects that are emitted along a moving path stop being one rigid sprite: the
  Flamethrower jet, the Firebolt's trail, the Rocket's trail.
- Those particles are simulated in cell space by the engine's own pool
  (`PixelWorld.spawn_visual_particles`), which no node transform can touch.
- A baked effect can no longer be parented to a mover at all — the rule is enforced, not commented.
- A flying bolt stays visible.

## Non-goals

- Re-sizing or re-baking the sheets. The battle camera is pinned at `ZOOM_WIDEST` 4.0 /
  `ZOOM_CLOSEST` 4.5, so the 320×180 frame pixelfx draws into maps 1:1 onto the screen's art
  pixels; the sheets are already correct for the screen. How big they read next to an 8×4-cell part
  is an art-ratio question for another day.
- New effects, new feedback profiles, or any change to what the fight reads.
- Replacing the nine one-shot sheets that already spawn under `ctx.world` (`muzzle`, `blast`,
  `fire_blast`, `fire_nova`, `spark_hit`, `blunt_hit`, `frost`, `shatter`, `ignite`). They are born
  in cell space and are already immune to the emitter.

## Anti-goals

- A VFX change that moves balance: the Flamethrower's and Chainsaw's real `fire` particle counts,
  speeds and reach are pinned by the fire tests and the balance runner, and must not move.
- A second particle system that duplicates the one in `addons/noita_engine`.

## Constraints

- `addons/noita_engine` is the only particle sim in the build; its pool is shared with gameplay
  particles, so decoration must obey `ChFeedbackParticles.budget` (CAP 24, skip past 75% full).
- 1 sheet pixel = 1 cell, and the camera never goes below 4.0 zoom: emitted pixels must be single
  cells, same as the world's own.
- Baseline suite before this change: `godot --headless -s res://tests/run_tests.gd`.

## Approaches

**A — engine pool for everything, sheets deleted.** Least code; every effect becomes a recipe of
counts/colours/lifetime. Trades away the shaped bursts (a nova, a shatter, a muzzle flash) that
read as art today.

**B — own FX layer in GDScript** (pooled MultiMesh of quads under the world layer, additive glow,
per-particle sprites). Full art control; ~200 lines plus tests, and it re-implements the pool the
engine already runs and already draws, lit by the same code as the terrain.

**C — hybrid** *(picked by Jeremy)*. Streaming effects — the ones emitted along a path — become real
engine particles; the shaped one-shots stay baked sheets, since they are already spawned in world
space and never follow anything. Trades a mixed system for the smallest change that removes the
rigid-cloud failure.

## Design

### Flamethrower: the jet is deleted, not replaced

`ch_flamethrower.gd` already throws 3 real `fire` particles per tick at the nozzle, and the sim
draws in-flight particles in their material colour and lands them as fire cells. The sheet was a
rigid copy painted on top of the flame. So: drop the `jet` field, the `ChFx.spawn` in `fire()`, the
`stop()` in `process()`, and the `teardown()` override that only existed to fade that jet. The
material emission numbers stay exactly as they are, so the burn, the reach test and the balance
runs read an unchanged fight.

### ChProjectile: emits, and carries its own body

`trail: ChFx` becomes two look fields set by the behaviour: `trail_color: Color` and an optional
`core: Texture2D`. Each physics frame the bolt calls

    world.spawn_visual_particles(trail_color, global_position,
        bolt_velocity * TRAIL_SPEED_SHARE, n, TRAIL_SPREAD, TRAIL_LIFE, 0.0, false)

with `n` from `ChFeedbackParticles.budget`. The particles inherit a *share* of the bolt's velocity,
so the bolt outruns them and the trail streams behind them; they are never addressed again.
`trail.face(...)` goes away with the field.

When `core` is unset, the bolt makes its own `ChTextures.disc(3, launcher.def.color)` so no bolt can
be invisible by forgetting a look. The core sprite mirrors on the sign of `bolt_velocity.x` and never
rotates, which keeps it on the pixel grid; a core is the emitter's body, so following the bolt is
correct for it.

### ChFx: cell space or nothing

`ChFx.spawn` returns null and pushes a warning when `parent` is not the `PixelWorld`. The failure
that produced this bug — `ChFx.spawn(bolt, …)` — becomes impossible instead of discouraged.

### Assets

`textures/fx/{flamethrower,fireball,rocket}.png` and their `.import` files are deleted, along with
their entries in `tools/fx/bake.mjs`; `textures/fx/fx.json` is regenerated by re-running the bake
against the local pixelfx checkout (`~/.claude/plugins/marketplaces/pixelfx`), which also proves the
tool still works for the nine sheets that remain.

## Calls made by Claude

- The Flamethrower gets no decorative layer of its own; the sim's fire particles are the flame. If
  the plume reads thin, the knob is a short-lived `spawn_visual_particles` puff, not the material
  counts (those are balance).
- The trail constants (`TRAIL_SPEED_SHARE`, `SPREAD`, `LIFE`, per-frame count) live on
  `ChProjectile` shared by both bolts; only the colour differs per part. Two bolts do not earn two
  tunings.
- Trails pass through terrain (`collides = false`): a smoke trail that dies on the first cell it
  crosses reads worse than one that carries on.
- `ChFeedbackParticles.budget` is reused rather than restated, so the "decoration never starves the
  fight" rule stays in one place.

## Tests

- `tests/battle/test_behaviours_fire.gd`: the two jet tests go — `test_flamethrower_jet_stays_where_it_was_fired`
  because the pool offers no position readback to pin against, and
  `test_breaking_a_firing_flamethrower_stops_its_jet` because there is no node left for a break to
  take. In their place: `test_flamethrower_burst_is_the_sim_own_flame` (the burst raises
  `world.get_stats()["particles_material"]` and puts no `ChFx` under the world),
  `test_breaking_a_firing_flamethrower_stops_its_burst` (the pool only drains after the break) and
  `test_fx_refuses_a_parent_that_moves` (`ChFx.spawn` takes the world, answers null for a body).
- `tests/battle/test_behaviours_ranged.gd`:
  `test_bolt_trail_is_particles_and_the_bolt_stays_visible` — a firing rocket leaves one `Sprite2D`
  core and no `ChFx` on the bolt, and raises `world.get_stats()["particles_visual"]`.
- Full suite green: 314 passed, 0 failed (the branch's baseline is 311 + the one pre-existing
  `test_catalog` sprite failure the worktree's missing imports cause).

## What is left to the builder

The trail's exact numbers (count per frame, speed share, lifetime, spread) and the two trail
colours, set by eye against a real frame (`tools/screenshot.gd`, not a test).
