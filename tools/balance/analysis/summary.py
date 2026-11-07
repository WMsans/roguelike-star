#!/usr/bin/env python3
"""One line per matchup from a run.sh --out file: W/L/D, fight length, player DPS, energy, and per part
firings/hits/damage/damage-per-energy. Usage: summary.py result.json"""
import json, sys
d = json.load(open(sys.argv[1]))
for a in d["aggregates"]:
    p, e = a["player"], a["enemy"]
    parts = ", ".join(f"{k.split('@')[0]}:{v['firings']:.0f}f/{v['hits']:.0f}h/{v['damage_dealt']:.0f}d/{v['damage_per_energy']:.1f}dpe"
                      for k, v in p["parts"].items() if not k.startswith("wheel"))
    print(f"{a['name']:28} W{a['wins']} L{a['losses']} D{a['draws']} t={a['mean_fight_seconds']:5.1f} dps={p['dps_dealt']:5.1f} "
          f"hp_left={p['hp_left']:6.0f} en={p['energy_spent']:5.0f} starve={p['energy_starved_seconds']:4.1f} | {parts} | "
          f"gain={p['energy_gained']:.0f} lit={p['caught_fire']:.1f} enemy_frozen={e['frozen']:.1f} enemy_dps={e['dps_dealt']:.1f}")
