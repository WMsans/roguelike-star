# Bright Parallax Background Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The battle sits on a bright, saturated, three-layer parallax sky, the whole pit is lit at full colour, and fire and lava can brighten cells above their base colour.

**Architecture:** The engine's light overlay gets a `light_headroom` cap (default 1.0) in place of its hard `1.0`, and the project turns on `hdr_2d` so values above 1 survive the blend. A new `background.tscn` on a `CanvasLayer` at −10 draws a screen-space gradient sky plus the user's `bg0/bg1/bg2`, scrolled by a script that reads the battle camera each frame. `ChBattle` sets the bright lighting values on its `PixelWorld`.

**Tech Stack:** Godot 4.7 Forward Plus, GDScript, canvas_item shaders, the vendored C++ GDExtension at `addons/noita_engine` (built with `build.sh`).

**Spec:** `docs/superpowers/specs/2026-11-05-bright-parallax-background-design.md`

## Global Constraints

- Run tests with `godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]`. The output ends `N passed, M failed`, and every task ends with the whole suite at `0 failed`.
- Rebuild the engine with `addons/noita_engine/build.sh`. `bin/` is untracked, so never commit the `.so`.
- `light_headroom` defaults to `1.0`, so anything that does not set it renders exactly as today.
- The viewport is 1280×720 with `canvas_items` stretch and nearest filtering. The battle camera zoom is 4.0–4.5 (`ChBattle.ZOOM_WIDEST` / `ZOOM_CLOSEST`), and the arena is `Rect2i(0, 0, 480, 180)`.
- One art texel equals one world cell, so a layer's on-screen texel size is the camera zoom.
- The art is 320×180. Copy it from `/mnt/windows/Godot/celeste-background-rendering/textures/parallax_pixelperfect/bg{0,1,2}_00002_.png` to `res://textures/background/bg{0,1,2}.png`.
- Keep the battle only. Do not touch the garage, the HUD or the camera framing.
- Comments follow the repo's house style: say why, not what.

## Review Focus

1. **Camera at the arena edge:** with the camera hard against either end of the 480-cell arena, every layer still covers the full screen width with no gap. Tested in Task 2 (`test_layers_wrap_horizontally`).
2. **Zoom 4.5:** the art is wider than the screen, and the layers must stay centred, not anchored to the left. Tested in Task 2 (`test_art_uv_centres_at_rest`).
3. **No camera yet:** while the arena is still streaming, the background has no `Camera2D` to read and must not error. It holds the rest pose. Tested in Task 2 (`test_no_camera_holds_rest`).
4. **Vertical overrun:** `bg1`/`bg2` must not tile vertically. Above or below the art they are transparent, and the sky clamps its gradient. Tested in Task 2 (`test_art_uv_vertical_outside_is_flagged`).
5. **Fight freeze at result:** after `world.simulating = false` the background keeps drawing, and the lighting values stay as set. Tested in Task 3 (`test_lighting_survives_finished_fight`).

---

### Task 1: Engine `light_headroom`

**Files:**
- Modify: `addons/noita_engine/engine/godot/pixel_world.h` (beside `light_exposure`, ~line 78; setters ~line 269)
- Modify: `addons/noita_engine/engine/godot/pixel_world.cpp` (bind ~line 176–225; `update_light_overlay` ~line 926)
- Modify: `addons/noita_engine/engine/godot/light_shaders.h` (`LIGHT_OVERLAY_SHADER`)
- Test: `tests/engine/test_light_headroom.gd`

**Interfaces:**
- Produces: `PixelWorld.light_headroom: float` (default `1.0`, range hint `"1,8,0.01,or_greater"`), with `set_light_headroom(float)` and `get_light_headroom() -> float`.

- [ ] **Step 1: Write the failing test** `tests/engine/test_light_headroom.gd` (extends `ChTest`):
  - `test_headroom_defaults_to_one`: `assert_near(PixelWorld.new().light_headroom, 1.0)`. Free the world.
  - `test_headroom_round_trips`: set it to `1.8` and assert `get_light_headroom()` is near `1.8`. Free the world.
- [ ] **Step 2: Run** with filter `light_headroom`. Expected: FAIL (invalid property).
- [ ] **Step 3: Implement.** Add the member, the inline setter/getter, the bind and the `ADD_PROPERTY` after `light_exposure`. In `LIGHT_OVERLAY_SHADER`, add `uniform float light_headroom = 1.0;` and change `min(…, 1.0)` to `min(…, light_headroom)`. In `update_light_overlay`, add `rs->material_set_param(light_material, "light_headroom", light_headroom);` next to `light_exposure`.
- [ ] **Step 4: Rebuild** with `addons/noita_engine/build.sh --test`. Expected: the build succeeds and the core doctest suite passes.
- [ ] **Step 5: Run** the full suite. Expected: `0 failed`.
- [ ] **Step 6: Commit** the three engine files and the test: `feat(engine): light_headroom lets light lift cells above their base colour`.

### Task 2: Parallax background scene

**Files:**
- Create: `textures/background/bg0.png`, `bg1.png`, `bg2.png` (copied, see Global Constraints)
- Create: `game/battle/background/bg_sky.gdshader`, `bg_layer.gdshader`
- Create: `game/battle/background/ch_background.gd`, `game/battle/background/background.tscn`
- Test: `tests/battle/test_background.gd`

**Interfaces:**
- Produces: `class_name ChBackground extends CanvasLayer` (`layer = -10`), with:
  - `const ART_SIZE := Vector2(320, 180)`
  - `const REST := Vector2(240, 90)`: the arena centre, where every layer shows its art centred.
  - `@export var speeds := {&"Sky": 0.02, &"Mid": 0.25, &"Front": 0.55}`: the fraction of camera travel each layer follows.
  - `static func art_uv(screen_uv: Vector2, screen_size: Vector2, zoom: float, camera: Vector2, speed: float) -> Vector2`: the art UV (0..1 inside the art) that a screen point samples. Horizontal values may leave 0..1 because the shader wraps them. The pan is `floor((camera - REST) * speed)` whole texels, so layers snap to the art grid.
  - Child `ColorRect`s named `Sky`, `Mid` and `Front` fill the screen, each with its own `ShaderMaterial`. Each frame, `_process` writes the uniforms `view_zoom: float` and `pan: Vector2` (texels, already snapped) from `get_viewport().get_camera_2d()`. With no camera it writes zoom `ChBattle.ZOOM_WIDEST` and pan `Vector2.ZERO`.
- The shaders share one mapping: `p = (screen_px - screen_size / 2) / view_zoom + ART_SIZE / 2 + pan`, so `uv = p / ART_SIZE`. `art_uv` is the GDScript twin of it, and the tests pin the math through that twin.
  - `bg_sky.gdshader` is adapted from the reference `shaders/bg_sky.gdshader`: a vertical `GradientTexture1D` sampled on screen Y, `bg0` luma as the cloud mask, and a sun bloom. Start the gradient as a bright, saturated daytime sky: `#4FB8FF` (top) → `#9FE2FF` → `#FFE3A8` (horizon). The clouds tint toward white.
  - `bg_layer.gdshader` is adapted from the reference `shaders/bg_layer.gdshader`, with the shadow tint dropped. A luma → `GradientTexture1D` grade, starting at Mid `#3E6FD8` → `#9BC4FF` and Front `#2F4FA8` → `#7FD0FF`, gives saturated cool silhouettes that sit behind warm terrain. Output alpha is 0 when `uv.y` is outside 0..1.
  - All three samplers use `repeat_enable, filter_nearest`.

- [ ] **Step 1: Write the failing tests** in `tests/battle/test_background.gd`:
  - `test_art_uv_centres_at_rest`: for zoom `4.0` and `4.5`, `art_uv(Vector2(0.5, 0.5), Vector2(1280, 720), z, ChBackground.REST, 0.25)` is near `Vector2(0.5, 0.5)`.
  - `test_pan_snaps_to_whole_texels`: at zoom 4 and speed 0.25, cameras at `REST + Vector2(3, 0)` and `REST + Vector2(0, 0)` give the same UV (0.75 floors to 0), and `REST + Vector2(4, 0)` shifts `u` by exactly `1.0 / 320`.
  - `test_layers_wrap_horizontally`: with the camera at x `0` and `480` and speed 0.55, both screen edges (`u = 0` and `u = 1`) return finite values. The fractional part, `fposmod(u, 1.0)`, lies in 0..1, which is the sampled texel, so coverage is total.
  - `test_art_uv_vertical_outside_is_flagged`: at zoom 4.5, screen `v = 0` gives `uv.y` ≥ 0 (the art covers it). With a camera 40 cells above REST and speed 1.0, screen `v = 0` gives `uv.y < 0`. That is the case the layer shader turns transparent.
  - `test_no_camera_holds_rest`: instance `background.tscn` into the root with no `Camera2D`, await one frame, and assert `Mid`'s material `pan` is `Vector2.ZERO` and `view_zoom` is `ChBattle.ZOOM_WIDEST`. Free it.
  - `test_scene_shape`: the instanced scene is a `ChBackground` with `layer == -10` and children `Sky`, `Mid` and `Front`, in that draw order.
- [ ] **Step 2: Run** with filter `background`. Expected: FAIL (ChBackground not found).
- [ ] **Step 3: Copy the textures and import.** Copy the three PNGs, then run `godot --headless --path . --import`. Expected: `.import` files appear next to them.
- [ ] **Step 4: Implement** the two shaders, `ch_background.gd` and `background.tscn` per the Interfaces block. The gradients are `GradientTexture1D` sub-resources in the scene.
- [ ] **Step 5: Run** with filter `background`, then the full suite. Expected: `0 failed`.
- [ ] **Step 6: Commit** the textures and their `.import` files, the `game/battle/background/` files and the test: `feat(battle): bright parallax background scene`.

### Task 3: Light the battle bright and put the sky behind it

**Files:**
- Modify: `project.godot` (`[rendering]`: `viewport/hdr_2d=true`)
- Modify: `game/battle/battle.tscn` (instance `background.tscn` as child `Background`, before `Camera`)
- Modify: `game/battle/ch_battle.gd` (constants and `_build_world`, before `add_child(world)`)
- Test: `tests/battle/test_battle_lighting.gd`

**Interfaces:**
- Consumes: `PixelWorld.light_headroom` (Task 1) and `ChBackground` (Task 2).
- Produces these constants on `ChBattle`, set on `world` in `_build_world`:
  - `const AMBIENT := 1.0`
  - `const AMBIENT_TINT := Color(1.0, 0.98, 0.94)`
  - `const LIGHT_HEADROOM := 1.8`
  - `const BACKDROP := Color(0, 0, 0, 0)`

- [ ] **Step 1: Write the failing tests** in `tests/battle/test_battle_lighting.gd`, driving the real `battle.tscn` the way `tests/battle/test_battle.gd` does (reuse its fixtures):
  - `test_world_is_lit_bright`: after `start()` passes its arena build (`started == true`), `world.ambient`, `world.ambient_tint`, `world.light_headroom` and `world.backdrop_color` equal the four constants (colours compared per channel with `assert_near`), and `world.backdrop_color.a == 0`.
  - `test_background_sits_behind_world`: the battle has a `ChBackground` child whose `layer` is below 0, and `$HUD.layer` is greater than it.
  - `test_lighting_survives_finished_fight`: run a fight to `finished`, then assert `world.light_headroom` is still `LIGHT_HEADROOM` and the `ChBackground` is still in the tree and visible.
  - `test_hdr_2d_on`: `ProjectSettings.get_setting("rendering/viewport/hdr_2d")` is `true`.
- [ ] **Step 2: Run** with filter `battle_lighting`. Expected: FAIL.
- [ ] **Step 3: Implement** the setting, the scene instance and the four assignments. The comment says why: ambient 1 stops the light pass dimming the sky and ground, and headroom only works because `hdr_2d` keeps values above 1 through the multiply.
- [ ] **Step 4: Run** the full suite. Expected: `0 failed`. If `hdr_2d` shifts colours that existing tests read back from pixels, report the test and the measured values rather than loosening the assertions.
- [ ] **Step 5: Commit**: `feat(battle): light the pit bright over a parallax sky`.

### Task 4: Tune by screenshot

**Files:**
- Modify only values: the gradient stops in `background.tscn`, `speeds` in `ch_background.gd`, the four `ChBattle` lighting constants, and the engine's existing `bloom_strength`/`bloom_threshold` set beside them if needed.
- Create, only if needed: a `WorldEnvironment` in `battle.tscn` (background mode Canvas, tonemap and glow).

- [ ] **Step 1: Shoot** with `godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- /tmp/claude-1000/bg-shots`, run in a window and not headless. Expected: `garage.png` and `battle.png` are written.
- [ ] **Step 2: Check `battle.png` against the spec's Acceptance.** The sky must be bright and saturated with three distinct layers and no near-black in the air. Terrain and chariots must read at full colour. Flames and lava must brighten their surroundings without clipping to flat white. If anything fails, adjust the values listed above and reshoot. Add the `WorldEnvironment` tonemap only if highlights clip.
- [ ] **Step 3: Check parallax motion** by shooting again after the fight's camera has moved (a later frame, or a temporary `BATTLE_FRAMES` change that is not committed). Layers must sit at visibly different offsets between the two shots, with no seam or gap at the screen edges.
- [ ] **Step 4: Run** the full suite. Expected: `0 failed`. Constant values changed, so the Task 3 tests read the constants rather than literals and still pass.
- [ ] **Step 5: Show the user the final `battle.png`**, then commit: `style(battle): tune the bright background and lighting`.
