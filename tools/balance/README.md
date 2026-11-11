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
| `drive.player`, `drive.enemy` | no | `"ai"`, `"ai"` | `ai` (the enemy AI's approach-and-hold rule), `hold` (never drives), `charge` (always drives at the other chariot), `kite` / `brawl` (the AI's `kiter` / `brawler` drive style, whatever the body's own) |
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
| `dozer` | 700 | (-11, 15) (11, 15) · (-9, -3) rear · (9, -3) front · (-5, -15) rear-top · (5, -15) front-top |
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
| `hazard_damage` | HP this chariot lost to material blasts (TNT, gunpowder) |
| `killed_by_hazard` | true when a material blast took this chariot's HP to 0 (a mean over fights in the aggregates: the share killed) |
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
- `lazy`: each of the 8 damaging parts alone on a Corsair's `[6]` (`lazy/<part>`, and `-nowheels`
  without the `[0]`/`[1]` wheels), `press.player: mash`, against the Cook, seeds 1-16. `expect` pins a
  lazy build at 0-2 wins of 16, so it shows which one-weapon builds still beat the Cook (one pin is
  wider; see Known-fail).
- `demo` also holds `vs-cook-<build>-nowheels` twins (no wheels, `ai` presses); read them with
  `analysis/summary.py --wheel-gap out.json`. 16 seeds per scenario. The five reference builds drive `ai` (written out in
  `demo.json`): `kite` lost more fights and cut them under 35 s for every build but artillery.
- `mirror`: each `demo` build against itself, 20 seeds; `expect` pins each win rate within one fight.
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
| R | final-review fixes, no stat change: Harpoon looks past its own bodies, cook Mace on `[6]` / Hearth `[5]`, kiter back-off edge kept outside hull contact, Tower wheels ±9→±11 | .50/.75 0/0 .88/.75 .88/.88 .88/0 | .38 .44 .55 .55 .59 | .38 / .53 / .59 | .41 .34 .47 | .094 vs .021 | 9/16 |

Kept (try 13): what holds and what doesn't is in the Task 9 section of
`docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md`. What blocks the rest, measured:

- **Self-flips decide the bodies suite.** Every body spends 25–40 s of a 60 s fight flipped, mirrors
  included (Wedge mirror 32/31 s, Tower mirror 29/25 s). A flipped chariot's guns point at the sky,
  so most pairs end in draws (half a point each) and pair scores sit at .41–.53 whatever the stats.
  The Tower's own tip (|rotation| 1.9 rad) turned out to be its narrow wheelbase rocking over
  the arena's bumps, not the landing; the Tower's wheels moved to ±11 in the final-review round
  (see Known-fail).
- **Rockets miss at range.** A straight shot over the ±6-cell surface noise hits the ground, so a
  kiter is safe from a brawler's Rocket and the AI's "ranged parts are in reach while facing" rule
  fires Rockets that miss (38% hits under `ai`, 83% under `mash`, which fires them in contact).
- **`mash` is not worse in a brawl.** Brawlers push into contact, so every melee part is in reach
  and pressing on every tick spends the same energy as waiting; raising the Rocket's damage per
  energy over the Chainsaw's (25 against 12) did not make waiting pay. Only the builds whose dear
  part has a long cooldown and a big hit (Hearth, Ring of Fire: hotmelee, selfburn) need the timing.

## Known-fail (Task 9)

The suites pass (`ok: true`) while these spec §4 criteria fail. Their `expect` ranges pin today's
measured values so a change shows up, not because the values are right. Values are from the
final-review fix round (log row R). Two Task 9 rows now pass and are gone: the round-robin band
(every build is in 0.35–0.65: sparks .38, freeze .44, selfburn .55, artillery .55, hotmelee .59)
and the Dozer flipping in most Cutter–Dozer fights (9 of 16).

| criterion (spec §4) | bound | measured | scenarios whose pins encode the miss |
|---|---|---|---|
| `ai` beats `mash` per build, `demo` | gap ≥ +0.15 | sparks −0.25 (.50/.75), freeze 0.00 (0/0), selfburn +0.12 (.88/.75), artillery 0.00 (.88/.88); hotmelee +0.88 passes | `demo`: `vs-cook-sparks`, `-freeze`, `-selfburn`, `-artillery` and their `-mash` twins (win-rate pins within one fight of the values) |
| `ai` beats `mash` per build, `demo-matrix` (player win rate) | gap ≥ +0.15 | sparks 0.00 (.45/.45), freeze +0.05 (.15/.10), selfburn 0.00 (.75/.75), artillery −0.25 (.20/.45); hotmelee +0.20 passes | `demo-matrix`: `matrix` and `matrix-mash` (pins only `aborted`, so nothing there guards the gap) |
| body cycle Wedge > Tower > Barge > Wedge | each body wins one pair ≥ 0.60 and loses one ≥ 0.60 | pairs Cutter–Dozer .41, Cutter–Corsair .34 (the Barge's win, .66, holds), Dozer–Corsair .47; scores .38 / .53 / .59 | `bodies`: `bodies/0x1`, `bodies/1x0`, `bodies/1x2`, `bodies/2x1` (win-rate pins) |
| standalone part DPS (brief) | about 10–20 DPS | Flamethrower 21.3 is over 20. Rocket 8.3, Chainsaw 4.7, Hearth 2.7, Firebolt 2.0, Harpoon 0.4 and Mace 0 are under 10; only the Ring (12.9) is in range. The Mace at the Cutter's `[3]` lands nothing on the plain-hull dummy; in real fights against the cook's builds it lands (see below) | `standalone` (no `expect`; it measures) |

The cook's Harpoon and Mace now land against every body when the player is armed (cook hits per
fight, `ai` presses): against a Barge (`demo` corsair builds) Harpoon 0.5–2.6, Mace 1.5–10.1;
against a Tower (`vs-cook-freeze`) Harpoon 4.0, Mace 8.6; against a Wedge (Rocket + Chainsaw, 4
seeds) Harpoon 0.5, Mace 10.0. Against an unarmed hull that holds still (two wheels only) the
Harpoon lands nothing: the brawling Barge drives up onto a Wedge or a Barge, and tips itself
against a Tower, before its first 5 s cooldown is up.

`tests/battle/test_bodies.gd` `test_each_body_drives_the_arena` used to fail about half the time in
suite runs (`dozer stayed wheels-down (max |rotation| 1.92)`). The cause was not the landing: on
slow frames the same 600 ticks carry the Tower further, over the arena's bumps near x 215–280
(seed 12345), where its 18-cell wheelbase under a 30-cell hull rocked it onto its back. Holding
the drive until landing did not help, and angular damping up to 8 still tipped it on slow frames.
The Tower's wheels moved from ±9 to ±11 (its hull corners), and
`test_tower_drives_upright_on_slow_frames` pins it with a 30 ms stall on every tick.

Check the button criterion on any `demo` or `demo-matrix` `--out` file with
`analysis/summary.py --press-gap out.json`. It prints the `ai` and `mash` win rates and the gap per
build, flags each gap under 0.15, and exits 1 if any is. Today it exits 1 on both suites.

## Cook and arena tuning log

Task 6 of the cook-and-arena plan (`docs/superpowers/specs/2026-11-10-cook-and-arena-design.md`,
Goals). One lever per row where it could be split. Columns: G1 = `lazy` builds over 1 win of 8, and
the median Cook `hp_left` over every lazy fight (pass: none over, median ≥ half its HP); G2 = player
win rate and mean fight seconds of `vs-cook-<build>` (sparks freeze selfburn artillery hotmelee;
pass: .40-.70 and ≥ 35 s); G3 = wheels minus no-wheels win rate per build (pass ≥ .25); G4 =
hazard HP over all HP lost, both sides (pass ≥ .10, > 0 each side); AG = the worst build's share of
fights the Cook lost to a blast (pass < .25); matrix = `demo-matrix` round-robin scores (pass
.35-.65). Rows 1-13 ran `demo` on the `ai` and `-nowheels` scenarios only; rows 0 and F are the whole suite,
so their G4 counts the `mash` and `never` fights too. `—` means not run.
Rows 2 and 3 ran with the Cook as a separate layout, not the suite's.

| # | change from the previous row | G1 (over 1/8; Cook HP median) | G2 win; seconds | G3 gap | G4 | AG | matrix | verdict |
|---|---|---|---|---|---|---|---|---|
| 0 | Cook 700→1500 HP, Firebolt `[2]`, Ring of Fire `[3]` (the brief's start); fuse fix | 0/8 all; 957 | .25 0 0 0 .25; 30 27 32 29 33 s | −.25 0 −.25 −.50 +.12 | .002 (cook 0) | 0 | .53 .12 .73 .41 .70 | baseline |
| 1 | Rocket point-blank: a hit within 12 cells of its anchor pays half | 0/8 all; 1017 (rocket-nowheels 471→1172) | .25 0 0 0 .25; 30 27 32 29 33 s | (unchanged: the five builds' Rockets hit from 25+ cells) | .002 | 0 | | kept: the lone-Rocket cheese is gone |
| 2 | Cook `[3]` Ring of Fire → second Firebolt (1500 HP) | — | .12 0 .50 .25 .38; 39 19 36 44 41 s | −.38 0 +.25 −.38 +.25 | .008 | 0 | | fights reach 35 s; the Ring was 6 DPS against full builds (18 per part crossed) |
| 3 | Cook HP 1500 → 1200 | — | .62 0 .88 .38 .50; 31 19 28 40 35 s | −.25 0 +.62 −.50 +.38 | .008 | 0 | | |
| 4 | Firebolt damage 60 → 40 (the Tower died in 19 s to the Cook's two) | 0/8 all; 745 | .62 0 .88 .50 .50; 31 28 28 40 35 s | −.25 0 +.62 −.38 +.38 | .008 | 0 | | kept |
| 5 | a second TNT crate per side where the chariots meet (x 198-203, mirrored) | rocket-nw 2/8, mace-nw 2/8; 742 | .62 0 .88 .50 .62; 27 31 25 35 30 s | −.25 0 +.25 −.38 +.50 | .055 (player 4007, cook 3394) | .12 | | kept: hazards now hit both sides |
| 6 | Hearth 45 → 32 and Cook HP 1200 → 1450 (fights were 25-35 s; Hearth was 3/4 of the Cook's damage) | rocket-nw 2/8, ring-nw 2/8; 964 | .38 0 .38 .50 .25; 41 33 37 40 38 s | −.25 0 −.38 −.38 0 | .049 | 0 | | kept: fights reach 35 s |
| 7 | Firebolt speed 150 → 115 (lands at its 70-cell range) | rocket-nw 2/8, ring-nw 3/8; 1038 | 0 0 .12 .12 0; 24 25 33 33 31 s | −.50 0 −.50 −.75 0 | .053 | 0 | | reverted: the slower lob hits a chariot driving in (3 of 5) and misses one that stands (1 of 5), the opposite of G3. Kite drives did better (artillery .88, selfburn .62) |
| 8 | drive cost 2 → 1 energy/s | rocket-nw 3/8; 1046 | .38 0 .75 .38 .62; 36 30 30 49 30 s | −.50 −.25 −.25 −.50 +.25 | .043 | .12 | | reverted: no-wheel chariots pay the drive too (the AI holds a direction), so it lifted both and shortened fights |
| 9 | flank crate under the spawn's tail (x 138, fuse to 176) | mace-nw 2/8, flame-nw 3/8, ring-nw 3/8; 961 | .50 0 0 .62 .38; 38 44 36 47 34 s | −.12 0 −.88 −.12 +.12 | .045 | 0 | | reverted: a chariot standing on it took 30-50 hazard HP a fight, nothing lit it in most fights |
| 10 | TNT blast damage 150 → 250 (Hearth 36 = the 32 of row 6 after per-pulse rounding) | rocket-nw 2/8, ring-nw 2/8; 938 | .50 0 .50 .50 .25; 38 27 35 37 37 s | −.12 0 −.12 −.38 0 | .095 (player 7457, cook 6500) | 0 | | kept. Same at Cook HP 1600: .12 0 .38 .50 .12, lazy unchanged (2 fails): kept 1450 |
| 11 | Ring of Fire 18 → 14 per part, Chainsaw 12 → 15 (lazy Ring was the best lone part; hotmelee and sparks lean on Chainsaws) | rocket-nw 2/8, ring-nw 2/8; 940 | .38 0 .62 .50 .50; 34 27 31 37 37 s | −.25 0 −.25 −.38 +.38 | .089 | 0 | | kept |
| 12 | Mace swing reaches 6 cells above and below its head too | rocket-nw 2/8; 946 | .38 0 .62 .50 .50; 34 29 31 37 37 s | −.25 −.12 −.25 −.38 +.50 | .088 | 0 | | reverted: the Cook's Mace still landed 2-5 of 34 swings on a wheel-less Corsair, so height wasn't why it missed |
| 13 | Rocket point-blank 12 → 20 cells; TNT blast damage 250 → 300 | ring-nw 2/8; 916 | .25 0 .50 .50 .38; 31 27 31 35 36 s | −.38 0 −.38 −.38 +.25 | .109 (player 8666, cook 7553) | 0 | | kept: lazy Rocket off 2/8, G4 over 10% |
| F | final, the whole suites (row 13's numbers) | ring-nw 2/8; 916 | .25 0 .50 .50 .38; 31 27 31 35 36 s | −.38 0 −.38 −.38 +.25 | .145 (player 19828, cook 17828) | 0 | .58 .14 .66 .42 .70 | |

Round 2 (16 seeds for `demo` and `lazy`, so one fight is .0625; G4 on rows R1-R5 counts only the
`ai` and `-nowheels` fights):

| # | change from the previous row | G1 (over 2/16; Cook HP median) | G2 win; seconds | G3 gap | G4 | AG | matrix | verdict |
|---|---|---|---|---|---|---|---|---|
| R1 | freeze build: Rocket `[2]`, Freeze Charge `[4]`, Harpoon `[5]`, `[3]` empty (any front part made the Tower brawl and tip: 19-37 s flipped); Cook 1450 → 1250 | chainsaw-nw 3, rocket-nw 5, mace-nw 4, flame-nw 5, ring-nw 3; 711 | .56 .56 .62 .69 .44; 29 37 26 33 30 s | −.25 +.19 −.25 −.12 +.25 | .119 | .12 | | reverted HP: G2 5/5 but the no-wheel lazy builds grind a 1250 Cook down |
| R2 | the Cook's Mace → Chainsaw (1250 / 1350) | 6 builds over | .25 .56 .44 .44 .56 | | .109 | .12 | | reverted: lazy worse |
| R3 | Firebolt `LOFT` 20 → 8 (1250 / 1150) | 5 builds over | .19 .69 .19 .25 .12 | | .100 | .19 | | reverted: a flatter lob hits a full build, still misses a parked one |
| R4 | the Cook's Mace → a second Hearth (1250 / 1400) | rocket-nw 3, flamethrower 3; 819 | .06 .50 .50 .69 .38 | | .098 | .06 | | kept: the only lever that helped G1 and G2 together |
| R5 | Hearth 36 → 27 | flamethrower 7-9 | .12 .50 .50 .81 .38 | | .104 | .06 | | reverted |
| R6 | Cook 1500, Flamethrower 72 → 63, Rocket point-blank share .5 → .25, Chainsaw 15 → 18 | rocket-nw 3, chainsaw-nw 3; 949 | .06 .50 .44 .56 .56 | | .095 | .06 | | kept |
| R7 | middle crate 3 → 5 deep (out of a Rocket hull hit's reach) | none over; 957 | .12 .62 .38 .25 .50; 28 43 33 47 32 s | | .065 | .06 | | reverted: G1 passes but G2 drops to 2/5 |
| F2 | final, the whole suites, clean tree (R6 numbers) | rocket-nw 3, flamethrower-nw 3; 949 | .12 .56 .38 .50 .50; 28 41 32 43 29 s | −.19 +.25 0 +.25 +.44 | .120 (player 21535, cook 41214) | .06 | .41 .77 .56 .22 .55 | |

Kept numbers (before → after, both rounds): the Cook 700 → 1500 HP with a Firebolt Launcher on `[2]`
and `[3]` and a second Hearth on `[6]` in place of the Mace (Harpoon and Hearth `[5]` kept); a Rocket
hit within 20 cells of its anchor pays a quarter (new); Firebolt damage 60 → 40; Hearth 45 → 36;
Ring of Fire 18 → 14; Chainsaw 12 → 18; Flamethrower 72 → 63; TNT blast 150 → 300 HP at the centre;
gunpowder radius 3 → 5, gunpowder and TNT `burn_heat` 0 → 600, the seam 1 → 2 rows (so a lit seam
reaches its crate); a second TNT crate per side at x 198-203 (mirrored 276-281), 3 deep. The freeze
reference build is Rocket `[2]`, Freeze Charge `[4]`, Harpoon `[5]` in `demo`, `demo-matrix` and
`mirror`; it still freezes (3 parts a fight) but has no Shatter.

## Known-fail (cook and arena)

The suites pass (`ok: true`) while these Goals miss. Their `expect` ranges pin today's values so a
change shows, not because the values are right. Values are row F2.

| goal | bound | measured | why, measured | pins that encode it |
|---|---|---|---|---|
| G1 lazy builds lose | every `lazy/*` ≤ .125 (2 of 16) | `lazy/cutter_rocket-nowheels` and `lazy/flamethrower-nowheels` 3 of 16; every other lazy build 0-2; Cook median 949 of 1500 passes | against a chariot with no wheels the Cook deals 10-17 DPS (its Firebolts miss a low target), so a parked lazy build grinds it down in a 40-57 s fight, partly with the TNT under the Cook. Every HP cut that lifts the full builds lifts these too (R1); the crate 5 deep fixes G1 but costs G2 (R7) | `lazy`: those two at `win_rate` [0, 0.1875] |
| G2 full builds | .40-.70 and ≥ 35 s | freeze .56 / 41 s and artillery .50 / 43 s pass; hotmelee .50 / 29 s (time short), selfburn .38 / 32 s (one fight short), sparks .12 / 28 s | sparks brawls with Chainsaws in contact and the two Hearths burn it down, `kite` included (.12); a recorded miss | `demo`: each `vs-cook-*` within one fight of the measured win rate, `mean_fight_seconds` ±5 s |
| G3 moving matters | wheels − no wheels ≥ .25 | freeze +.25, artillery +.25, hotmelee +.44 pass; selfburn 0, sparks −.19 | parked: the Cook drives to you, so for a brawler standing still costs nothing | `demo`: the `-nowheels` twins' win-rate pins |
| round-robin band | every build .35-.65 | freeze .77, artillery .22 (sparks .41, selfburn .56, hotmelee .55 pass) | the ranged freeze build holds off every brawler; artillery loses its Flamethrower edge (72 → 63) | `demo-matrix` pins only `aborted` and `matrix-never` |
| standalone baseline | common weapons 10-20 DPS at about equal damage per energy | Flamethrower 18.9 (29.3 per energy) and Mace 10.2 (15.7) in range; Ring 9.1, Chainsaw 6.3, Hearth 4.8, Rocket 1.3, Harpoon 1.0, Firebolt 0.8 under | the dummy underrates ranged and lobbed parts (handoff open problem 4) | `standalone` (no `expect`) |

`mirror`: the player side wins 36 of 100 and the enemy 46 (18 draws), as before this task (the
double knock-out goes to the enemy, see the handoff). Blasts killed 9 player-side and 9 enemy-side
chariots, so the arena doesn't favour a side. `matrix-never` (the player never presses) wins 0.