# Balance runner

## What it's for

Runs seeded, headless auto-battles from a JSON scenario and reports win rates, time to kill and
per-part output (damage, damage per energy, time spent waiting for energy) as text and JSON. Run
it after changing a part, a body or a balance number, or whenever someone asks whether something
is balanced: it turns "feels strong" into numbers you can compare before and after.

## Run it

From the repo root (or anywhere; paths are resolved from your current directory):

```sh
tools/balance/run.sh path/to/scenario.json [--out result.json]   # one scenario file
tools/balance/run.sh --suite smoke [--out result.json]           # a built-in suite (tools/balance/suites/<name>.json)
tools/balance/run.sh --list                                      # part ids, body ids, enemy layouts, suites
```

Exit codes (the highest that applies wins):

| code | meaning |
|---|---|
| 0 | every fight ran, every `expect` passed |
| 1 | usage, JSON or scenario error, an unwritable `--out`, or wrong frame pacing; no fight ran |
| 2 | an `expect` range failed |
| 3 | a fight aborted (its seed is printed and listed in `aborted_seeds`) |

`run.sh` exists because fights only reproduce under `godot --headless --fixed-fps 60`: without
`--fixed-fps` headless frames run uncapped while physics stays at 60 Hz, and the same seed plays a
different fight. `run.gd` checks this and refuses (exit 1) if the flag is missing. `--out` is the
only place a run writes a file.

## Scenario schema

Shape (`SIDE` is a placeholder, defined below; the regression example further down is a complete
file you can copy):

```
{
  "name": "wedge-vs-dozer",
  "player": SIDE or [SIDE, ...],
  "enemy":  SIDE or [SIDE, ...],
  "seeds":  {"from": 1, "count": 10},
  "drive":  {"player": "ai", "enemy": "ai"},
  "expect": {"win_rate": [0.4, 0.6], "player.dps_dealt": [10, 20]}
}
```

A `SIDE` is one of:

```json
{"layout": "res://game/data/enemies/dozer_cook.tres", "hp": 100000}
{"body_id": "cutter", "hp": 800,
 "parts": [{"slot": [0], "part": "wheel"},
           {"slot": [3], "part": "cutter_rocket", "flipped": false},
           {"slot": [3, 0], "part": "strut"}]}
```

| field | required | default | notes |
|---|---|---|---|
| `name` | yes | | names the result; a matrix pairing is `<name>/<i>x<j>` |
| `player`, `enemy` | yes | | a side, or a list of sides: a list makes a matrix, every player × enemy pair runs |
| `seeds.from`, `seeds.count` | no | `1`, `10` | fights use seeds `from .. from+count-1` |
| `drive.player`, `drive.enemy` | no | `"ai"`, `"ai"` | `ai` (the enemy AI's approach-and-hold rule), `hold` (never drives), `charge` (always drives at the other chariot) |
| `expect` | no | `{}` | dotted metric path → inclusive `[min, max]`; see below |
| side `layout` | one of | | a `res://` `ChChariotLayout` (`--list` shows them) |
| side `body_id` | one of | | a body id (`--list`), with `parts` |
| side `parts` | with `body_id` | | `slot` is a slot path, `part` a part id, `flipped` defaults to `false` |
| side `hp` | no | the body's | overrides HP for this side only |

Slot paths: `[i]` is body slot `i`; `[i, j]` is extension slot `j` of the part in body slot `i`.
Any part can go in any slot. Body slots are listed in `game/data/bodies/<id>.tres` (`slots`), as
body-local `(x, y)` cells from the hull's centre: `+x` is forward (toward the enemy), `-y` is up.
On every body the first two slots are the bottom wheel mounts. Today's bodies:

| body | hp | slots `[0]`, `[1]`, ... |
|---|---|---|
| `cutter` | 500 | (-4, 5) (6, 5) · (-4, -3) rear-top · (6, -3) front-top |
| `dozer` | 500 | (-9, 9) (9, 9) · (-12, -3) rear · (12, -3) front · (-6, -9) rear-top · (6, -9) front-top |
| `corsair` | 600 | (-8, 5) (10, 5) · then five top slots from rear (-18, -5) to front (20, -5) |

(Check the `.tres` for current numbers; this table is a guide.) A `layout` side uses the HP of its
layout's body unless you give `hp`.

Every mistake is reported before any fight, as `<file>: <field path>: <problem>`, and unknown ids
list the valid ones. Unknown fields are errors too, so a typo never silently falls back to a
default. `body_type` / `body_seed` are not accepted yet (they arrive with the body-types plan).

## Reading results

Stdout shows one progress line per matchup (`[3/12] name: 7W 3L 0D`), then a summary block per
matchup, then **a final line** `RESULT {...}` with one JSON object:

```json
{"ok": true, "failures": [], "scenarios": [{"name": "...", "win_rate": 0.7, "mean_fight_seconds": 21.3, "aborted": 0}]}
```

`ok` is false when an `expect` failed or a fight aborted. Trust the exit code and `RESULT`:
Godot's own warnings and `ERROR: ... leaked` / `resources still in use` lines on stderr at exit
are engine teardown noise, not failures.

`--out` writes the full data:
`{"aggregates": [AGG, ...], "fights": {name: [FIGHT, ...]}, "failures": [...]}`, where each
`FIGHT` is `{"seed", "result": "win"|"loss"|"draw"|"aborted", "fight_seconds", "sides": [PLAYER, ENEMY]}`:
`sides[0]` is the player and `sides[1]` the enemy, each with the per-side metrics below for that
one fight. The stdout table abbreviates some names: `starved_s` = `energy_starved_seconds`,
`dmg/energy` = `damage_per_energy`, `waiting_s` = `seconds_waiting`. Part breakage
(`broke_at_seconds`, `broke_fraction`) is only in `--out`.

Per matchup (`AGG`): `fights`, `wins`, `losses`, `draws`, `aborted`, `win_rate`,
`mean_fight_seconds`, `aborted_seeds`, `draw_seeds`, and `player` / `enemy` side means.

- `win_rate` = player wins / non-aborted fights. A draw (nobody dead after 60 s) counts as a fight.
- `mean_fight_seconds` averages non-aborted fights; a draw counts as 60.
- Side and part values are means over the non-aborted fights.

Per side:

| metric | meaning |
|---|---|
| `hp_left` | this chariot's HP at the end |
| `damage_dealt` | the other chariot's HP lost (its starting HP minus HP left), burn included |
| `unattributed_damage` | `damage_dealt` minus what this side's parts claimed. Mostly burn: any HP the other chariot lost that no part of this side hit for, so it also holds burn on a chariot that set itself alight, and can be non-zero for a build with no fire parts |
| `dps_dealt` | `damage_dealt / fight_seconds` |
| `energy_spent` | energy paid, driving plus every part firing |
| `energy_starved_seconds` | time with at least one part waiting in the energy queue |
| `flipped_seconds` | time with the hull rotated past 90° |
| `rams` | times the two hulls started touching (same number for both sides) |
| `energy_gained` | energy this chariot's parts added to its own pool (Ember Battery), after the cap: a gain into a full pool counts 0 |
| `caught_fire` | times one of this chariot's parts caught fire |
| `frozen` | times one of this chariot's parts froze |
| `parts` | per part, keyed `<part_id>@<slot path>`, e.g. `cutter_rocket@[3]` |

Per part:

| metric | meaning |
|---|---|
| `firings` | times the part was paid and went off |
| `hits` | hits it landed on the other chariot (hits on its own chariot are not counted) |
| `misses` | `max(0, firings - hits)`. Approximate: one firing can hit several times (pulses, a growing ring) or hit later |
| `damage_dealt` | HP damage from its hits on the other chariot |
| `energy_spent` | `firings × energy_cost` |
| `damage_per_energy` | `damage_dealt / energy_spent`, `0` if it spent nothing |
| `seconds_waiting` | time it sat in the energy queue |
| `broke_at_seconds` | mean time it broke, over the fights it broke in; `-1` if it never broke |
| `broke_fraction` | share of fights it broke in (aggregates only) |

## Suites

- `smoke`: the Cutter with wheels and a `cutter_rocket` against `dozer_cook.tres`, seeds 1–3, and
  it fails if any fight aborts. A quick "does the runner work" check (~2 s).
- `standalone`: each damaging part alone at the Cutter's `[3]`, AI-driven, against a dummy Dozer
  (two wheels, 100000 HP, drive `hold`), seeds 1–5. The dummy can't die or fight back, so every
  fight runs the full 60 s and each part's damage per energy is measured over the same window.
  No `expect`: it measures (~1 minute).
- Coming with later plans: `bodies` (every body type against every other), `payoffs` (each payoff
  alone and in its target scenario) and `builds` (each build against a reference gauntlet).

## Writing a regression check

Add `expect` to a scenario; the run exits 2 and lists the failure in `RESULT` when a value leaves
its range. Paths are dotted into the aggregate:

```json
{
  "name": "rocket-stays-efficient",
  "player": {"body_id": "cutter", "parts": [{"slot": [0], "part": "wheel"}, {"slot": [1], "part": "wheel"},
                                            {"slot": [3], "part": "cutter_rocket"}]},
  "enemy": {"layout": "res://game/data/enemies/dozer_cook.tres"},
  "seeds": {"from": 1, "count": 10},
  "expect": {
    "win_rate": [0.6, 1.0],
    "aborted": [0, 0],
    "player.parts.cutter_rocket@[3].damage_per_energy": [10, 20]
  }
}
```

A path that names no metric fails with `expect <path>: no such metric`, so a misspelt check can't
pass by checking nothing.

## Gotchas

- Speed: a 60-second fight takes about 1.5 s of wall time; budget a minute per 40 full-length fights.
- Parts are referenced by slot path, not by name: the key `cutter_rocket@[3]` changes if you move
  the part.
- The battle mirrors the enemy layout so it faces the player. Write every layout facing right
  (+x forward), the way the player's is written.
- Fights are deterministic only for the same scenario, seeds and code; numbers change when a part,
  body or the physics changes, which is the point.
- Parts that start on a cooldown under one tick (1/60 s) would have their first-tick firing missed
  by the stats; no current part does.
