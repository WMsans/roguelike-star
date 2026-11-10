#!/usr/bin/env python3
"""One line per matchup from a run.sh --out file: W/L/D, fight length, player DPS, energy, and per part
firings/hits/damage/damage-per-energy. Usage: summary.py result.json
summary.py --press-gap result.json: the spec §4 button check instead. Per build, the player's win rate
under `ai` minus under `mash` (scenario `X` against `X-mash`; in a matrix, `name/ixj` grouped by the
player row i). Flags every build under 15 points and exits 1 if any is."""
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


if len(sys.argv) < 2 or (sys.argv[1] == "--press-gap" and len(sys.argv) < 3):
    sys.exit(__doc__)
if sys.argv[1] == "--press-gap":
    sys.exit(press_gap(json.load(open(sys.argv[2]))))
d = json.load(open(sys.argv[1]))
for a in d["aggregates"]:
    p, e = a["player"], a["enemy"]
    parts = ", ".join(f"{k.split('@')[0]}:{v['firings']:.0f}f/{v['hits']:.0f}h/{v['damage_dealt']:.0f}d/{v['damage_per_energy']:.1f}dpe"
                      for k, v in p["parts"].items() if not k.startswith("wheel"))
    print(f"{a['name']:28} W{a['wins']} L{a['losses']} D{a['draws']} t={a['mean_fight_seconds']:5.1f} dps={p['dps_dealt']:5.1f} "
          f"hp_left={p['hp_left']:6.0f} en={p['energy_spent']:5.0f} starve={p['energy_starved_seconds']:4.1f} | {parts} | "
          f"gain={p['energy_gained']:.0f} lit={p['caught_fire']:.1f} enemy_frozen={e['frozen']:.1f} enemy_dps={e['dps_dealt']:.1f}")
