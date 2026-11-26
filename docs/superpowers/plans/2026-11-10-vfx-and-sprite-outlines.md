# VFX and sprite outlines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every sprite a closed 1-pixel dark outline derived from its silhouette, redraw the tiny weapon sprites so navy is outline not filler, and make the Flamethrower plume stay where it was fired.

**Architecture:** A stdlib Python pass recolours each sprite PNG's boundary ring to its darkest palette colour; `gen_sprite.py` runs it on every new sprite. The hand-pixelled grids are rewritten to the same rule and regenerated. The Flamethrower behaviour stops re-anchoring its jet after `fire()`.

**Tech Stack:** Godot 4.7 GDScript, Python 3 stdlib (no Pillow), PNG RGBA8.

**Spec:** `docs/superpowers/specs/2026-11-10-vfx-and-sprite-outlines-design.md`

## Global Constraints

- Sprite silhouettes (opaque pixel sets) and sizes must not change: `PixelRigidBody` builds collision from opaque pixels.
- Python stdlib only in `tools/sprites/`.
- Baseline suite is 311 passed, 0 failed.

## Review Focus

- A sprite with a single opaque pixel or a 1-pixel-wide arm must still get a ring without crashing or wrapping around the image edges.
- A sprite whose darkest colour already covers the ring (hand grids) must come out byte-identical.
- The flame must not drift or rotate during the 1 s burst; it must still fade on stop and on a mid-burst break.

---

### Task 1: Deterministic outline pass

**Files:**
- Create: `tools/sprites/outline.py`
- Test: `tools/sprites/test_outline.py`

**Interfaces:**
- Produces: `outline_image(data: bytes) -> bytes` (RGBA8 PNG bytes in, same out, in place), and CLI `python3 tools/sprites/outline.py <png>...`.

- [ ] **Step 1: Write the failing test**

```python
import struct, sys, os, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from outline import outline_image
# helper: rgba(pixels, w, h) -> png bytes, and png_pixels(data) -> (w, h, list of rows)
# test_ring_is_darkest: 3x3 all (200,60,40,255) -> ring equals darkest colour, centre untouched
# test_interior_and_alpha_untouched: 3x3 with one transparent pixel; ring only, interior same
# test_hand_grid_unchanged: ring already the darkest colour -> identical bytes
# test_single_pixel: 1x1 -> unchanged, no crash
# test_offimage_neighbour: pixel at (0,0) is treated as an edge
```

- [ ] **Step 2: Run it, confirm failure**

Run: `python3 tools/sprites/test_outline.py`
Expected: `ModuleNotFoundError: No module named 'outline'`

- [ ] **Step 3: Implement `outline_image`**

Decode RGBA8 (colour type 6, bit depth 8, with all five PNG filters), find the darkest opaque colour by
`0.299r + 0.587g + 0.114b`, and for every opaque pixel with a transparent/off-image 4-neighbour write that
colour. Re-encode with `zlib.compress` and filter 0. CLI rewrites each path and prints it.

- [ ] **Step 4: Run tests, confirm pass**

Run: `python3 tools/sprites/test_outline.py`
Expected: `ALL PASS`

- [ ] **Step 5: Commit**

```bash
git add tools/sprites/outline.py tools/sprites/test_outline.py
git commit -m "feat(sprites): deterministic silhouette outline pass"
```

### Task 2: Wire the pass into the sprite pipeline and fix committed sprites

**Files:**
- Modify: `tools/sprites/gen_sprite.py` (after the `SPRITE` download, before writing)
- Modify: `textures/sprites/*.png`

**Interfaces:**
- Consumes: `outline.outline_image`.

- [ ] **Step 1: Run the pass over the committed sprites**

Run: `python3 tools/sprites/outline.py textures/sprites/*.png`
Expected: prints every path; Cutter's right/bottom edge turns dark navy.

- [ ] **Step 2: Wire `gen_sprite.py`**

Apply `outline_image` to the `SPRITE` output bytes only (not `_x8`). Re-running on an already-outlined
sprite is a no-op.

- [ ] **Step 3: Reimport and run the suite**

Run: `godot --headless --import && godot --headless -s res://tests/run_tests.gd`
Expected: `311 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add tools/sprites/gen_sprite.py textures/sprites
git commit -m "fix(sprites): outline every sprite from its silhouette"
```

### Task 3: Redraw the hand sprites

**Files:**
- Modify: `tools/sprites/hand_sprites.gd`
- Modify: `textures/sprites/*.png` (regenerated)

- [ ] **Step 1: Rewrite the grids** so the outer ring is `k` on every side and the interior is art
  (Flamethrower: navy only on the ring, its orange/metal body inside). Sizes and palettes unchanged.

- [ ] **Step 2: Regenerate and outline**

Run: `godot --headless --path . -s res://tools/sprites/hand_sprites.gd`
Run: `python3 tools/sprites/outline.py textures/sprites/*.png`

- [ ] **Step 3: Reimport and run the suite**

Run: `godot --headless --import && godot --headless -s res://tests/run_tests.gd`
Expected: `311 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add tools/sprites/hand_sprites.gd textures/sprites
git commit -m "fix(art): fill tiny weapon sprites, outline only the ring"
```

### Task 4: Freeze the Flamethrower plume where it was fired

**Files:**
- Modify: `game/battle/behaviours/ch_flamethrower.gd`
- Test: `tests/battle/test_behaviours_fire.gd`

- [ ] **Step 1: Write the failing test**

In `test_behaviours_fire.gd`, after the burst starts, record `jet.position` and `jet.rotation`, turn the
part's body (so `facing()` changes), tick `process` a few times, and assert both values are unchanged.
The existing break test still asserts the stop.

- [ ] **Step 2: Run it, confirm failure**

Run: `godot --headless -s res://tests/run_tests.gd -- behaviours_fire`
Expected: FAIL, position/rotation changed.

- [ ] **Step 3: Remove the per-tick re-anchor from `process`**

Keep only the `stop()` when `burst_left` reaches 0. Update the file's header comment.

- [ ] **Step 4: Run the suite**

Run: `godot --headless -s res://tests/run_tests.gd`
Expected: `312 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add game/battle/behaviours/ch_flamethrower.gd tests/battle/test_behaviours_fire.gd
git commit -m "fix(vfx): let the flamethrower plume stay where it was fired"
```

### Task 5: Verify by eye and on the full suite

- [ ] **Step 1:** Run the throwaway capture script against a flamethrower fight and check the plume is
  world-anchored for the burst (`/tmp/flame_shot`), then delete the script.
- [ ] **Step 2:** Run the full suite one last time: `godot --headless -s res://tests/run_tests.gd`.
- [ ] **Step 3:** Commit any remaining tracked change and report the worktree path and branch.
