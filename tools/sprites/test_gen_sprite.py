# Run: python3 tools/sprites/test_gen_sprite.py
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_sprite import fill
from build_workflow import dozer_shape

GEN = os.path.join(HERE, "gen_sprite.py")


def contract_api():
    def n(cls, title, **inputs):
        return {"class_type": cls, "inputs": inputs, "_meta": {"title": title}}
    return {"1": n("LoadImage", "SHAPE", image="x"), "2": n("PrimitiveStringMultiline", "SUBJECT", value="y"),
            "3": n("PrimitiveInt", "SEED", value=1), "4": n("PrimitiveInt", "BATCH", value=4),
            "5": n("SaveImage", "SPRITE", filename_prefix="a"), "6": n("SaveImage", "PREVIEW", filename_prefix="b")}


def by_title(api, title):
    return next(n for n in api.values() if n["_meta"]["title"] == title)


def test_fill_sets_contract_fields():
    api = contract_api()
    out = fill(api, "up.png", "a wheel", 5, 3, "sprite_from_shape/wheel")
    assert by_title(out, "SHAPE")["inputs"]["image"] == "up.png"
    assert by_title(out, "SUBJECT")["inputs"]["value"] == "a wheel"
    assert by_title(out, "SEED")["inputs"]["value"] == 5 and by_title(out, "BATCH")["inputs"]["value"] == 3
    assert by_title(out, "SPRITE")["inputs"]["filename_prefix"] == "sprite_from_shape/wheel"
    assert by_title(out, "PREVIEW")["inputs"]["filename_prefix"] == "sprite_from_shape/wheel_x8"
    assert by_title(api, "SEED")["inputs"].get("value") != 5  # input not mutated


def test_fill_missing_title_names_it():
    api = contract_api()
    del api["4"]
    try:
        fill(api, "up.png", "a wheel", 5, 3, "p")
    except KeyError as e:
        assert "BATCH" in str(e), e
    else:
        raise AssertionError("no KeyError")


def test_dead_server_exits_nonzero():
    with tempfile.TemporaryDirectory() as tmp:
        shape, out = os.path.join(tmp, "dozer.png"), os.path.join(tmp, "out")
        open(shape, "wb").write(dozer_shape())
        r = subprocess.run([sys.executable, GEN, "--shape", shape, "--subject", "x", "--out", out,
                            "--server", "http://127.0.0.1:9"], capture_output=True, text=True, timeout=30)
        assert r.returncode == 1 and r.stderr.strip(), (r.returncode, r.stderr)
        assert "Traceback" not in r.stderr and not (os.path.isdir(out) and os.listdir(out))


if __name__ == "__main__":
    for k, t in sorted(globals().items()):
        if k.startswith("test_"):
            t()
            print("ok", k)
    print("ALL PASS")
