# Pixel sprite workflow (shape + prompt → sprite) — design

## Intent

Every hull and part in the game is a flat-colour placeholder, and the garage draws them as smooth
rectangles. We want a ComfyUI workflow on the inference server (`localhost:8188`, tunnelled to
`jeremy@100.122.99.38`) that turns a **silhouette PNG + a prompt** into a finished pixel sprite. Jeremy
runs it by hand in ComfyUI; other LLM agents must be able to drive it with one command.

Quality bar: hand-made-looking low-res pixel art like
[this reference](https://i.pinimg.com/736x/d6/21/3e/d6213ef386deb23cce4220710e3783cd.jpg): one dark
outline, ~3 flat shades per material lit from one side, small parts (knobs, bolts, slits) as 1–3 pixel
clusters, no noise, no dithering, no gradients.

## Goals

- Output is an RGBA PNG at **exactly the silhouette's size, 1 sprite pixel = 1 game cell**.
  `PixelRigidBody` builds the body from opaque pixels, so the opaque set must equal the silhouette's.
- Each sprite gets **its own 8-colour palette**, picked from its own render.
- One graph, two entry points: the ComfyUI UI for Jeremy, an API-format copy + a CLI for agents.
- Several seeds per run, so you can choose between them.

## Non-goals

- Wiring sprites into the game (battle textures, garage cards/pit drawing). Separate follow-up.
- Sprites below ~16 px on the short side (freeze charge 4×4, flamethrower 8×4, wheel 12×12, strut 3×8,
  Cutter 34×9 came out mush in tests). Those get hand-pixelled. Separate follow-up.
- A shared game-wide palette. Tried Sweetie 16 and dropped it (see Approaches).
- Animation, sprite sheets, generating silhouettes.

## Anti-goals

- Generating a detailed image and shrinking it. Tests showed the detail averages into mush: the
  render looks great and the sprite looks terrible. Detail must be **decided at the target size**.
- Snapping to a fixed palette: it turned steel highlights into cyan "ice" streaks.
- Agents building or editing graphs themselves.

## Constraints

- Server: ComfyUI 0.45, 2× RTX 2080 Ti 22 GB, Linux. Custom nodes are single `.py` files in
  `/home/jeremy/inference/ComfyUI/custom_nodes/` (not a git repo). New nodes load on a ComfyUI restart.
  ComfyUI isn't a service: it runs detached as `.venv/bin/python main.py --listen 127.0.0.1 --port 8188`
  from `/home/jeremy/inference/ComfyUI`. **Ask Jeremy before restarting it**, because it may be running his own jobs.
  The node's logic can be unit-tested outside ComfyUI first.
- Installed models used: `krea2_turbo_fp8_scaled` + `PixelArt_One_Token_128_Krea2T_8x8_M_V1…epoch_10`
  LoRA (trigger `pixelart`, 1024 px canvas = 128×128 art pixels, 8 px per art pixel),
  `qwen3vl_4b_fp8_scaled` (CLIPLoader type `krea2`), `qwen_image_vae`.
- Recipe already proven in the server's `sprite/` and `pixel_parallax/` workflows: 8 steps, CFG 1,
  euler/simple, `ConditioningZeroOut` negative, `ImageScale nearest-exact` to snap the 8 px grid.
- Workflows live **on the server** in ComfyUI's user data (`/userdata/workflows%2F…` API), not in this repo.
- Largest silhouette must fit 128 art pixels (Corsair hull is 52×10: fine).

## Approaches

Packaging (picked **A**):

- **A. One graph, saved as UI + API JSON, plus a stdlib CLI.** Input nodes have fixed titles the CLI
  fills in. Hand edits in the UI flow to agents once the API copy is re-exported. *Picked*: smallest,
  one source of truth.
- B. A single all-in-one custom node. More server Python to maintain, and agents still need A's CLI.
- C. A ComfyUI MCP server for agents. New dependency, and agents would end up building graphs themselves.

Generation (tested in two spikes; picked **Krea2 inpainting on the native grid**):

| Tried | Result |
|---|---|
| Krea2 img2img at native or ×k scale, then downscale | Raw renders great, sprites mush. Denoise 0.9 ignores the silhouette; 0.75 follows it. Background leaked into the sprite wherever the model under-filled the shape. |
| Qwen-Image-Edit-2511 from silhouette | Ignores size (wheel drawn ~1.7× too big). |
| Qwen-Edit "redraw the masterpiece small, style of the reference" | Copied the masterpiece instead of simplifying. |
| Qwen-Edit silhouette + style reference | Redrew the reference coffee machine. |
| **Krea2, silhouette drawn on the LoRA's 8 px grid at native size, inpaint only inside the silhouette, "tiny simple chunky icon" prompt** | **Picked.** First result that looks designed at 22×30. |

Colour (picked **k-means in OKLab, medoid representatives, 8 colours per sprite**):

- Sweetie 16 snap: dropped, made weird colours (see Anti-goals).
- Octree (existing `ImageListQuantizeShared`), k-means with cluster averages, and k-means with the most
  central real colour all looked close. Jeremy picked the **medoid** variant: every output colour is one
  the model actually drew, so there are no muddy averaged colours.

## Design (decided)

### Pipeline

1. **Shape in.** A native-size PNG; opaque pixels = solid cells. The graph must take this file directly
   (no manual prep in the UI).
2. **Canvas.** 1024×1024 flat light-green (`#c8e8b0`) background, silhouette scaled ×8 nearest and
   centred on the 8 px grid, filled mid-grey (`#808080`).
3. **Generate.** Krea2 turbo + PixelArt LoRA (strength 1), `VAEEncode` the canvas, `SetLatentNoiseMask`
   with the silhouette mask (grown 8 px in the spike), KSampler 8 steps / CFG 1 / euler / simple /
   **denoise 0.8**. Prompt = fixed style prefix + the user's subject:
   `pixelart. A tiny simple chunky {w}x{h} pixel game icon of {subject}, filling the grey shape completely. Dark navy outline, 3 flat shades per material lit from the top left, no texture, no noise. Small parts are 1 to 3 pixel clusters. Plain flat light green background.`
   `{w}x{h}` comes from the shape automatically.
4. **Back to native.** Crop the silhouette's box, `ImageScale nearest-exact` to native size.
5. **Finish (new node).** Inside the silhouette, pixels that are still background colour (the "leak")
   become the sprite's darkest colour, so they read as outline. Then each sprite gets its own 8 colours
   via k-means in OKLab over the opaque pixels only, with deterministic farthest-point seeding (most
   frequent colour first) and ~30 iterations. Each cluster is replaced by its **medoid**: the real
   source colour nearest the cluster centre. Outside the silhouette goes fully transparent.
6. **Save.** The native RGBA sprite, plus a ×8 nearest preview for looking at.

Seeds: one queue run produces N seeds (default 4) for picking.

### Server pieces

- New node, added to `custom_nodes/pixel_palette.py` beside the existing pixel nodes:
  `ImageQuantizeKMeansMedoid` (image, colors=8, optional mask; transparent/unmasked pixels ignored and
  kept transparent). The background-leak fill (step 5) may be the same node or a small sibling node. The builder decides.
- Workflows in server user data:
  - `workflows/sprite/sprite_from_shape.json`: UI format, with a MarkdownNote explaining use.
  - `workflows/sprite/sprite_from_shape_api.json`: API format. Input nodes titled exactly
    `SHAPE` (LoadImage), `SUBJECT` (prompt string), `SEED`, `BATCH` (seed count); output SaveImage
    titled `SPRITE` (native) and `PREVIEW` (×8).

### Repo pieces (`tools/sprites/`)

- `gen_sprite.py`: Python stdlib only. Usage:
  `python3 tools/sprites/gen_sprite.py --shape path/to/shape.png --subject "…" [--seeds 4] [--seed 1] [--out dir] [--server http://localhost:8188]`.
  It fetches `sprite_from_shape_api.json` from the server's userdata (so the server copy is the only
  copy), uploads the shape, fills the titled nodes, queues, waits on `/history`, and downloads
  `<out>/<shape-stem>_s<seed>.png` (+ `_x8.png`). Exits non-zero with ComfyUI's error text on failure.
- `README.md`: aimed at agents. What a shape PNG is, how to write a subject (name colours and materials,
  facing direction: +x is forward), and the command. Also the limit: under ~16 px on the short side, draw by hand.

## Left to the builder

- Exact node wiring for centring/padding the native shape onto the 1024 canvas inside the graph.
- Whether the mask grows (the spike used +8 px) and the exact background-leak threshold.
- Splitting the finish step into one node or two.
- Default output folder for the CLI (the scratch/output dir vs. `textures/…`); placement into the game is the follow-up project.

## Calls made without asking (check these)

- Denoise 0.8, mask grow 8, 4 seeds default: taken from the spike.
- Leak pixels become the darkest colour (outline), not keyed out: keying would change the physics shape.
- New node goes into the existing `pixel_palette.py`, not a new file.
- CLI pulls the API JSON from the server at run time instead of keeping a copy in the repo.
