# VFX and sprite outlines — design

## Intent

Two visual defects in the battle:

1. **The Flamethrower's flame tail moves with the gun.** The jet is re-positioned and re-rotated
   onto the nozzle every fight tick (`ch_flamethrower.gd` `process`), so the whole rigid plume —
   head and already-burned tail — swings with the rig. A flame is emitted; its tail stays where it
   was burned.
2. **Sprites have uneven outlines.** The dark outline is painted by the image model ("dark navy
   outline" in the prompt) or by the hand grids, not derived from the silhouette. Cutter's wedge
   has navy on its left/top edge only; weapon sprites expose orange/pink/tan on some edges; the
   Flamethrower's 8x4 grid uses navy as *filler* (5 of 8 pixels in its top row), so the outline
   reads a couple of pixels thick around a tiny object.

## Goals

- One closed, 1-pixel dark outline around every sprite's opaque silhouette, on every side.
- The tiny weapon sprites fill their silhouette with art; navy is outline only, not filler.
- The Flamethrower's plume stays where it was fired for the length of the burst.
- Sprite silhouettes do not change, so collision shapes, `def.size` and balance are untouched.

## Non-goals

- Regenerating the large model-made sprites (Cutter, Corsair, Dozer, wheel) through ComfyUI.
- Interior outlines between materials (only the silhouette edge is outlined).
- New VFX, new animations, or changes to the other effects.
- Rebuilding the prompt/workflow graph on the server.

## Approaches

**Sprite outline** — one sensible way left after the others were ruled out:

- *Model prompt only (current)*: uneven; ruled out by the defect report.
- *Draw the rim outside the silhouette*: grows the opaque set, and `PixelRigidBody` builds the body
  from opaque pixels, so it would change collision and balance; ruled out.
- **Recolour the silhouette's boundary ring to the sprite's darkest palette colour** *(picked)*:
  the opaque set is unchanged, the outline is deterministic and closed on every side, and it works
  for both model-made and hand-made sprites.
- Hand sprites are then redrawn in `hand_sprites.gd` so the boundary ring is already the navy `k`
  and the interior is art. A boundary pass is a no-op on them afterwards.

**Flamethrower plume** — Jeremy chose *stay where it was fired*: freeze the jet's position and
rotation at `fire()` and leave it until the burst ends. The plume no longer follows the gun.

## Design

### Outline pass

`tools/sprites/outline.py`, Python stdlib only:

- `outline_image(rgba_bytes) -> bytes`: decode RGBA8 PNG, find the darkest opaque colour (lowest
  luminance among alpha >= 128, the engine's own empty cut; ties on first seen), set every opaque
  pixel with an empty (alpha < 128) or off-image 4-neighbour to that colour, alpha 255, re-encode.
  A faint anti-aliased edge therefore cannot grow the collision silhouette.
- CLI: `python3 tools/sprites/outline.py <png>...` rewrites each file in place and prints it.
- `gen_sprite.py` runs the pass on each `SPRITE` download before writing it (not on `_x8`
  previews), so new sprites arrive outlined.

Run once over `textures/sprites/*.png`, then reimport in Godot.

### Hand sprites

*Revised after review:* ringing the hand grids inside their box turned every tiny part into a navy
square (a 3-4 px tall part loses most of its art to the ring). The grids are back to their original art
with the navy *background* made transparent (`.`), so each part has its real shape. They are not run
through `outline.py`. Instead `ChTextures.ringed` draws a 1-px navy outline *outside* the shape for the
visual (battle and garage card), and `ChTextures.solid` gives the body the full `def.size` box with the
background filled navy, which matches the old pixels exactly, so collision, mass and balance stay the same.
`outline.py` stays for the model-made sprites (Cutter, Corsair, Dozer, wheel).

### Flame plume

`ch_flamethrower.gd`:

- `fire()` keeps spawning the jet at the nozzle turned to `facing()` — unchanged.
- `process()` no longer writes `jet.position` / `jet.face(...)`; it only calls `jet.stop()` when the
  burst is spent. `teardown()` still stops a jet on a part broken mid-burst.

## Tests

- `tools/sprites/test_outline.py`: ring is the darkest colour on all four sides; interior colours and
  alpha untouched; already-outlined input is unchanged; degenerate 1x1 and 1-pixel-wide sprites; an
  opaque island in a transparent field; a faint pixel is empty and not the outline colour; the ring
  is written solid.
- `tests/battle/test_behaviours_fire.gd`: the jet's position and rotation stay at the fire-time
  values while the part's facing changes.
- Full suite: `godot --headless -s res://tests/run_tests.gd` (311 baseline, 0 failed).

## Calls made without asking

- The outline pass lives in Python (the sprite pipeline's language), not GDScript, so the committed
  PNGs are fixed for every consumer (battle, garage, tooltips) and the fix survives re-export.
- The boundary pass recolours the silhouette's outer ring only; deliberate dark interior detail
  (a hearth's mouth, a fire ring's hole) stays.
- Hand grids get redrawn only as far as the outline/filler defect requires; their palette and
  silhouettes stay.
