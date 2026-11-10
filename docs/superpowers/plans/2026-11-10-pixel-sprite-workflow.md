# Pixel Sprite Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A ComfyUI graph on the inference server that turns a native-size silhouette PNG + a subject prompt into a native-size RGBA pixel sprite with its own 8-colour palette, drivable by hand and by a one-command CLI.

**Architecture:** Two new nodes in the server's `custom_nodes/pixel_palette.py` do the exact pixel work (shape → 1024 canvas + inpaint mask; generated image + shape → finished sprite). Between them, Krea2 + the PixelArt LoRA inpaint inside the silhouette on the LoRA's 8 px grid. A repo script emits the graph in both UI and API formats to the server's userdata. A stdlib CLI fetches the API graph, fills its titled inputs, queues it and downloads the sprites.

**Tech Stack:** ComfyUI 0.45 (server venv: Python 3.12, numpy, scipy, torch, PIL), Python 3 stdlib on the Mac.

**Spec:** `docs/superpowers/specs/2026-11-10-pixel-sprite-workflow-design.md`

## Global Constraints

- Server: `ssh jeremy@100.122.99.38`. ComfyUI root `/home/jeremy/inference/ComfyUI`, Python `/home/jeremy/inference/ComfyUI/.venv/bin/python`. The Mac reaches it at `http://localhost:8188` (SSH tunnel).
- ComfyUI is not a service. **Ask Jeremy before restarting it.** Restart = kill the `main.py --listen 127.0.0.1 --port 8188` process, then from the root run `nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 > comfyui.log 2>&1 &`.
- Never put test files in `custom_nodes/`, because ComfyUI imports every `.py` there. Server tests live in `/home/jeremy/inference/pixel_node_tests/`.
- 1 sprite pixel = 1 game cell. Output opaque set == silhouette solid set, and alpha is strictly 0 or 1.
- Canvas: 1024×1024, 8 px per cell (max 128×128 cells), background `#c8e8b0`, silhouette fill `#808080`, offsets snapped to multiples of 8.
- Sampling: `krea2_turbo_fp8_scaled.safetensors`; LoRA `PixelArt_One_Token_128_Krea2T_8x8_M_V1_krea2_3264755_epoch_10.safetensors` strength 1; CLIP `qwen3vl_4b_fp8_scaled.safetensors` type `krea2`; VAE `qwen_image_vae.safetensors`; KSampler 8 steps, CFG 1, euler, simple, denoise 0.8; negative = `ConditioningZeroOut` of the positive.
- Prompt template (verbatim): `pixelart. A tiny simple chunky {size} pixel game icon of {subject}, filling the grey shape completely. Dark navy outline, 3 flat shades per material lit from the top left, no texture, no noise. Small parts are 1 to 3 pixel clusters. Plain flat light green background.` (`{size}` = `WxH`, e.g. `22x30`).
- Colours: k-means in OKLab over the sprite's solid non-leak pixels; deterministic farthest-point seeding starting at the most frequent colour; 30 iterations; each cluster is replaced by its medoid (the real source colour nearest the cluster centre); default 8 colours. Leak pixels (solid pixels within threshold of the background) become the darkest palette colour (lowest OKLab L).
- Server userdata paths: `workflows/sprite/sprite_from_shape.json` (UI), `workflows/sprite/sprite_from_shape_api.json` (API).
- Titled nodes the CLI relies on: `SHAPE` (LoadImage), `SUBJECT` (PrimitiveStringMultiline), `SEED` (PrimitiveInt), `BATCH` (PrimitiveInt), `SPRITE` (SaveImage, native), `PREVIEW` (SaveImage, ×8).
- The Mac side uses only the Python standard library.

## Review Focus

1. A shape PNG with no alpha channel (all opaque): treat pixels with luma < 0.5 as solid instead of the whole square. Pinned in Task 1 (`test_shape_without_alpha_uses_dark_pixels`).
2. Anti-aliased shape edges (alpha between 0 and 1): solid iff alpha ≥ 0.5, and output alpha strictly 0/1. Pinned in Task 1 (`test_soft_alpha_thresholds_at_half`).
3. An empty shape, or one larger than 128 cells on a side: fail with a message naming the size, never a silent crop. Pinned in Task 1 (`test_rejects_empty_and_oversized`).
4. A batch of several seeds: each image gets its own palette of ≤ 8 colours; a sprite with fewer distinct colours keeps them all. Pinned in Task 1 (`test_batch_palettes_are_per_image`, `test_fewer_colours_than_k_kept`).
5. CLI against a dead server or a failed job: exit non-zero with the reason (connection error / ComfyUI's error text), never hang or write empty files. Pinned in Task 3 (`test_dead_server_exits_nonzero`).

---

### Task 1: Sprite nodes on the server

**Files:**
- Modify: `/home/jeremy/inference/ComfyUI/custom_nodes/pixel_palette.py` (append; reuse its existing `srgb_to_oklab`)
- Create: `/home/jeremy/inference/pixel_node_tests/test_sprite_nodes.py`

**Interfaces:**
- Produces (pure functions, numpy float arrays in 0..1):
  - `shape_solid(image: np.ndarray[H,W,3], mask: np.ndarray[H,W]) -> np.ndarray[H,W] bool`. `mask` is ComfyUI's LoadImage mask (= 1 − alpha). If the mask is all 0 (no alpha), solid = luma < 0.5. Otherwise solid = (1 − mask) ≥ 0.5. Raises `ValueError` if there are no solid pixels or either side > 128, naming `WxH`.
  - `canvas_origin(w: int, h: int) -> tuple[int, int]` = `(((1024 - w*8)//2)//8*8, ((1024 - h*8)//2)//8*8)`.
  - `kmeans_medoid(colors: np.ndarray[N,3], k: int) -> np.ndarray[N,3]` returns each input colour replaced by its cluster medoid.
- Produces (nodes, registered in `NODE_CLASS_MAPPINGS` / display names; both use `FUNCTION = "run"`, `CATEGORY = "image/postprocessing"`):
  - `SpriteShapeCanvas`. Inputs: `shape` IMAGE, `shape_mask` MASK, `grow` INT (default 8, 0..64). Returns `(IMAGE canvas[1,1024,1024,3], MASK inpaint[1,1024,1024], STRING size "WxH")`. The inpaint mask is 1 on the solid cells ×8, dilated by `grow` px. Display name "Sprite Shape Canvas".
  - `SpriteFinish`. Inputs: `images` IMAGE[B,1024,1024,3], `shape` IMAGE, `shape_mask` MASK, `colors` INT (default 8, 2..32), `leak_threshold` FLOAT (default 0.1). Returns `(IMAGE sprite[B,h,w,4], IMAGE preview[B,h*8,w*8,4])`. It samples cell centres (`x*8+4`) inside the box at `canvas_origin`, marks solid pixels whose max channel difference to `#c8e8b0` ≤ threshold as leak, quantizes the rest per image with `kmeans_medoid`, sets leak pixels to the darkest palette colour (if every solid pixel is leak, it quantizes them as normal colours), and makes non-solid pixels transparent. Display name "Sprite Finish (8-colour k-means)".

- [ ] **Step 1: Write the failing tests** in `test_sprite_nodes.py`. Use plain `assert`s; a `__main__` runs every `test_*` and prints `ALL PASS`. Import via `sys.path.insert(0, "/home/jeremy/inference/ComfyUI/custom_nodes")`.

```python
def test_round_trip_identity():
    # 22x30 trapezoid with alpha; feed the canvas straight back as the "generated" image
    canvas, inpaint, size = SpriteShapeCanvas().run(shape, shape_mask, 8)
    assert size == "22x30" and canvas.shape == (1, 1024, 1024, 3)
    sprite, preview = SpriteFinish().run(canvas, shape, shape_mask, 8, 0.1)
    assert sprite.shape == (1, 30, 22, 4) and preview.shape == (1, 240, 176, 4)
    a = sprite[0, ..., 3].numpy()
    assert set(np.unique(a)) <= {0.0, 1.0} and (a == 1).sum() == solid.sum() and ((a == 1) == solid).all()
    assert np.allclose(sprite[0][solid][:, :3].numpy(), 128 / 255, atol=1 / 255)   # grey fill survives

def test_leak_becomes_darkest():
    # generated = canvas with a navy block (#1a1c2c) and a bg-coloured hole inside the silhouette
    ...; assert colour at the hole == colour at the navy block

def test_batch_palettes_are_per_image():
    # batch of 2 generated images with 20 random colours each, disjoint hues
    ...; assert each image has <= 8 distinct opaque colours and the two palettes differ

def test_fewer_colours_than_k_kept():
    ...; assert a 3-colour sprite comes out with exactly those 3 colours

def test_medoid_is_a_source_colour():
    out = kmeans_medoid(cols, 8); assert every row of out is present in cols

def test_shape_without_alpha_uses_dark_pixels():
    # black disc on white, mask all zeros
    assert shape_solid(img, np.zeros(...)).sum() == disc_pixels

def test_soft_alpha_thresholds_at_half():
    # alpha 0.4 -> not solid, 0.6 -> solid
    ...

def test_rejects_empty_and_oversized():
    for bad in (empty_shape, shape_129_wide): expect ValueError whose message contains the WxH
```

(`...` = build the arrays as the comment says; the asserts after it are the spec.)

- [ ] **Step 2: Run them, expect failures**

Run: `ssh jeremy@100.122.99.38 'cd /home/jeremy/inference && ComfyUI/.venv/bin/python pixel_node_tests/test_sprite_nodes.py'`
Expected: `ImportError`/`NameError` on `SpriteShapeCanvas`.

- [ ] **Step 3: Implement** the three functions and two nodes per the Interfaces above. The k-means algorithm is fixed by Global Constraints: seeding = most frequent OKLab colour, then repeatedly the point farthest from its nearest centre, up to `min(k, distinct)`; 30 Lloyd iterations; the medoid is chosen among the cluster's distinct source colours. Do it with numpy on distinct colours weighted by count (sprites are ≤ 128×128). Edit with `ssh` + a heredoc patch or `scp` a copy back. Back up first: `cp pixel_palette.py pixel_palette.py.bak-2026-11-10`.

- [ ] **Step 4: Run tests, expect `ALL PASS`** (same command).

- [ ] **Step 5: Ask Jeremy to restart ComfyUI**, then restart it per Global Constraints and verify:
Run: `curl -s localhost:8188/object_info/SpriteFinish | python3 -m json.tool | head -5`
Expected: the node's input spec, with no import error in `comfyui.log`.

- [ ] **Step 6: Record the change** (server dir is not git): append a dated line to `docs/superpowers/plans/2026-11-10-pixel-sprite-workflow.md` under "Server changes log" at the bottom, then commit that file.

---

### Task 2: The graph, in UI and API format, on the server

**Files:**
- Create: `tools/sprites/build_workflow.py` (emits both formats from one graph definition and uploads them)
- Create: `tools/sprites/test_build_workflow.py`

**Interfaces:**
- Consumes: the `SpriteShapeCanvas` / `SpriteFinish` signatures from Task 1; server `GET /object_info` for widget order.
- Produces: `graph() -> dict` (API format, node ids are strings, every node has `_meta.title`); `to_ui(api: dict, object_info: dict) -> dict` (litegraph UI JSON: `nodes` with `id/type/title/pos/size/inputs/outputs/widgets_values`, `links`, `last_node_id`, `last_link_id`, `version: 0.4`); uploads via `POST /userdata/workflows%2Fsprite%2F<name>.json?overwrite=true`. Includes a `MarkdownNote` node in the UI copy explaining use (shape PNG rules, `{subject}` tips, <16 px → hand-draw).
- Graph (titles in caps are the CLI contract): `SHAPE` LoadImage → `SpriteShapeCanvas` → VAEEncode(canvas) → `RepeatLatentBatch`(amount ← `BATCH`) → `SetLatentNoiseMask`(inpaint) → KSampler(seed ← `SEED`) → VAEDecode → `SpriteFinish`(shape, shape_mask) → `SPRITE` SaveImage(sprite, prefix `sprite_from_shape/sprite`) and `PREVIEW` SaveImage(preview, prefix `sprite_from_shape/preview`). Prompt = two `StringReplace` nodes filling `{size}` (from the canvas node) and `{subject}` (from `SUBJECT`) in the template held by a `PrimitiveStringMultiline` titled `Style template`. Defaults: `SEED` 1, `BATCH` 4, `SUBJECT` "a tall armored siege-tower chariot hull of blue steel plates with a dark viewing slit near the top and a few bolts".

- [ ] **Step 1: Write the failing test** (`python3 tools/sprites/test_build_workflow.py` prints `ALL PASS`):

```python
def test_contract_titles():
    titles = {n["_meta"]["title"]: n["class_type"] for n in graph().values()}
    assert titles["SHAPE"] == "LoadImage" and titles["SUBJECT"] == "PrimitiveStringMultiline"
    assert titles["SEED"] == titles["BATCH"] == "PrimitiveInt"
    assert titles["SPRITE"] == titles["PREVIEW"] == "SaveImage"

def test_links_resolve():
    g = graph()
    for n in g.values():
        for v in n["inputs"].values():
            if isinstance(v, list): assert v[0] in g

def test_ui_matches_api():
    ui = to_ui(graph(), json.load(open(FIXTURE_OBJECT_INFO)))   # fixture: object_info subset saved next to the test
    assert len([n for n in ui["nodes"] if n["type"] != "MarkdownNote"]) == len(graph())
    assert len(ui["links"]) == sum(isinstance(v, list) for n in graph().values() for v in n["inputs"].values())
```

- [ ] **Step 2: Run it, expect failure** (`ModuleNotFoundError: build_workflow`).
- [ ] **Step 3: Implement `graph()`, `to_ui()`, and `main()`** (`main` fetches `/object_info`, writes both JSONs, uploads both). In `to_ui`, `widgets_values` follow `object_info` input order for non-link inputs. Seed-like INT widgets with `control_after_generate` get an extra `"fixed"` after their value. Lay nodes out left-to-right in a 300 px grid.
- [ ] **Step 4: Run test, expect `ALL PASS`**, then `python3 tools/sprites/build_workflow.py`. Expected: two `200` upload lines, and `curl -s "localhost:8188/userdata?dir=workflows/sprite"` lists both files.
- [ ] **Step 5: Smoke run** the API JSON via `POST /prompt` with `SHAPE` = an uploaded 22×30 Dozer trapezoid (outline `(-11,15),(11,15),(8,-15),(-8,-15)`) and `BATCH` 2. Expected: 2 `SPRITE` files of 22×30 RGBA, each with ≤ 8 opaque colours and its alpha equal to the trapezoid. Check with a few lines of stdlib PNG reading (reuse `read_png` from the spike if handy).
- [ ] **Step 6: Ask Jeremy to open `sprite/sprite_from_shape` in the ComfyUI sidebar and press Queue once.** Expected: it loads without missing-widget warnings and produces sprites. Fix `to_ui` if not.
- [ ] **Step 7: Commit** `tools/sprites/build_workflow.py tools/sprites/test_build_workflow.py` (+ fixture).

---

### Task 3: CLI and README for agents

**Files:**
- Create: `tools/sprites/gen_sprite.py`
- Create: `tools/sprites/test_gen_sprite.py`
- Create: `tools/sprites/README.md`

**Interfaces:**
- Consumes: the userdata path and the titles contract from Task 2.
- Produces: `fill(api: dict, shape_name: str, subject: str, seed: int, batch: int, prefix: str) -> dict` (returns a filled copy; sets `SHAPE.inputs.image`, `SUBJECT.inputs.value`, `SEED.inputs.value`, `BATCH.inputs.value`, and `filename_prefix` of `SPRITE`/`PREVIEW` to `f"{prefix}"` / `f"{prefix}_x8"`; raises `KeyError` naming any missing title). CLI: `gen_sprite.py --shape PATH --subject TEXT [--seeds 4] [--seed 1] [--out DIR (default: ./sprites_out)] [--server http://localhost:8188]`. It writes `<out>/<stem>_s<seed>_<i>.png` and `<out>/<stem>_s<seed>_<i>_x8.png` (i = batch index; one seed drives the whole batch), prints each path, and exits 1 with a one-line reason on connection error, on a job error (ComfyUI's `exception_message`), or after a 600 s timeout.

- [ ] **Step 1: Write the failing tests** (`python3 tools/sprites/test_gen_sprite.py` → `ALL PASS`):

```python
def test_fill_sets_contract_fields():
    api = {"1": {"class_type": "LoadImage", "inputs": {"image": "x"}, "_meta": {"title": "SHAPE"}}, ...all six titles...}
    out = fill(api, "up.png", "a wheel", 5, 3, "sprite_from_shape/wheel")
    assert by_title(out, "SHAPE")["inputs"]["image"] == "up.png"
    assert by_title(out, "SEED")["inputs"]["value"] == 5 and by_title(out, "BATCH")["inputs"]["value"] == 3
    assert by_title(out, "PREVIEW")["inputs"]["filename_prefix"] == "sprite_from_shape/wheel_x8"
    assert by_title(api, "SEED")["inputs"].get("value") != 5        # input not mutated

def test_fill_missing_title_names_it():
    # drop BATCH -> KeyError whose message contains "BATCH"

def test_dead_server_exits_nonzero():
    r = subprocess.run([sys.executable, GEN, "--shape", SHAPE_FIXTURE, "--subject", "x", "--server", "http://127.0.0.1:9"], capture_output=True, text=True, timeout=30)
    assert r.returncode == 1 and r.stderr.strip() and not os.listdir(tmp_out)
```

- [ ] **Step 2: Run, expect failure** (`ModuleNotFoundError: gen_sprite`).
- [ ] **Step 3: Implement** with `urllib` + `json` only: upload via multipart `POST /upload/image` (overwrite true), `GET /userdata/workflows%2Fsprite%2Fsprite_from_shape_api.json`, `POST /prompt`, poll `GET /history/<id>` every 1 s, then download each image of the `SPRITE`/`PREVIEW` node outputs via `/view`, in order.
- [ ] **Step 4: Run tests, expect `ALL PASS`.**
- [ ] **Step 5: Write `README.md`** for agents. Cover:
  - what a shape PNG is (native size, opaque = solid, 1 px = 1 cell, ≤ 128 per side)
  - how to write a subject (name materials and colours, and that +x is the part's facing direction)
  - the command and its outputs
  - that sprites under ~16 px on the short side should be drawn by hand
  - that the graph source is `build_workflow.py`, and hand edits made in the UI need "Export (API)" saved over the `_api.json`
- [ ] **Step 6: End-to-end check:**
  Run: `python3 tools/sprites/gen_sprite.py --shape <dozer 22x30 PNG> --subject "a tall armored siege-tower chariot hull of blue steel plates with a dark viewing slit near the top and a few bolts" --seeds 2 --out /tmp/…/scratchpad/e2e`
  Expected: 4 files printed (2 sprites at 22×30, 2 previews at 176×240), exit 0. Show the previews to Jeremy.
- [ ] **Step 7: Commit** `tools/sprites/gen_sprite.py tools/sprites/test_gen_sprite.py tools/sprites/README.md`.

---

## Server changes log

(Task 1 appends here.)
