# Bodies and balance design

Date: 2026-11-06. Branch base: `garage-battle-ui`.

Markers: **Decided** was agreed with the user. **My call** was settled by the designer and can be
overruled. **Proposed** numbers are starting points the battle runner is there to tune.

## Intent

Two problems found in playtests:

1. **Bodies don't feel different.** Cutter, Dozer and Corsair are all plain rectangles
   (30×10, 30×18, 48×10 cells) with HP 500–600, energy cap 20–24 and regen 5–6. In practice slot
   count is the only difference between them.
2. **Parts aren't balanced.** By damage ÷ cooldown, the 12 in-game parts range from Harpoon at
   1 DPS and Ring of Fire at 1.7 DPS to Rocket at 30 and Chainsaw at 40, against a design target
   of 10–20 for a common weapon (`parts-list.md` §1.1). Several in-game parts also behave
   differently from their `parts-list.md` entries.

**Why bodies matter (Decided):** picking a new body is the big pivot of a run. Taking one means
committing to a different way of winning, and possibly giving up parts and builds that worked on
the old body. It should feel like a bet whose payoff is uncertain. The body itself is fully known
before the player takes it.

**What balance means (Decided):** every build (the synergy plans in `parts-list.md` §2) has a fair
shot at winning a run. Individual parts don't have to be equal. A build's payoff part can be weak
on its own and still carry the build, like Reaper carries a Strength build in Slay the Spire 1.
Under that sits a rough damage-per-energy baseline, so plain parts are fair against each other.

Research behind the body design: CATS bodies differ only by silhouette and stats. Each copy rolls
its own slots, and shape drives a rock-paper-scissors between height, stability and nose shape:
low wedges beat tall bodies, bouncers beat slow ranged builds, knockback beats bouncers. Body
notes are in `docs/design-doc/research/parts/cats-parts.md`. My call: this design appends a
"Body analysis" section there with the findings from this session.

## Goals

- Body types that play differently through **physics alone** (shape, mass, stats). (Decided.)
- Every offered body is a type plus a **procedurally generated slot layout**, and the player sees
  the exact layout before taking it. (Decided.)
- Written balance rules: a damage-per-energy baseline, and a separate pricing rule for payoff
  and enabler parts. (Decided.)
- The rules are applied to **both** the 169-part list on paper and the 12 in-game parts.
  (Decided.)
- The in-game parts and `parts-list.md` agree. (Decided.)
- A **headless battle runner** that measures win rates, time to kill and per-part output, and that
  future LLM agents can use without help. (Decided.)

## Non-goals

- Implementing the 157 parts that exist only on paper. Builds get verified by the runner as their
  parts are implemented.
- The shop and its body offers. No shop exists yet (`ch_main.gd` hands the inventory straight to
  the garage). This design makes generated bodies previewable in the garage; showing them on a
  shop card is the shop's job.
- Body special rules or abilities. (Decided: shape and stats only.)
- Part upgrades or levels (ruled out by `core-mechanics.md` §4.2).

## Anti-goals

- A body type that is strictly better than another. Every type must lose some matchups.
- A generated roll that is unplayable. A "bad roll" means a worse fit for your parts, never a
  chariot that can't drive or fight.
- Balancing by flattening: if every part ends up at the baseline, payoff parts stop carrying
  builds and the Reaper effect is gone.
- A runner that needs a window, a human, or reading GDScript to use.

## Constraints (from the code)

- The hull shape comes from the texture's opaque pixels: `PixelRigidBody` SHAPE_HULL (convex hull)
  or SHAPE_BOXES (concave). `ChTextures` only makes boxes and discs today, so each silhouette needs
  a new mask generator, not engine work.
- `ChBodyDef.slots` is a fixed `PackedVector2Array`. The **two lowest slots must sit on the hull's
  bottom edge** (`ch_body_def.gd` header, checked by `tests/data/test_catalog.gd`); a wheel mounted
  higher leaves the hull resting on the sand.
- `ChChariotLayout.swap_body` moves parts to the nearest slot by position. Kept unchanged: the cost
  of a new body is strategic (parts stop making sense), not mechanical. (Decided.)
- `ChBattle.start(player, enemy, catalog, seed)` runs one fight per scene instance, ticking once
  per awaited frame (`TICK` = 1/60 s, `FIGHT_TICKS` = 3600). The player's drive reads `Input`, so a
  headless fight today has a player that never moves.
- The fight is meant to be deterministic for a given seed (`ch_battle.gd` header).
- The part tooltips spec (`2026-11-06-part-tooltips-design.md`) describes what parts do in the game
  today. Every part whose behaviour changes here needs its tooltip text updated with it.

## Approaches

How to check the balance work:

1. **Rules on paper, checked by playtesting.** The cheapest option. But "fair shot" and "does
   shape matter" stay a matter of feel, and 169 hand-costed parts let errors through.
2. **Rules plus a list checker** that reads the `parts-list.md` tables and flags rule breaks.
   Catches maths errors across the list; physics and synergy stay unchecked.
3. **Rules, list checker and a headless battle runner.** (Picked by the user.) The only option that
   measures the two claims the design rests on: bodies differ through physics alone, and payoff
   parts are weak alone but strong in their build. It also replaces a throwaway shape spike. Cost:
   the biggest build, and it only tests parts that exist in the game.

On body identity, "shape and stats only" was picked over "shape plus one rule per type".
On randomness, "known body, uncertain payoff" was picked over CATS-style hidden rolls, with
slots still generated and shown in full before the pick.

## Design

Work order (Decided): **body types and budgets → balance rules and re-costing the list → bringing
the in-game parts into line**, with the runner built first so each step can be measured.

### 1. Body types

A **body type** fixes the silhouette, mass, HP, energy and the rules its slots are generated by.
A **body roll** is one generated instance of a type: a seed plus the resulting slot positions.

Physical axes the types are built on (Decided as the playback):

1. **Height:** parts fire straight ahead and nothing auto-aims, so a weapon's height against the
   enemy's hull decides who hits whom.
2. **Nose:** a sloped nose gets under enemies and lifts them on a ram; a blunt one shoves.
3. **Stability:** wheelbase against height and mass decides how easily it tips.
4. **Recovery:** a rounded top rolls back upright, a flat one stays stuck.
5. **Mass:** wins pushing contests and sinks into loose sand or water; light bodies bounce.

HP and slot count grow with hull area.

Roster (types and matchups Decided as the playback; numbers Proposed):

| Type | Existing body | Silhouette | Approx. cells | HP | En cap | Regen/s | Mass | Slots (incl. 2 wheel mounts) | Wins against | Loses to |
|---|---|---|---|---|---|---|---|---|---|---|
| Wedge | Cutter | Low, sloped nose | 34×9 | 650 | 18 | 5 | medium, low centre of mass | 4–5 | Tower: flips it, ducks its guns | Barge (too heavy to lift); low guns |
| Tower | Dozer | Tall and narrow | 22×30 | 1000 | 24 | 4 | medium, high centre of mass | 6–8 | Ranged fights, firing over mounds | Wedge and rammers: it tips |
| Barge | Corsair | Long, flat, wide wheelbase | 52×10 | 900 | 22 | 4.5 | heavy | 6–7 | Shoving, staying upright | Being slow and easy to hit |
| Dome | new | Round or semicircular | 28×20 | 700 | 20 | 5 | light, high bounce | 4–6 | Self-righting, bouncing over enemies | Knockback; can't hold its spot |
| Skiff | new | Short, very light | 22×8 | 500 | 16 | 6 | very light | 3–4 | Speed: cheap to drive, picks its range | Anything that connects |

My call: Cutter, Dozer and Corsair keep their ids and display names and are reshaped into Wedge,
Tower and Barge, so existing enemy layouts, tests and the garage's body cycle keep working. The
two new types get names of the same style (left to the builder). "Wedge", "Tower" and so on are
type names used in this doc and in data, and appear in the UI as the body's subtitle.

The physics levers each type uses are left to the builder: texture mask, `mass`, `friction`,
`restitution`, and where the centre of mass sits. They are tuned with the runner (§4) until the
matchup column holds.

### 1b. Enemy driving by body type

Decided (user picked this over a runner-only policy and over a free-form smarter AI). Today
`ChEnemyAI` drives to weapon reach plus both half-widths and stops, so hulls never touch, and an
enemy with only ranged weapons never moves. That makes the contact matchups (flipping, ramming,
shoving, knockback) impossible.

Each body type now carries a **drive style** that `ChEnemyAI` follows:

| Style | Types | Behaviour |
|---|---|---|
| Brawler | Wedge, Barge, Dome | Closes to contact and keeps pushing into the enemy hull |
| Kiter | Tower, Skiff | Holds at its weapon reach, and backs off when the enemy closes inside it |

- The style is part of the type, so the player can read an enemy's intent from its silhouette.
- Driving still pays the normal energy rules, so a brawler's charge costs it firepower.
- Hand-authored `ChBodyDef`s without a type default to the current hold-at-reach behaviour.
- The thresholds (how far a kiter backs off, how hard a brawler pushes) are left to the builder,
  tuned with the runner.
- The runner's `ai` policy is this same AI on either side, so suites measure what the player
  will actually face.

### 2. Procedural slots

Per type, a generator takes a seed and returns a slot list. My call on its rules:

- **Wheel mounts:** always the two lowest slots, on the bottom edge, at least a wheel's width apart
  and no further apart than the hull. The Barge may roll a third wheel mount.
- **Region bands:** each type has the area of the hull where its other slots may fall. A Tower puts
  most of them in its upper half, a Wedge keeps them all low, a Dome spreads them over its arc.
  Every roll stays recognisably its type.
- **Count range** from the roster table, and a minimum spacing so two parts' footprints don't
  overlap.
- **Playable floor:** every roll has at least one slot at a height that can hit a hull of each
  type. A generated roll that fails the floor is rerolled from the next seed.
- **Same seed, same roll**, so a roll can be saved, shown, shared and replayed by the runner.

Storage (my call): `ChBodyDef` stays the runtime shape. A new `ChBodyType` resource holds a type's
silhouette, stats and generator rules, and `ChBodyType.roll(seed)` returns a `ChBodyDef`. A layout
records `body_type` and `body_seed` alongside `body_id`, so swapping, saving and mirroring keep
working. Hand-authored bodies (enemies, tests) can still be plain `ChBodyDef`s.

Garage (my call, until the shop exists): the body buttons cycle types, and a debug reroll key
draws a new roll of the current type, so rolls can be playtested before any shop sells them. The
pit already draws the hull and its slots, which is the preview a shop card will reuse.

### 3. Balance rules

These go into `parts-list.md` §1 as **Decided** rules, with the numbers **Proposed**.

**Baseline.** A standalone part delivers about **15 damage per energy** at common, **18** at
uncommon and **22** at rare. The list's commons already sit near 15 (Rocket Pod 60 for 4, Cannon
120 for 6).

**Adjusters**, applied to the baseline:

- Melee: +25%, because it has to close to contact in a reactive arena.
- Beams and long-range parts: no bonus.
- Limited charges: +30% per firing, because the part goes dead mid-fight.
- Knockback, pull or other control effects: priced as damage at a rate the runner calibrates.

**Status conversion.** One stack of a status is worth a fixed damage equivalent per status (for
example Flame ≈ its expected burn damage), so status parts can be costed on the same scale. The
runner measures the conversion rates; until then each counts as 3 damage per stack.

**Stat parts** (+HP, Block, energy): priced through the same conversion. 100 HP or Block counts as
the damage it absorbs; energy gained counts as the damage that energy buys at the baseline.

**Continuous parts** (my call). Melee, beam and spinning parts are held to **both** the
damage-per-energy baseline and the DPS band (10–20 for a common, `parts-list.md` §1.1). They fit
both by costing less energy per second, not by dealing more damage: a common Chainsaw at 15 per
tick costs about **1/s** (15–19 damage per energy with the melee bonus), not 2/s. Most `/s` costs
in the list come down.

**Energy pressure.** A body's regen is the cap on sustained firepower. A full loadout of
standalone parts, **driving excluded**, should draw about **1–1.5× that body's regen** in energy
per second, so the queue fills sometimes but not constantly. Driving is paid first, so moving
pushes the chariot into starvation. That's the trade-off `core-mechanics.md` §3.3 calls the main
decision in battle, and it is meant to hurt (my call).

**Roles.** Every part in the list gets one of three roles:

- **Standalone:** priced at the baseline. Commons are standalone.
- **Enabler:** sets up a build (applies Oil, drops batteries). Priced at the baseline on its own
  output, with the setup counted as its control effect.
- **Payoff:** turns a build's setup into power. Deliberately **≤ 60% of the baseline when used
  alone**, with a written **target scenario**: the build parts it needs and the value it should
  reach with them. A payoff without a target scenario is a rule break.
  - What "1.5×" means (my call): the payoff's **marginal** value. In its target scenario, the
    chariot's damage per energy with the payoff, minus the same chariot with the payoff's slot
    filled by a baseline standalone part of the same rarity, should be about **0.5× that
    standalone part's own output**. Put another way, the payoff is worth about 1.5 standalone
    parts once its build is assembled.

**Who gets which role** (my call): commons are standalone. A build's **rares** (its cores in
`parts-list.md` §2) are its payoffs, usually 1–3 per build. Its **uncommons** are mostly enablers,
with at most one uncommon payoff per build. Bridge parts are standalone or enablers, so that
pulling in a second build never costs a payoff's weakness.

**List format.** My call: the part tables in `parts-list.md` gain three columns, so the checker
reads numbers rather than parsing effect text:

- **Dmg**: damage per firing, or per second for `/s` parts.
- **Role**: S, E or P.
- **Target**: for payoffs, a short reference to the scenario (for example `Inferno: U01+U02+C17`).

**List checker** (`tools/balance/check_list.gd`, headless): parses the tables, computes damage per
energy with the adjusters, and prints every part outside ±25% of its rarity band, every payoff above
60% alone or missing a target, and every malformed row. The exit code is non-zero if anything is
flagged.

**Re-costing.** All 169 parts are re-costed against these rules. Once the checker is clean, the
list's numbers stay **Proposed** until the runner has checked the ones that exist in the game.

### 4. Bringing the in-game parts into line

`parts-list.md` is the source of truth for numbers. Game behaviours worth keeping are written back
into the list. (My call, accepted with the mismatch table.)

| In-game part | List entry | Mismatch | Resolution |
|---|---|---|---|
| Cutter Rocket | C01 Rocket Pod | 2 en / 1 s / 30 instead of 4 / 4 s / 60; has an Ignition hook | `cutter_rocket` becomes the plain C01 Rocket Pod, so the game keeps a plain common weapon. Ignition moves to a new uncommon Inferno part, added to the list and to the game, that reuses the existing Ignition behaviour (my call) |
| Cutter Chainsaw | C03 Chainsaw | Fires every 0.5 s for 20 (2 en per firing), not a 2/s melee at 15 per tick; Sparks hook | Becomes a continuous melee part as the list says. Sparks is written into the list |
| Flamethrower | C16 | Fires every 3 s for 45, not a 2/s beam at 4 per second plus Flame | Becomes a beam as the list says |
| Corsair Harpoon | U77 Harpoon | A 5-damage weapon, not a start-of-battle pull | Becomes the list's pull |
| Strut | C42 | 2 extension slots, not 1 | Back to 1 slot; the list's Gantry already covers more slots |
| Wheel | C39 Roller | Driving costs 0 energy, not 1/s | Becomes the Roller at 1/s |
| Ember Battery, Freeze Charge, Firebolt Launcher, Hearth, Ice Cream Mace, Ring of Fire | — | Not in the list | Each is matched to an existing list entry with the same role, or added as a new entry, then costed by the rules |

Each changed part's behaviour script, `.tres`, tests and tooltip text change together. Existing ids
are kept where the part stays recognisably the same, so enemy layouts keep loading; the builder
renames an id only where the part becomes something else, and updates every layout that uses it.

### 5. The headless battle runner

Lives in `tools/balance/`. Made for LLM agents first: one command, plain JSON in and out, a short
text summary, and a doc that says when to use it.

**Command:**

```
godot --headless --path . -s res://tools/balance/run.gd -- <scenario.json> [--out <result.json>]
godot --headless --path . -s res://tools/balance/run.gd -- --suite <name>
```

**Scenario file** (JSON, so an agent can write one without knowing Godot resources):

```json
{
  "name": "wedge-vs-tower-rockets",
  "player": { "body_type": "wedge", "body_seed": 7,
              "parts": [ {"slot": [0], "part": "wheel"}, {"slot": [1], "part": "wheel"},
                         {"slot": [2], "part": "cutter_rocket", "flipped": false} ] },
  "enemy":  { "layout": "res://game/data/enemies/dozer_cook.tres" },
  "seeds": { "from": 1, "count": 20 },
  "drive": { "player": "ai", "enemy": "ai" },
  "expect": { "win_rate": [0.4, 0.6] }
}
```

- A side is either inline (`body_type` + `body_seed`, or `body_id`, plus `parts` by slot path) or a
  `layout` path to an existing `.tres`.
- `drive`: `ai` (the `ChEnemyAI` decision, using the body type's drive style from §1b), `hold`
  (no driving) or `charge` (always drive at the enemy). There's no input in a headless run, so
  the player side needs a policy. The `bodies` suite runs `ai` on both sides.
- `matrix` mode: `"player"` and `"enemy"` can be lists, and every pair is run.
- `expect` is optional. When present, the run fails (exit 2) if a metric is out of its range, so
  scenarios double as balance regression checks.

**Output.** One JSON result per scenario, and a summary on stdout whose last line is a single
machine-readable `RESULT {...}` line. Metrics (field names carry their units):

- Per scenario: wins, losses, draws, aborts, `win_rate`, `mean_fight_seconds`, and the seeds of
  any aborted or drawn fights.
- Per side: `hp_left`, `dps_dealt`, `energy_spent`, `energy_starved_seconds` (parts waiting in the
  queue), `flipped_seconds` (hull past 90°), `airborne_seconds`, `rams`.
- Per part: `firings`, `hits`, `misses`, `damage_dealt`, `damage_per_energy`, `seconds_waiting`,
  `broke_at_seconds`.

The physical metrics (flipped, misses, rams) are how the runner shows that shape matters, not
just HP.

**Built-in suites** (`tools/balance/suites/*.json`):

- `bodies`: every body type × every type, the same reference loadout on both sides. This checks
  the roster's matchup column.
- `standalone`: each standalone part on a reference body against a reference dummy. Measured
  damage per energy is compared with the paper value.
- `payoffs`: each implemented payoff alone and in its target scenario.
- `builds`: each build whose parts are all implemented, against a reference gauntlet of enemies.

**Speed and determinism.** Fights must run much faster than real time in headless mode; the
builder measures this and documents the flags needed (for example `--fixed-fps`). The same
scenario and seeds give the same result, covered by a test. Feedback, camera easing and the HUD
are skipped in runner fights if they cost time, without changing the fight.

**Docs for agents.** `tools/balance/README.md` gives copy-paste commands, the scenario schema, the
meaning of every metric, and how to read a suite's output. A project skill at
`.claude/skills/balance-runner/SKILL.md` tells an agent when to reach for the runner (after
changing a part, a body or a balance number), the commands, and how to interpret results. (My
call on the location.)

### 6. Success criteria (Proposed)

- **Bodies:** in the `bodies` suite, no type wins more than 65% of all its matchups, and every type
  wins at least one matchup ≥ 60% and loses at least one ≥ 60%. The same suite with every type
  replaced by a rectangle of equal stats is closer to even, which shows that shape decides fights.
- **Standalone parts:** measured damage per energy within ±25% of the rarity baseline.
- **Payoffs:** ≤ 0.6× the baseline alone and ≥ 1.5× in their target scenario.
- **Builds:** every implemented build wins 35–65% against the reference gauntlet.
- **List:** the checker passes on `parts-list.md`.
- **Runner:** an agent with only the README can write a scenario, run it and read the result.

## Left to the builder

- Silhouette masks, physics properties and the exact numbers that get the roster's matchups to
  hold, tuned with the runner.
- Names of the two new body types.
- The reference loadout, reference dummy and reference gauntlet used by the suites.
- The status conversion rates and control-effect pricing, measured with the runner.
- How the six unlisted in-game parts map onto list entries, following the roles above.
- Headless speed flags, and which visual systems to skip in runner fights.
