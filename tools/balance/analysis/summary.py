#!/usr/bin/env python3
"""One line per matchup from a run.sh --out file: W/L/D, fight length, player DPS, energy, and per part
firings/hits/damage/damage-per-energy. Usage: summary.py result.json
summary.py --press-gap result.json: the spec §4 button check instead. Per build, the player's win rate
under `ai` minus under `mash` (scenario `X` against `X-mash`; in a matrix, `name/ixj` grouped by the
player row i). Flags every build under 15 points and exits 1 if any is.
summary.py --wheel-gap result.json: per build, the win rate of `vs-cook-X` and `vs-cook-X-nowheels` and the gap."""
import json, sys
from collections import defaultdict

GAP = 0.15


def press_gap(d):
    tally = defaultdict(lambda: [0, 0])  # (build, policy) -> [wins, fights]
    for a in d["aggregates"]:
        name, _, pair = a["name"].partition("/")
        policy = "mash" if name.endswith("-mash") else "ai" if not name.endswith("-never") else None
        if policy is None:
            continue
        build = name.removesuffix("-mash") + (f"/{pair.split('x')[0]}" if pair else "")
        t = tally[build, policy]
        t[0] += a["wins"]; t[1] += a["wins"] + a["losses"] + a["draws"]
    short = 0
    for build in sorted({b for b, _ in tally}):
        if (build, "mash") not in tally:
            continue
        (aw, af), (mw, mf) = tally[build, "ai"], tally[build, "mash"]
        gap = aw / af - mw / mf
        short += gap < GAP - 1e-9
        print(f"{build:28} ai {aw / af:.2f} mash {mw / mf:.2f} gap {gap:+.2f}{'  < 0.15' if gap < GAP - 1e-9 else ''}")
    return 1 if short else 0


def wheel_gap(d):
    wr = {a["name"]: a["wins"] / (a["wins"] + a["losses"] + a["draws"]) for a in d["aggregates"]}
    for name in sorted(wr):
        if name.startswith("vs-cook-") and name + "-nowheels" in wr:
            nw = wr[name + "-nowheels"]
            print(f"{name.removeprefix('vs-cook-')} wheels={wr[name]:.2f} nowheels={nw:.2f} gap={wr[name] - nw:+.2f}")
    return 0


if len(sys.argv) < 2 or (sys.argv[1] in ("--press-gap", "--wheel-gap") and len(sys.argv) < 3):
    sys.exit(__doc__)
if sys.argv[1] == "--wheel-gap":
    sys.exit(wheel_gap(json.load(open(sys.argv[2]))))
if sys.argv[1] == "--press-gap":
    sys.exit(press_gap(json.load(open(sys.argv[2]))))
d = json.load(open(sys.argv[1]))
for a in d["aggregates"]:
    p, e = a["player"], a["enemy"]
    parts = ", ".join(f"{k.split('@')[0]}:{v['firings']:.0f}f/{v['hits']:.0f}h/{v['damage_dealt']:.0f}d/{v['damage_per_energy']:.1f}dpe"
                      for k, v in p["parts"].items() if not k.startswith("wheel"))
    print(f"{a['name']:28} W{a['wins']} L{a['losses']} D{a['draws']} t={a['mean_fight_seconds']:5.1f} dps={p['dps_dealt']:5.1f} "
          f"hp_left={p['hp_left']:6.0f} en={p['energy_spent']:5.0f} starve={p['energy_starved_seconds']:4.1f} | {parts} | "
          f"gain={p['energy_gained']:.0f} lit={p['caught_fire']:.1f} enemy_frozen={e['frozen']:.1f} enemy_dps={e['dps_dealt']:.1f} "
          f"haz={p['hazard_damage']:.0f} hazkill={(p['killed_by_hazard'] + e['killed_by_hazard']) * (a['fights'] - a['aborted']):.0f}")
