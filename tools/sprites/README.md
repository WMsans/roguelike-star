# Pixel sprites from a shape + a prompt

`gen_sprite.py` turns a silhouette PNG and a one-line description into finished pixel sprites, using the
`sprite/sprite_from_shape` workflow on the ComfyUI server (Krea2 + PixelArt LoRA). Python stdlib only.

```sh
# tunnel first if localhost:8188 isn't up:  ssh -N -L 8188:127.0.0.1:8188 jeremy@100.122.99.38
python3 tools/sprites/gen_sprite.py --shape hull.png \
  --subject "a tall armored siege-tower chariot hull of blue steel plates with a dark viewing slit near the top and a few bolts" \
  [--seeds 4] [--seed 1] [--out ./sprites_out] [--server http://localhost:8188]
```

It prints each file it writes and exits 1 with a one-line `error: …` on failure (server unreachable, job error,
600 s timeout). One run with `--seeds N` gives N variants:

- `<out>/<shape-stem>_s<seed>_<i>.png`: the sprite. RGBA, exactly the shape's size, opaque pixels = the shape's. The model's outline is replaced by `outline.py`'s: the silhouette's boundary ring becomes the sprite's darkest colour, so every edge is closed.
- `<out>/<shape-stem>_s<seed>_<i>_x8.png`: the same ×8, for looking at. Look at these before picking.

Change `--seed` for a new set.

## The shape PNG

- **Native size: 1 pixel = 1 sprite pixel = 1 game cell.** `PixelRigidBody` builds the body from opaque pixels, so
  the sprite's opaque set is exactly the shape's opaque set.
- Opaque pixels (alpha ≥ 50%) are solid. A PNG without alpha uses dark pixels as solid. Draw it **dark on
  transparent** so both readings agree.
- At most 128 px per side.
- **Under ~16 px on the short side, draw the sprite by hand**: the model can't put detail in that little room and
  the result is mush (wheel 12×12, strut 3×8, Cutter 34×9 were all bad).

## Writing the subject

The template adds the size, the style (dark navy outline, 3 flat shades per material, lit from the top left) and the
background. Your subject only says *what it is*:

- Name the **materials and colours**: "blue steel plates", "rusty orange iron", "dark wood planks with brass bands".
- Place the **small parts**: "a dark viewing slit near the top", "two bolts on each side", "a red lamp at the front".
- **+x (right) is forward**: put guns, blades and noses on the right ("a short barrel pointing right").
- Keep it to one object. Don't describe the background or the outline shape; the shape decides the outline.

## Changing the workflow

`build_workflow.py` is the source of the graph. It writes both copies on the server and an example shape:

```sh
python3 tools/sprites/build_workflow.py          # → workflows/sprite/sprite_from_shape.json + _api.json
python3 tools/sprites/test_build_workflow.py     # tests: titles, links, UI widget order
python3 tools/sprites/test_gen_sprite.py
python3 tools/sprites/test_outline.py   # the ring pass; also runs alone: python3 tools/sprites/outline.py <png>...
```

If you edit the graph by hand in the ComfyUI UI instead, use **Export (API)** and save it over
`workflows/sprite/sprite_from_shape_api.json`, or `gen_sprite.py` won't see the change. Keep the node titles
`SHAPE`, `SUBJECT`, `SEED`, `BATCH`, `SPRITE` and `PREVIEW`: they're how `gen_sprite.py` finds its inputs.
The two custom nodes (`Sprite Shape Canvas`, `Sprite Finish`) live in the server's
`ComfyUI/custom_nodes/pixel_palette.py`. Their tests are in `/home/jeremy/inference/pixel_node_tests/`.
