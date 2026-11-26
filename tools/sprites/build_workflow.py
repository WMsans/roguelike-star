"""Builds the shape + prompt -> pixel sprite ComfyUI graph and saves it on the server in both formats:
workflows/sprite/sprite_from_shape.json (UI, for people) and sprite_from_shape_api.json (API, for gen_sprite.py).
Python stdlib only. Run: python3 tools/sprites/build_workflow.py [--server http://localhost:8188]
Spec: docs/superpowers/specs/2026-11-10-pixel-sprite-workflow-design.md"""
import argparse, json, struct, urllib.parse, urllib.request, uuid, zlib

TEMPLATE = ("pixelart. A tiny simple chunky {size} pixel game icon of {subject}, filling the grey shape completely. "
            "Dark navy outline, 3 flat shades per material lit from the top left, no texture, no noise. "
            "Small parts are 1 to 3 pixel clusters. Plain flat light green background.")
SUBJECT = "a tall armored siege-tower chariot hull of blue steel plates with a dark viewing slit near the top and a few bolts"
EXAMPLE_SHAPE = "sprite_from_shape_example.png"  # the Dozer hull trapezoid, uploaded so the UI graph opens ready to Queue
WORKFLOW_DIR = "workflows/sprite"

NOTE = f"""## Shape + prompt → pixel sprite

Turns a **native-size silhouette PNG** into a finished pixel sprite of exactly that size (1 pixel = 1 game cell).

1. **SHAPE**: load your silhouette. Opaque pixels are solid. Without alpha, dark pixels are solid, so draw it dark on
   transparent. Max 128 px per side. Under ~16 px on the short side the result is mush: draw those by hand.
2. **SUBJECT**: what it is. Name the colours and materials and where the small parts go ("a dark viewing slit near
   the top"). +x (right) is forward. The size and the style come from **Style template** automatically.
3. **SEED** / **BATCH**: BATCH images per run, each with its own look.
4. Queue. `output/sprite_from_shape/sprite_*.png` are the native RGBA sprites, `preview_*.png` are ×8 for looking at.

How it works: the shape is drawn grey on light green at 8 px per pixel on a 1024 canvas (the PixelArt LoRA's grid),
Krea2 repaints only inside it (denoise 0.8), and **Sprite Finish** samples each 8 px cell back to one pixel, picks
each image's own 8 colours (k-means in OKLab, every colour a real one from the image), paints leaked background
inside the shape with the darkest colour and makes everything outside transparent.

Agents: `python3 tools/sprites/gen_sprite.py` drives `{WORKFLOW_DIR}/sprite_from_shape_api.json`. After editing this
graph by hand, re-run `tools/sprites/build_workflow.py` or re-export the API copy, or agents won't see the change."""


def graph():
    """API-format graph. Titles in caps are the gen_sprite.py contract."""
    def n(cls, title, **inputs):
        return {"class_type": cls, "inputs": inputs, "_meta": {"title": title}}
    return {
        "1": n("UNETLoader", "Load Krea2 turbo", unet_name="krea2_turbo_fp8_scaled.safetensors", weight_dtype="default"),
        "2": n("LoraLoaderModelOnly", "PixelArt LoRA (8 px grid)", model=["1", 0], strength_model=1,
               lora_name="PixelArt_One_Token_128_Krea2T_8x8_M_V1_krea2_3264755_epoch_10.safetensors"),
        "3": n("CLIPLoader", "Load text encoder", clip_name="qwen3vl_4b_fp8_scaled.safetensors", type="krea2", device="default"),
        "4": n("VAELoader", "Load VAE", vae_name="qwen_image_vae.safetensors"),
        "5": n("LoadImage", "SHAPE", image=EXAMPLE_SHAPE),
        "6": n("SpriteShapeCanvas", "Sprite Shape Canvas", shape=["5", 0], shape_mask=["5", 1], grow=8),
        "7": n("PrimitiveStringMultiline", "Style template", value=TEMPLATE),
        "8": n("PrimitiveStringMultiline", "SUBJECT", value=SUBJECT),
        "9": n("StringReplace", "Fill {size}", string=["7", 0], find="{size}", replace=["6", 2]),
        "10": n("StringReplace", "Fill {subject}", string=["9", 0], find="{subject}", replace=["8", 0]),
        "11": n("CLIPTextEncode", "Prompt", clip=["3", 0], text=["10", 0]),
        "12": n("ConditioningZeroOut", "Negative (zero)", conditioning=["11", 0]),
        "13": n("VAEEncode", "Encode canvas", pixels=["6", 0], vae=["4", 0]),
        "14": n("PrimitiveInt", "BATCH", value=4),
        "15": n("RepeatLatentBatch", "Repeat for batch", samples=["13", 0], amount=["14", 0]),
        "16": n("SetLatentNoiseMask", "Inpaint inside shape", samples=["15", 0], mask=["6", 1]),
        "17": n("PrimitiveInt", "SEED", value=1),
        "18": n("KSampler", "KSampler", model=["2", 0], positive=["11", 0], negative=["12", 0], latent_image=["16", 0],
                seed=["17", 0], steps=8, cfg=1, sampler_name="euler", scheduler="simple", denoise=0.8),
        "19": n("VAEDecode", "Decode", samples=["18", 0], vae=["4", 0]),
        "20": n("SpriteFinish", "Sprite Finish", images=["19", 0], shape=["5", 0], shape_mask=["5", 1],
                colors=8, leak_threshold=0.1),
        "21": n("SaveImage", "SPRITE", images=["20", 0], filename_prefix="sprite_from_shape/sprite"),
        "22": n("SaveImage", "PREVIEW", images=["20", 1], filename_prefix="sprite_from_shape/preview"),
    }


def _is_widget(spec):
    return isinstance(spec[0], list) or spec[0] in ("INT", "FLOAT", "STRING", "BOOLEAN", "COMBO")


def to_ui(api, object_info):
    """litegraph UI JSON for the same graph: every input in object_info order (linked widgets keep their slot in
    widgets_values, as the frontend saves them), nodes laid out by depth on a 300 px grid, plus a MarkdownNote."""
    depth = {}
    def d(i):
        if i not in depth:
            ups = [v[0] for v in api[i]["inputs"].values() if isinstance(v, list)]
            depth[i] = 1 + max((d(u) for u in ups), default=-1)
        return depth[i]
    rows = {}
    nodes, links, out_links = [], [], {}
    for i in api:
        out_links[i] = {}
    for i, node in api.items():
        info = object_info[node["class_type"]]
        specs = {**info["input"].get("required", {}), **info["input"].get("optional", {})}
        order = info["input_order"].get("required", []) + info["input_order"].get("optional", [])
        inputs, widgets = [], []
        for name in order:
            spec, val = specs[name], node["inputs"].get(name)
            entry = {"name": name, "localized_name": name, "type": "COMBO" if isinstance(spec[0], list) else spec[0], "link": None}
            if isinstance(val, list):
                link_id = len(links) + 1
                src, slot = val
                links.append([link_id, int(src), slot, int(i), len(inputs), object_info[api[src]["class_type"]]["output"][slot]])
                out_links[src].setdefault(slot, []).append(link_id)
                entry["link"] = link_id
            if _is_widget(spec):
                entry["widget"] = {"name": name}
                opts = spec[1] if len(spec) > 1 else {}
                widgets.append(None if isinstance(val, list) else val)
                if widgets[-1] is None:  # linked: keep the slot with the default
                    widgets[-1] = opts.get("default", spec[0][0] if isinstance(spec[0], list) else "")
                if opts.get("control_after_generate"):
                    widgets.append("fixed")
                if opts.get("image_upload"):
                    widgets.append("image")
            inputs.append(entry)
        col = d(i)
        row = rows[col] = rows.get(col, -1) + 1
        nodes.append({"id": int(i), "type": node["class_type"], "title": node["_meta"]["title"],
                      "pos": [col * 300, row * 300], "size": [280, 200], "flags": {}, "order": int(i) - 1, "mode": 0,
                      "inputs": inputs, "outputs": [], "properties": {"Node name for S&R": node["class_type"]},
                      "widgets_values": widgets})
    for n in nodes:
        info = object_info[n["type"]]
        n["outputs"] = [{"name": nm, "localized_name": nm, "type": t, "links": out_links[str(n["id"])].get(k, [])}
                        for k, (t, nm) in enumerate(zip(info["output"], info["output_name"]))]
    note_id = max(int(i) for i in api) + 1
    nodes.append({"id": note_id, "type": "MarkdownNote", "title": "How to use", "pos": [0, -560], "size": [900, 520],
                  "flags": {}, "order": note_id - 1, "mode": 0, "inputs": [], "outputs": [], "properties": {},
                  "widgets_values": [NOTE]})
    return {"id": str(uuid.uuid4()), "revision": 0, "last_node_id": note_id, "last_link_id": len(links),
            "nodes": nodes, "links": links, "groups": [], "config": {}, "extra": {}, "version": 0.4}


def png_rgba(w, h, alpha):
    """Black RGBA PNG; alpha(x, y) -> bool decides opaque pixels."""
    raw = b"".join(b"\0" + b"".join(b"\0\0\0" + (b"\xff" if alpha(x, y) else b"\0") for x in range(w)) for y in range(h))
    chunk = lambda t, data: struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def dozer_shape():
    """22x30 Dozer hull: outline (-11,15),(11,15),(8,-15),(-8,-15), y down = +15 at the bottom."""
    return png_rgba(22, 30, lambda x, y: abs(x + 0.5 - 11) <= 8 + 3 * (y + 0.5) / 30)


def upload_image(server, name, data):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{server}/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    return json.load(urllib.request.urlopen(req))["name"]


def save_userdata(server, path, obj):
    url = f"{server}/userdata/{urllib.parse.quote(path, safe='')}?overwrite=true"
    req = urllib.request.Request(url, json.dumps(obj, indent=1).encode(), {"Content-Type": "application/json"}, method="POST")
    return urllib.request.urlopen(req).status


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--server", default="http://localhost:8188")
    server = ap.parse_args().server.rstrip("/")
    object_info = json.load(urllib.request.urlopen(f"{server}/object_info"))
    upload_image(server, EXAMPLE_SHAPE, dozer_shape())
    api = graph()
    for name, obj in (("sprite_from_shape.json", to_ui(api, object_info)), ("sprite_from_shape_api.json", api)):
        print(save_userdata(server, f"{WORKFLOW_DIR}/{name}", obj), f"{WORKFLOW_DIR}/{name}")


if __name__ == "__main__":
    main()
