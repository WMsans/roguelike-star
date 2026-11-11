# Run: python3 tools/sprites/test_build_workflow.py
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_workflow import graph, to_ui

FIXTURE_OBJECT_INFO = os.path.join(HERE, "object_info_fixture.json")


def test_contract_titles():
    titles = {n["_meta"]["title"]: n["class_type"] for n in graph().values()}
    assert titles["SHAPE"] == "LoadImage" and titles["SUBJECT"] == "PrimitiveStringMultiline"
    assert titles["SEED"] == titles["BATCH"] == "PrimitiveInt"
    assert titles["SPRITE"] == titles["PREVIEW"] == "SaveImage"


def test_links_resolve():
    g = graph()
    for n in g.values():
        for v in n["inputs"].values():
            if isinstance(v, list):
                assert v[0] in g


def test_ui_matches_api():
    ui = to_ui(graph(), json.load(open(FIXTURE_OBJECT_INFO)))
    assert len([n for n in ui["nodes"] if n["type"] != "MarkdownNote"]) == len(graph())
    assert len(ui["links"]) == sum(isinstance(v, list) for n in graph().values() for v in n["inputs"].values())


def test_ui_widget_values_follow_input_order():
    ui = to_ui(graph(), json.load(open(FIXTURE_OBJECT_INFO)))
    ks = next(n for n in ui["nodes"] if n["type"] == "KSampler")
    # seed is linked from SEED but keeps its slot (+ control_after_generate), then steps, cfg, sampler, scheduler, denoise
    assert ks["widgets_values"][1:] == ["fixed", 8, 1, "euler", "simple", 0.8], ks["widgets_values"]
    load = next(n for n in ui["nodes"] if n["title"] == "SHAPE")
    assert load["widgets_values"][1] == "image"


if __name__ == "__main__":
    for k, t in sorted(globals().items()):
        if k.startswith("test_"):
            t()
            print("ok", k)
    print("ALL PASS")
