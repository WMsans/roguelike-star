#!/usr/bin/env python3
"""Round-robin table from a demo-matrix run. Score = share of a build's fights won (draw = half), counting
its games as player and as enemy, mirror match excluded. Usage: matrix.py result.json [name ...]
Names default to the order in tools/balance/suites/demo-matrix.json."""
import json, sys
d = json.load(open(sys.argv[1]))
names = sys.argv[2:] or ["sparks", "freeze", "selfburn", "artillery", "hotmelee"]
n = len(names); M = {}
for a in d["aggregates"]:
    i, j = map(int, a["name"].split("/")[1].split("x")); M[i, j] = (a["wins"], a["losses"], a["draws"], a["mean_fight_seconds"])
print(f"{'player/enemy':12}" + "".join(f"{x:>14}" for x in names) + "   score")
for i in range(n):
    w = l = dr = 0
    for j in range(n):
        if i == j: continue
        a, b, c, _ = M[i, j]; w += a; l += b; dr += c
        a, b, c, _ = M[j, i]; w += b; l += a; dr += c
    row = "".join(f"{M[i,j][0]}-{M[i,j][1]}-{M[i,j][2]} {M[i,j][3]:3.0f}s".rjust(14) for j in range(n))
    print(f"{names[i]:12}{row}   {(w + 0.5 * dr) / (w + l + dr):.2f}")
