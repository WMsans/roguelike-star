# Balance runner

## What it's for

Runs seeded, headless auto-battles from a JSON scenario and reports win rates, time to kill and
per-part output (damage, damage per energy, time spent ready but unfired) as text and JSON. Run
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
  "press":  {"player": "ai", "enemy": "ai"},
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
| `press.player`, `press.enemy` | no | `"ai"`, `"ai"` | when the side presses its button (a press fires a volley of ready parts): `ai` (the enemy AI's rule), `mash` (every tick, so each part fires the moment it is ready and affordable), `never` (parts sit ready and unfired) |
| `expect` | no | `{}` | dotted metric path → inclusive `[min, max]`; see below |
| side `layout` | one of | | a `res://` `ChChariotLayout` (`--list` shows them) |
| side `body_id` | one of | | a body id (`--list`), with `parts` |
| side `parts` | with `body_id` | | `slot` is a slot path, `part` a part id, `flipped` defaults to `false` |
| side `hp` | no | the body's | overrides HP for this side only |
| side `plain_hull` | no | `false` | with `body_id` only: the body's outline is dropped, so the hull is its plain `size` box with every other field kept (the body joins as `<id>_box`). The `bodies-box` control |

Slot paths: `[i]` is body slot `i`; `[i, j]` is extension slot `j` of the part in body slot `i`.
Any part can go in any slot. Body slots are listed in `game/data/bodies/<id>.tres` (`slots`), as
body-local `(x, y)` cells from the hull's centre: `+x` is forward (toward the enemy), `-y` is up.
On every body the first two slots are the bottom wheel mounts. Today's bodies:

| body | hp | slots `[0]`, `[1]`, ... |
|---|---|---|
| `cutter` | 450 | (-10, 4.5) (9, 4.5) · (-6, -3) rear-top · (6, -3) front, on the nose slope |
| `dozer` | 700 | (-9, 15) (9, 15) · (-9, -3) rear · (9, -3) front · (-5, -15) rear-top · (5, -15) front-top |
| `corsair` | 900 | (-21, 5) (21, 5) · then five top slots from rear (-20, -5) to front (22, -5) |

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
`dmg/energy` = `damage_per_energy`, `ready_s` = `seconds_ready_unfired`. Part breakage
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
| `energy_starved_seconds` | time with a ready part whose energy cost exceeds the pool (a press could not pay for it) |
| `flipped_seconds` | time with the hull rotated past 90° |
| `rams` | times the two hulls started touching (same number for both sides) |
| `energy_gained` | energy this chariot's parts added to its own pool (Ember Battery), after the cap: a gain into a full pool counts 0 |
| `caught_fire` | times one of this chariot's parts caught fire |
| `frozen` | times one of this chariot's parts froze |
| `parts` | per part, keyed `<part_id>@<slot path>`, e.g. `cutter_rocket@[3]` |

Per part:

| metric | meaning |
|---|---|
| `firings` | times a press paid for the part and it went off |
| `hits` | hits it landed on the other chariot (hits on its own chariot are not counted) |
| `misses` | `max(0, firings - hits)`. Approximate: one firing can hit several times (pulses, a growing ring) or hit later |
| `damage_dealt` | HP damage from its hits on the other chariot |
| `energy_spent` | `firings × energy_cost` |
| `damage_per_energy` | `damage_dealt / energy_spent`, `0` if it spent nothing |
| `seconds_ready_unfired` | time it was ready (cooled down, intact, not frozen, charges left) and had not fired; large under `press: never`, or when the policy presses late |
| `broke_at_seconds` | mean time it broke, over the fights it broke in; `-1` if it never broke |
| `broke_fraction` | share of fights it broke in (aggregates only) |

## Suites

- `smoke`: the Cutter with wheels and a `cutter_rocket` against `dozer_cook.tres`, seeds 1–3, and
  it fails if any fight aborts. A quick "does the runner work" check (~2 s).
- `standalone`: each damaging part alone at the Cutter's `[3]`, AI-driven, against a dummy Corsair
  (two wheels, 100000 HP, drive `hold`), seeds 1–5. Both sides use `plain_hull`: with the shaped
  hulls the Cutter climbed the dummy and spent 11–46 s of each fight flipped, which measured the
  flip rather than the part. The dummy can't die or fight back, so every fight runs the full 60 s
  and each part's damage per energy is measured over the same window. No `expect`: it measures
  (~1 minute).
- `bodies`: every body against every body (9 pairs, seeds 1–8), `ai` driving and pressing. Each
  side carries two wheels, a Rocket and a Chainsaw on the body's two highest front-facing non-wheel
  slots, Chainsaw in front (Cutter `[2]`/`[3]`, Dozer `[5]`/`[3]`, Corsair `[5]`/`[6]`; the Dozer's
  front-facing pair is its front-top `[5]` and front `[3]`, its rear-top `[4]` faces away). One
  scenario per pair, named `bodies/<i>x<j>` (0 cutter, 1 dozer, 2 corsair) so
  `analysis/matrix.py out.json cutter dozer corsair` reads it; `expect` pins each pair's win rate
  to within one fight of the tuned result, and the Dozer's `flipped_seconds` against the Cutter (~2 min).
- `bodies-box`: the same matrix with `"plain_hull": true` on both sides, the control that shows
  what the outlines add. No `expect`: compare it with `bodies` (~2 min).
- Coming with later plans: `payoffs` (each payoff alone and in its target scenario) and `builds`
  (each build against a reference gauntlet).

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
- Melee reach (`ChBehaviour._nearest_enemy_body`) tests the target's unrotated `size` box, not its
  outline, so an outline changes who a Chainsaw hits only through the physics (lifts, flips,
  tilts). A Rocket is a real projectile and does meet the outline.
- Parts that start on a cooldown under one tick (1/60 s) would have their first-tick firing missed
  by the stats; no current part does.

## Body tuning log

Task 8 of the button-and-bodies plan. Each try ran `bodies` and `bodies-box` (8 seeds per pair).
Score = a body's share of its non-mirror fights, draw = half (`matrix.py`); MAD = mean distance
of the three pair scores from 0.5. Criteria: no body above 0.65; each body wins one pair ≥ 0.60
and loses one ≥ 0.60; the Dozer flipped in most Cutter–Dozer fights; `bodies` MAD > `bodies-box`.
Tries 1–8 ran before the mass fix (below): a `mass` in a body def did nothing then.

| # | change from the previous try | cutter / dozer / corsair | MAD vs box | Dozer flipped vs Cutter | verdict |
|---|---|---|---|---|---|
| 0 | Task 7 bodies, `KITE_BACKOFF` 8 | .59 / .59 / .31 | .125 vs .073 | 16/16 | the Tower tipped itself (51 s flipped in the mirror, 0 rams): the kiter reversed at full speed |
| 1 | `KITE_BACKOFF` 20; Tower top ±5 | .59 / .52 / .39 | .073 vs .083 | 13/16 | self-tip gone; everything draws |
| 2 | Wedge 34×8, Barge 52×12, guns re-heighted so the Tower's miss the Wedge and hit the Barge | .61 / .55 / .34 | .125 vs .156 | 10/16 | tilt puts every melee box on target anyway |
| 3 | Tower top back to ±8; Wedge rear wheel to -15 | .56 / .67 / .27 | .219 vs .167 | 7/16 | the Wedge climbs the Tower's ramp-like face and flips itself |
| 4 | Tower bottom chamfer; Barge guns lower | .62 / .58 / .30 | .156 vs .135 | 11/16 | the Barge drives up onto the Wedge |
| 5 | Barge front tyre inside its nose | .58 / .55 / .38 | .104 vs .146 | 11/16 | the Barge stays down but still loses: it fires half as often |
| 6 | sharp Wedge nose (no vertical face); Tower tyres inside the hull (±5) | .78 / .19 / .53 | .312 vs .219 | 16/16 | the Wedge flips the Tower 7–0, but a ±5 Tower fails `test_bodies` (tips, does not land upright) |
| 7 | Tower wheels back to ±9 | .56 / .64 / .30 | .167 vs .135 | 11/16 | the Wedge climbs the Tower's protruding tyre |
| 8 | Wedge friction 0.3 | .58 / .64 / .28 | .177 vs .229 | 9/16 | no help |
| — | **mass fix**: `mass` reaches Box2D (`ChChariotRuntime.settle_mass`); Tower needs 800 to pass `test_bodies` | | | | |
| 9 | real masses (Wedge default, Tower 800, Barge 872) | .55 / .75 / .20 | .260 vs .302 | 8/16 | heavy Tower wins everything |
| 10 | Barge restitution 0.6 | .56 / .78 / .16 | .292 | 8/16 | worse |
| 11 | Barge 52×6, Tower guns at its foot, Wedge 34×9 | .48 / .69 / .33 | .198 vs .156 | 7/16 | Wedge's Chainsaw still reaches the flat Barge (tilt) |
| 12 | Task 7 bodies + sharp Wedge nose + Barge mass 500 + `KITE_BACKOFF` 20 | .66 / .55 / .30 | .146 vs .062 | 9/16 | **kept** |
| 13 | try 12 + Barge friction 2.0 | .67 / .50 / .33 | .146 vs .115 | 9/16 | worse for the Barge |
| 14 | try 12 + Barge top slots at y = -2 | .67 / .56 / .27 | .167 vs .094 | 9/16 | worse for the Barge |

Kept (try 12): pair scores Cutter–Dozer .47, Cutter–Corsair .84, Dozer–Corsair .56. Met: the Dozer
flips in 9 of 16 Cutter–Dozer fights (mean 28.5 s), and `bodies` is further from even than the
box (MAD .146 vs .062). Not met: the Cutter scores .66 (limit .65), and there is no win/lose
cycle: the Corsair loses to both. What blocks it, measured:

- The Barge fires half as often as the Wedge. Both are brawlers paying 2 energy/s to drive; the
  Corsair's 3.0 regen against the Cutter's 3.5 leaves it 1.0/s net against 1.5/s, and the
  Corsair's 900 HP does not cover that. HP, cap and regen are body stats outside this task's knobs.
- Melee hits test unrotated `size` boxes, so the outline cannot make a Chainsaw miss; only flips can.
- `test_bodies` drives each body into the cook (a Corsair): a Barge above mass ~500 is not pushed
  away and the driver stops short of 100 cells, and a Tower with its wheels inside its hull (the
  shape that let the Wedge get under it) tips over on landing.

### Task 9: body stats and the press re-tune

Task 9 (button-and-bodies) widened the knobs to body HP / regen / mass, part costs and damage,
`PRESS_SHARE` and the cook's HP, and measured `demo` (with `press` ai / mash / never per build),
`demo-matrix` (the same three), `bodies` and `bodies-box` on every try. Columns: demo = player
win rate ai/mash against the cook per build (sparks freeze selfburn artillery hotmelee);
matrix = round-robin score under `ai`; bodies = cutter / dozer / corsair; MAD as above.

| # | change from the previous try | demo ai/mash | matrix | bodies | pairs C-D C-B D-B | MAD vs box | Dozer flipped vs Cutter |
|---|---|---|---|---|---|---|---|
| 0 | Task 8 state, presses | .12/0 0/0 .12/.12 0/.12 0/0 | .44 .39 .77 .22 .69 | .66 / .55 / .30 | .47 .84 .56 | .146 vs .062 | 9/16 |
| 1 | cook 1800→1100; Wedge regen 3.5→3.0; Tower mid slots y -3→+6, Tower loadout Chainsaw `[3]` Rocket `[5]` | .25/.12 0/.12 .62/.25 0/.12 .88/.12 | .45 .31 .83 .23 .67 | .52 / .69 / .30 | .25 .78 .62 | .219 vs .177 | 6/16 |
| 2 | Rocket 2→3 energy, 35→55 dmg; Flamethrower 2→3 energy; Barge HP 900→1100; Tower mass 600 | .25/.50 .12/0 .88/.50 .25/.12 1/.12 | .45 .39 .62 .22 .81 | .38 / .67 / .45 | .28 .47 .62 | .125 vs .125 | 7/16 |
| 3 | Chainsaw 16→12; Ring 25→20; Tower mass 2000 (stops the spawn wheelie, but drives 56 cells in 10 s: fails `test_bodies`) | .25/.38 .50/.62 .88/.50 .25/.12 .88/.12 | .39 .72 .58 .20 .61 | .33 / .66 / .52 | .22 .44 .53 | .125 vs .094 | 2/16 |
| 4 | Rocket 55→75; Chainsaw 12→10; `PRESS_SHARE` 0.6→0.8; Tower mass 900 (600 tips in `test_bodies`, 1200 is too slow) | .38/.25 .12/.38 .62/.25 .12/.12 .50/0 | .55 .55 .67 .19 .55 | .41 / .70 / .39 | .16 .66 .56 | .188 vs .135 | 4/16 |
| 5 | Barge regen 3.0→2.5, HP 1100→1300; Tower HP 1000→750; Wedge HP 650→750; cook 900 | .50/.50 .25/.38 .62/.62 .12/.12 .25/0 | .47 .53 .62 .39 .48 | .47 / .64 / .39 | .25 .69 .53 | .156 vs .115 | 4/16 |
| 6 | Tower slots back to y -3 (loadout `[3]`/`[5]` kept: its guns now clear the Wedge and reach the Barge's top parts); Barge regen 3.0; Tower HP 1000; Wedge HP 650; Chainsaw 12; `PRESS_SHARE` 0.6 | .38/.75 0/.25 .88/.62 .50/.38 1/.12 | .44 .45 .64 .28 .69 | .41 / .55 / .55 | .41 .41 .50 | .062 vs .031 | 6/16 |
| 7 | every HP down so the bodies suite ends fights: Wedge 450, Tower 700, Barge 900, cook 700 | .38/.62 0/.25 .88/.62 .50/.62 1/.25 | .50 .44 .67 .22 .67 | .52 / .52 / .47 | .44 .59 .47 | .062 vs .021 | 6/16 |
| 8 | Barge regen 3.5; Wedge regen 2.5 | .50/.50 0/.25 .88/1 .50/.62 .75/.12 | .48 .39 .62 .28 .72 | .30 / .52 / .69 | .41 .19 .44 | .156 vs .042 | 7/16 |
| 9 | Tower HP 500, regen 4.0 | | | .30 / .52 / .69 | .41 .19 .44 | .156 vs .052 | 7/16 |
| 10 | Tower back to 700 / 3.0; Barge regen 3.25; Ring 20→18 | .50/.50 0/.25 .88/.50 .62/.62 .88/.12 | .52 .42 .64 .33 .59 | .30 / .53 / .67 | .41 .19 .47 | .146 vs .042 | 7/16 |
| 11 | Wedge regen 3.0 | same as 10 | same as 10 | .47 / .52 / .52 | .44 .50 .47 | .031 vs .021 | 6/16 |
| 12 | Wedge regen 2.75 | | | .38 / .53 / .59 | .41 .34 .47 | .094 vs .042 | 7/16 |
| 13 | Flamethrower back to 2 energy (its damage is the behaviour's `PULSE_DAMAGE`, so tries 2–11 raised its cost for nothing) — **kept** | .50/.50 0/.25 .88/.50 1/.88 .88/.12 | .50 .44 .67 .28 .61 | (= 12) | | | |
| F0 | fix round: Flamethrower and Hearth pulses now read `def.damage` (`pulse_damage()`, 45 → 9 x 5, no change at the old data) | | | | | | |
| F1 | Flamethrower damage 45→63 | .50/.50 0/.25 .88/.50 .88/1 .88/.12 | .50 .41 .67 .34 .58 | (= 12) | | | |
| F2 | Flamethrower damage 81 | same but artillery t=21 | .50 .42 .67 .38 .53 (hotmelee ai−mash in the matrix drops to +.10) | | | | |
| F3 | Flamethrower damage 72 — **kept** | .50/.50 0/.25 .88/.50 .88/1 .88/.12 | .50 .41 .67 .38 .55 | (= 12) | | | |

Kept (try 13): what holds and what doesn't is in the Task 9 section of
`docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md`. What blocks the rest, measured:

- **Self-flips decide the bodies suite.** Every body spends 25–40 s of a 60 s fight flipped, mirrors
  included (Wedge mirror 32/31 s, Tower mirror 29/25 s). A flipped chariot's guns point at the sky,
  so most pairs end in draws (half a point each) and pair scores sit at .41–.53 whatever the stats.
  The Tower wheelies over when it lands with its motor running (probe: |rotation| 1.9 rad within
  0.6 s of landing); mass 2000 stops that but then it can't drive the arena.
- **Rockets miss at range.** A straight shot over the ±6-cell surface noise hits the ground, so a
  kiter is safe from a brawler's Rocket and the AI's "ranged parts are in reach while facing" rule
  fires Rockets that miss (38% hits under `ai`, 83% under `mash`, which fires them in contact).
- **`mash` is not worse in a brawl.** Brawlers push into contact, so every melee part is in reach
  and pressing on every tick spends the same energy as waiting; raising the Rocket's damage per
  energy over the Chainsaw's (25 against 12) did not make waiting pay. Only the builds whose dear
  part has a long cooldown and a big hit (Hearth, Ring of Fire: hotmelee, selfburn) need the timing.

## Known-fail (Task 9)

The suites pass (`ok: true`) while these spec §4 criteria fail. Their `expect` ranges pin today's
measured values so a change shows up, not because the values are right. Values are from the kept
state (Task 9 fix round, Flamethrower 72).

| criterion (spec §4) | bound | measured | scenarios whose pins encode the miss |
|---|---|---|---|
| `ai` beats `mash` per build, `demo` | gap ≥ +0.15 | sparks 0.00 (.50/.50), freeze −0.25 (0/.25), artillery −0.12 (.88/1.00); selfburn +0.38 and hotmelee +0.75 pass | `demo`: `vs-cook-sparks`, `-freeze`, `-artillery` and their `-mash` twins (win-rate pins within one fight of the values) |
| `ai` beats `mash` per build, `demo-matrix` (player win rate) | gap ≥ +0.15 | sparks −0.10 (.35/.45), freeze +0.05 (.05/0), selfburn −0.05 (.70/.75), artillery −0.25 (.20/.45); hotmelee +0.15 passes | `demo-matrix`: `matrix` and `matrix-mash` (pins only `aborted`, so nothing there guards the gap) |
| round-robin band | every build 0.35–0.65 | selfburn 0.67 (sparks .50, freeze .41, artillery .38, hotmelee .55) | `demo-matrix` `matrix` (no win-rate pin) |
| body cycle Wedge > Tower > Barge > Wedge | each body wins one pair ≥ 0.60 and loses one ≥ 0.60 | pairs Cutter–Dozer .41, Cutter–Corsair .34 (the Barge's win, .66, holds), Dozer–Corsair .47 | `bodies`: `bodies/0x1`, `bodies/1x0`, `bodies/1x2`, `bodies/2x1` (win-rate pins) |
| Dozer flipped in most Cutter–Dozer fights | > 8 of 16 | 7 of 16 | `bodies/0x1` `enemy.flipped_seconds`, `bodies/1x0` `player.flipped_seconds` (pin the mean seconds, not the count) |
| standalone part DPS (brief) | about 10–20 DPS | Flamethrower 21.3 is over 20. Rocket 8.3, Chainsaw 4.7, Hearth 2.7, Firebolt 2.0, Harpoon 0.2 and Mace 0 are under 10; only the Ring (12.9) is in range. The Mace and Harpoon reading about 0 may be an artifact of the plain-hull Corsair target rather than of the parts (not checked) | `standalone` (no `expect`; it measures) |

A test fails for the same reason. `tests/battle/test_bodies.gd`
`test_each_body_drives_the_arena` fails about half the time in suite runs: 6 of the 12 suite and
subset runs made in the Task 9 fix rounds, on the Task 9 data, and 0 of 7 isolated runs. It fails
with `dozer stayed wheels-down (max |rotation| 1.92)`. The Dozer (Tower) wheelies over when it lands
with its motor already running, and whether it does depends on how its join lines up with the fight
ticks, which the frame timing decides (the tests run without `--fixed-fps`). This is the real
self-flip defect, so the test is left as it is. No Dozer mass fixes it: 600 tips, and 1000 or 1100
cannot drive the 100 cells.

Check the button criterion on any `demo` or `demo-matrix` `--out` file with
`analysis/summary.py --press-gap out.json`. It prints the `ai` and `mash` win rates and the gap per
build, flags each gap under 0.15, and exits 1 if any is. Today it exits 1 on both suites.

