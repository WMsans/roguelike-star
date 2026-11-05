# Bright parallax background for the battle — design

Status: waiting on approval. Nothing is built yet.

## Intent

The battle currently plays against a near-black void, and the whole pit is dimmed. Replace that
with a bright, saturated, multi-layer parallax sky in the style of the
`/mnt/windows/Godot/celeste-background-rendering` project, and brighten the whole scene,
ground included. Fire and lava should still glow above that brighter base.

## Why it is dark today (measured in code)

- `PixelWorld` paints an opaque backdrop rect behind the lit area at z −4096, colour
  `(0.07, 0.05, 0.04)` (`addons/noita_engine/engine/godot/pixel_world.cpp`, `update_light_backdrop`).
- Over everything it draws a `blend_mul` overlay at z 4000:
  `min(ambient * ambient_tint + light * light_exposure, 1.0)` (`light_shaders.h`,
  `LIGHT_OVERLAY_SHADER`). The battle sets none of these, so it runs on the engine defaults
  (`ambient 0.40`, tint `(0.62, 0.69, 1.0)`), which multiplies the frame to about 25–40%.
- The `min(…, 1.0)` means light can only darken, never lift a cell above its own colour.

## Goals / non-goals / anti-goals

Goals
- A bright, saturated sky gradient plus the user's three layers (`bg0` sky detail, `bg1` mid,
  `bg2` front) behind the battle, each scrolling at its own rate with the battle camera.
- The whole scene brighter: terrain and chariots show at full colour under a near-white ambient.
- Fire, lava and other emitters push nearby cells *above* full brightness (warm pop).

Non-goals
- The garage (a Control UI with no world or camera); other scenes; new art; particles; audio.
- Changing fight rules, the camera's framing, or the HUD.

Anti-goals
- A sky that is bright but gets dimmed by the light pass (the light overlay must not grey it).
- A blown-out frame where the bright base plus fire glow clips to flat white.
- Changing the engine's behaviour for anything that doesn't opt in (the engine's demo keeps
  today's look).

## Constraints

- Godot 4.7, Forward Plus (the light pass uses RenderingDevice compute). The viewport is 1280×720,
  `canvas_items` stretch, nearest filtering.
- The battle camera zooms 4.0–4.5, so the view is about 284–320 × 160–180 cells. The art is
  320×180, so one art texel ≈ one cell ≈ 4 screen px. The arena is 480×180 cells, so the camera's
  horizontal travel is small and the layers must still cover any view in both axes.
- The engine is vendored source (`addons/noita_engine`). Its `bin/` is not tracked, so a change
  means rebuilding with `addons/noita_engine/build.sh`.
- The textures are the user's own (they live in the reference project at
  `textures/parallax_pixelperfect/bg{0,1,2}_00002_.png`) and get copied into `textures/background/`.

## Approaches

- **A — lighting values + backdrop only.** Set ambient ≈ 1, white tint, transparent backdrop,
  and add a parallax `CanvasLayer`. No engine change. Trade-off: light can never exceed the base
  colour, so fire only shows through the additive bloom and looks flat on the bright base.
- **B — A plus an engine light-headroom setting. Chosen by the user.** Same scene work, plus the
  overlay's `1.0` cap becomes a property so emitters brighten cells above their base colour.
  Costs an extension rebuild and an HDR canvas.
- **C — draw the sky after the light pass using an air mask.** Dropped: it only makes sense if the
  ground stays dark, and the user wants the whole scene brighter.

## How it's built

1. **Engine: `light_headroom`.** New `PixelWorld` float property, default `1.0` (today's
   behaviour, so the demo and tests are unchanged). `LIGHT_OVERLAY_SHADER` becomes
   `min(ambient * ambient_tint + light * light_exposure, light_headroom)`, set alongside
   `ambient` in `update_light_overlay`. Bind it like the other light properties.
2. **HDR canvas.** `project.godot` sets `rendering/viewport/hdr_2d = true`. Without it the
   framebuffer is RGBA8 and a multiply above 1.0 clamps to 1.0 in the blend, so headroom does
   nothing. A `WorldEnvironment` (canvas background mode) with a tonemap and engine glow is
   allowed if the clipped highlights look harsh; the builder decides by screenshot.
3. **Battle lighting values** (in `ChBattle._build_world`, before `add_child(world)`):
   `ambient ≈ 1.0`, `ambient_tint` white or slightly warm, `backdrop_color` alpha 0 (so the sky
   shows through air), `light_headroom ≈ 1.6–2.0`. Exact numbers are tuned by screenshot.
4. **Backdrop scene** (`game/battle/background.tscn` + `ch_background.gd`), instanced by
   `battle.tscn` under a `CanvasLayer` with `layer = -10`, so it is behind the world, untouched by
   the camera transform and the light overlay (which lives in the world's canvas), and under the HUD.
   - **Sky:** a full-screen `ColorRect` with the reference's `bg_sky.gdshader` idea — a vertical
     gradient retuned bright and saturated, with `bg0` used as the cloud/star mask, plus a soft sun
     bloom. The gradient is screen-space, so it doesn't slide with the layer.
   - **Mid/front:** `bg1` and `bg2` as full-screen `ColorRect`s with `bg_layer.gdshader`, retuned
     from the reference's dark maroon grade toward bright saturated tones. Sampler-wrapped
     horizontally, so the layers tile with no gaps.
   - **Scroll:** `ch_background.gd` reads the active `Camera2D` each frame and writes its position
     and zoom into a `camera_pan`-style uniform. Per-layer speeds start from the reference's
     0.02 / 0.25 / 0.55 (sky → front) and are tuned so movement reads at this small camera travel.
     Offsets snap to whole art texels so the layers don't shimmer.
5. **Post bloom:** the reference's `post_glow.gdshader` is optional. The engine already adds bloom
   for emitters; add a screen pass only if the sky needs its own halo.

## Decisions I made (yours to overrule)

- The backdrop is battle-only. The garage keeps its plain UI background.
- `light_headroom` defaults to 1.0 so nothing that doesn't opt in changes.
- The textures are copied into this repo rather than referenced across projects.
- The reference shaders are the starting point and are retuned. The reference's final scene
  (plain `Sprite2D` + engine glow) is not what gets copied, because its gradient would slide with
  the camera.

## Left to the builder

Gradient stops, layer grades, scroll speeds, ambient/tint/headroom values, and whether a tonemap,
engine glow or post pass is needed. All of these are tuned by screenshots from
`tools/screenshot.gd` (battle frame at 400 ticks).

## Acceptance

- The battle screenshot shows a bright, saturated sky with three distinct layers behind the pit,
  with no near-black left in the air.
- Terrain and chariots read at full colour. Flames and lava visibly brighten the cells around
  them without clipping the frame to white.
- When the camera moves, the layers shift at different rates, with no gap, seam bounce or
  shimmer.
- The existing headless test suite still passes, and the engine's own tests pass after the rebuild.
