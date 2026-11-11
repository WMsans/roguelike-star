"""Shape PNG + subject -> pixel sprites, via the sprite_from_shape workflow on the ComfyUI server.
Python stdlib only. See tools/sprites/README.md.
  python3 tools/sprites/gen_sprite.py --shape hull.png --subject "..." [--seeds 4] [--seed 1] [--out ./sprites_out]"""
import argparse, copy, json, os, sys, time, urllib.error, urllib.parse, urllib.request, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_workflow import WORKFLOW_DIR, upload_image
from outline import outline_image

TIMEOUT = 600


def fill(api, shape_name, subject, seed, batch, prefix):
    """A copy of the API graph with the titled contract inputs set."""
    api = copy.deepcopy(api)
    by_title = {n["_meta"]["title"]: n["inputs"] for n in api.values()}
    missing = [t for t in ("SHAPE", "SUBJECT", "SEED", "BATCH", "SPRITE", "PREVIEW") if t not in by_title]
    if missing:
        raise KeyError(f"workflow has no node titled {', '.join(missing)}")
    by_title["SHAPE"]["image"] = shape_name
    by_title["SUBJECT"]["value"] = subject
    by_title["SEED"]["value"] = seed
    by_title["BATCH"]["value"] = batch
    by_title["SPRITE"]["filename_prefix"] = prefix
    by_title["PREVIEW"]["filename_prefix"] = f"{prefix}_x8"
    return api


def run(a):
    server = a.server.rstrip("/")
    get = lambda path: json.load(urllib.request.urlopen(server + path, timeout=30))
    stem = os.path.splitext(os.path.basename(a.shape))[0]
    api = get("/userdata/" + urllib.parse.quote(f"{WORKFLOW_DIR}/sprite_from_shape_api.json", safe=""))
    shape_name = upload_image(server, f"sprite_shape_{stem}.png", open(a.shape, "rb").read())
    api = fill(api, shape_name, a.subject, a.seed, a.seeds, f"sprite_from_shape/{stem}_s{a.seed}")
    titles = {n["_meta"]["title"]: i for i, n in api.items()}
    req = urllib.request.Request(server + "/prompt", json.dumps({"prompt": api}).encode(), {"Content-Type": "application/json"})
    try:
        pid = json.load(urllib.request.urlopen(req, timeout=30))["prompt_id"]
    except urllib.error.HTTPError as e:  # graph rejected: ComfyUI explains why in the body
        raise SystemExit(f"error: ComfyUI rejected the job: {e.read().decode(errors='replace')[:500]}")
    end = time.time() + TIMEOUT
    while True:
        h = get(f"/history/{pid}").get(pid)
        if h and (h["status"].get("completed") or h["status"].get("status_str") == "error"):
            break
        if time.time() > end:
            raise SystemExit(f"error: job {pid} not done after {TIMEOUT} s")
        time.sleep(1)
    if h["status"].get("status_str") == "error":
        msgs = [m[1] for m in h["status"].get("messages", []) if m[0] == "execution_error"]
        raise SystemExit("error: " + (msgs[0].get("exception_message", "").strip() if msgs else "job failed"))
    os.makedirs(a.out, exist_ok=True)
    for title, suffix in (("SPRITE", ""), ("PREVIEW", "_x8")):
        for i, im in enumerate(h["outputs"][titles[title]]["images"]):
            path = os.path.join(a.out, f"{stem}_s{a.seed}_{i}{suffix}.png")
            data = urllib.request.urlopen(f"{server}/view?" + urllib.parse.urlencode(im), timeout=60).read()
            # The model's own outline is uneven, so the sprite gets a deterministic one from its silhouette.
            if not suffix:
                try:
                    data = outline_image(data)
                except (ValueError, zlib.error) as e:
                    raise SystemExit(f"error: sprite {path}: {e}")
            with open(path, "wb") as f:
                f.write(data)
            print(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--shape", required=True, help="native-size silhouette PNG: opaque (or dark, without alpha) = solid")
    ap.add_argument("--subject", required=True, help="what it is: colours, materials, where small parts go; +x is forward")
    ap.add_argument("--seeds", type=int, default=4, help="how many variants (one batch)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out", default="./sprites_out")
    ap.add_argument("--server", default="http://localhost:8188")
    a = ap.parse_args()
    try:
        run(a)  # SystemExit("error: ...") from run prints to stderr and exits 1
    except urllib.error.HTTPError as e:
        sys.exit(f"error: ComfyUI answered {e.code} for {e.url}")
    except urllib.error.URLError as e:
        sys.exit(f"error: cannot reach ComfyUI at {a.server}: {e.reason}")
    except (OSError, KeyError) as e:
        sys.exit(f"error: {e}")


if __name__ == "__main__":
    main()
