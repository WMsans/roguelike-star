# Handoff: balancing the demo with the balance runner

Date: 2026-11-07. Branch: `garage-battle-ui`. All of this work is in commit `4b5dc53`.

## The task

The user asked: "Use the suite to balance out the demo." The demo is the 12 in-game parts, the 3
bodies (Cutter, Dozer, Corsair) and the one enemy, `game/data/enemies/dozer_cook.tres`. The player
starts with two of every part (`game/ch_main.gd`, `_starter_inventory`).

What "balanced" means was decided with the user earlier (spec:
`docs/superpowers/specs/2026-11-06-bodies-and-balance-design.md`, §Intent and §3):

- **Every build has a fair shot.** A build is a synergy plan. Payoff parts may be weak alone and
  strong in their build, like Reaper in Slay the Spire.
- **A rough damage-per-energy baseline still holds** for plain parts. A common weapon deals 10–20
  DPS (`docs/design-doc/parts-list.md` §1.1).
- A full loadout should draw about 1–1.5× its body's energy regen, driving excluded, so energy
  runs short and moving costs firepower (`core-mechanics.md` §3.3).

The success thresholds I worked to (Proposed in spec §6, my call for the demo):

- Standalone weapons: 10–20 DPS, and damage per energy roughly equal.
- Build round-robin: no build above 0.65, none below 0.35.
- The demo enemy: every build beats it about 55–85% of the time, in fights long enough
  (30 s or more) for chains to show.

## Tools

- The runner: `tools/balance/run.sh`. Read `tools/balance/README.md` first; it has the schema and
  the metrics. It must run under `--fixed-fps 60` (the wrapper passes it), or fights don't
  reproduce. A 60 s fight takes about 1.5 s.
- Suites (`tools/balance/run.sh --suite <name> --out <file>`):
  - `standalone`: each damaging part alone on a Cutter against a 100000 HP dummy that holds still.
    About 1 minute.
  - `demo` (new): the five reference builds below against `dozer_cook`, 8 seeds each.
  - `demo-matrix` (new): a round-robin of the five builds, 4 seeds per pairing (100 fights, about
    8 minutes).
- Analysis (new): `tools/balance/analysis/summary.py <out.json>` prints one line per matchup.
  `tools/balance/analysis/matrix.py <out.json>` prints the round-robin table with a score per build
  (share of fights won, draws counted as half).
- A suite file can only be run with `--suite <name>` from `tools/balance/suites/`. A file passed
  directly must be a single scenario (a `{"name","player","enemy",...}` object).

### The five reference builds

All of them fill every free slot, use at most two of a part, and place melee parts where they reach.
Corsair top slots run `[2]` (rear) to `[6]` (front), all at the same height. Dozer: `[2]` rear,
`[3]` front, `[4]` rear top, `[5]` front top.

| Build | Body | Parts | Chain it tests |
|---|---|---|---|
| `sparks` | Corsair | Chainsaw [6],[5], Rocket [4],[3], Ember Battery [2] | Chain 1: Sparks → fire → Ember / Rocket Ignition |
| `freeze` | Dozer | Mace [3], Harpoon [5], Freeze Charge [4], Rocket [2] | Chain 2: freeze → Harpoon → Mace Shatter |
| `selfburn` | Corsair | Mace [6], Hearth [5],[4], Ring of Fire [3], Ember Battery [2] | Chain 3: burn yourself → Ember pays |
| `artillery` | Corsair | Flamethrower [6],[5], Firebolt [4],[3], Rocket [2] | Plain fire damage, no payoff |
| `hotmelee` | Corsair | Chainsaw [6],[5], Hearth [4],[3], Ring of Fire [2] | Plain melee plus self-burn |

The chains come from `docs/superpowers/specs/2026-11-02-battle-slice-design.md` §5.6.

## What changed

### Numbers (data)

| File | Before → after | Why |
|---|---|---|
| `cutter_rocket.tres` | en 2, cd 1.0, dmg 30 → en 2, cd 1.5, dmg 35 | Hit 90% against enemies that close in, which made it 26 damage per energy; now about 14 in fights |
| `cutter_chainsaw.tres` | en 2, cd 0.5, dmg 20 → en 1, cd 0.75, dmg 16 | Was 25 DPS at 6.6 per energy; now 14 DPS, about 13–15 per energy in fights |
| `hearth.tres` | en 2 → en 3; `proximity_range` 0 → 2 | 28 per energy was far over; the reach lets the AI close in (see below) |
| `firebolt_launcher.tres` | en 1, dmg 25 → en 3, dmg 60; `proximity_range` 0 → 70 | 5 charges of 25 barely mattered |
| `flamethrower.tres` | `proximity_range` 0 → 40 | The AI never closed in (see below) |
| `ring_of_fire.tres` | en 4, cd 6, dmg 10 → en 5, cd 4, dmg 25; `proximity_range` 24 → 36 | 1.4 per energy and it killed its own chariot |
| `cutter.tres` | HP 500, cap 20, regen 6 → 650, 10, 3.5 | HP from the spec's roster (Wedge); smaller cap and regen so energy runs short |
| `dozer.tres` | HP 500, cap 20, regen 5 → 1000, 14, 3.0 | Roster (Tower) |
| `corsair.tres` | HP 600, cap 24, regen 5 → 900, 12, 3.0 | Roster (Barge) |
| `dozer_cook.tres` | new `max_hp = 1800` | Every build beat it 7–8 times out of 8 in about 20 s |

### Behaviour constants

- `ch_ring_of_fire.gd`: `RADIUS` 24 → 36. **It no longer damages its own chariot's bodies** (enemy
  side only, the same as Hearth). Its fire cells still set your own parts alight, which is what
  Ember Battery pays for. The slice spec said "hits its own chariot too", so this is a behaviour
  change; tell the user.
- `ch_firebolt.gd`: `SPEED` 110 → 150, `LOFT` 60° → 20°. The flatter shot lands about 4 hits in 5
  against enemies that close in (it was 1 in 5).
- `ch_freeze_charge.gd`: `FREEZE_PER_HIT` 0.5 → 1.0. **This changed nothing measurable** (see open
  problems).

### Code

- **The AI reach bug** (the main find): `ChEnemyAI.reach` reads a weapon's reach from
  `def.proximity_range`, and treats 0 as unlimited range, so the AI parks across the arena.
  Flamethrower, Hearth and Firebolt had 0 and never hit anything. The fix was data only: each got
  its real reach. `proximity_range` doubles as both weapon reach and chain proximity, which the code
  documents in `ch_behaviour.gd`. Splitting them is the alignment plan's job.
- **Layout `max_hp`**, the enemy max-HP lever from `core-mechanics.md` §8:
  - `ChChariotLayout.max_hp` (0 means the body's HP), kept by `mirrored()` and by the garage's fight
    copy.
  - `ChChariotRuntime.max_hp` falls back to `body_def.hp` when unset. The builder seeds `hp` from it.
  - The HUD and `ChFightStats` read `max_hp`.
  - The scenario `hp` override also sets `max_hp`.
  - The test fixture `ChTest._enemy_layout()` returns a copy with `max_hp = 0`, because the fight
    tests size the enemy through `_fight_catalog`.
- **Ember Battery** puts the energy that actually landed after the cap into its `ENERGY_GAINED`
  event (`data.amount`).
- **New runner metrics** per side: `energy_gained`, `caught_fire` and `frozen` (README updated).

## Where it stands (final run on the numbers above)

Standalone, against the dummy:

| Part | DPS | Damage per energy | Notes |
|---|---|---|---|
| Chainsaw | 14.0 | 10.4 | |
| Rocket | 12.1 | 9.3 | Misses half against a dummy that holds still; about 14 in real fights |
| Mace | 11.4 | 11.4 | |
| Flamethrower | 11.2 | 17.7 | Burns itself a little |
| Hearth | 14.0 | 18.6 | Costs about 275 HP of self-burn per 60 s |
| Ring of Fire | 11.8 | 8.4 | Self-burn |
| Firebolt | 1.6 | 2.4 | The flat shot falls short of a dummy parked 70+ cells out; 15 per energy against real enemies |
| Harpoon | 0.2 | 1.0 | Utility |

Against `dozer_cook` at 1800 HP (`demo` suite), 8 seeds each:

| Build | Wins | Fight length |
|---|---|---|
| sparks | 7/8 | 33 s |
| freeze | 4/8 | 40 s |
| selfburn | 8/8 | 42 s |
| artillery | 8/8 | 32 s |
| hotmelee | 6/8 | 47 s |

Round-robin (`demo-matrix`), score per build:

| sparks | freeze | selfburn | artillery | hotmelee |
|---|---|---|---|---|
| **0.84** | 0.38 | 0.41 | 0.47 | 0.41 |

Four builds sit within 0.38–0.47. **Sparks is the outlier at 0.84.** Without its Ember Battery it
still wins 14 of 16, so Ember isn't the cause. In real fights the parts are now about even per
energy: Rocket 14–15, Chainsaw 12–15, Firebolt 15, Hearth 16–19, Mace 19, Flamethrower 22, Ring
of Fire 8–11, Harpoon 4. Sparks wins because it's the only build with no drawbacks whose chain works.

## Open problems (these need the user's call; numbers can't fix them)

1. **Freeze Charge never freezes anything.** `frozen` is 0 on the enemy in every fight. Freeze is
   only applied when a hit lands on a *part* (`ChBattleContext.deal_hit`: `target_part != null`),
   and Rockets and Maces almost always hit the hull. So Chain 2 (freeze → Shatter) never fires, and
   the freeze build carries a dead slot. Options to bring to the user: freeze applies to the part
   of the target nearest the hit; or the hull itself can be frozen (pausing every cooldown); or
   Shatter checks "any frozen part on the target chariot".
2. **Self-burn costs more than Ember pays.** Burning costs a flat 5 HP/s while any part burns
   (`ChDamage.burn_tick`), and self-burn builds are alight most of the fight. Ember also triggers on
   *anything* catching fire, so it pays the **opponent** of a self-burner too (Sparks's Ember earns
   20+ per fight off enemies that light themselves). Whether Ember should count only your own parts
   is a design question.
3. **Sparks at 0.84.** Once 1 and 2 are settled, rerun `demo-matrix` before nerfing anything
   further. Sparks's parts are at the baseline; its edge is structural.
4. **The standalone dummy underrates ranged and lobbed parts** (Rocket, Firebolt), because the AI
   parks at long range in front of a target that never moves. Compare per-energy numbers from the
   `demo` suite as well, not just `standalone`.
5. The Harpoon raycast stops at the first body, including the user's own parts, so it only works
   from a slot with nothing in front of it at the same height. That's placement as designed, but
   worth saying in its tooltip.

## Next steps

1. **Update the 9 failing tests to the new values.** Currently 228 passed, 9 failed. Every failure
   pins an old number or old behaviour; none is a regression:
   - `test_catalog.gd` `test_spec_numbers`: body HP, caps and regen; Chainsaw and Ring costs.
   - `test_garage.gd` `test_no_hint_labels`: the Cutter's "HP · Energy" line.
   - `test_behaviours_fire.gd` `test_ring_of_fire_hits_self_and_enemy_once_each`: the Ring no longer
     hits its own chariot, and its radius is now 36. Rename it and assert that the own side takes
     no hit.
   - `test_behaviours_melee.gd` `test_freeze_charge_freezes_wheel`: one hit now fills the meter.
     `test_mace_shatters_only_its_own_hit`: off by 2 integrity, so check which number moved.
     `test_chainsaw_sparks_emit_cells_cut`: cooldown 0.75, so it needs more ticks.
   - `test_behaviours_ranged.gd` `test_rocket_explodes_and_damages` and
     `test_rocket_ignition_halves_cooldown` (cooldown 1.5), and `test_firebolt_starts_fire` (new
     arc).
   - For each one, read the test's own comments: they say what the test pins. Change the
     constants, and don't weaken what is being checked.
   - Run `godot --headless --path . --script res://tests/run_tests.gd`. It must end `0 failed`.
2. Update tooltip text for the parts whose numbers or behaviour changed (Ring of Fire no longer says
   "yours too" for damage). The tooltip copy is in the part-tooltips work
   (`docs/superpowers/specs/2026-11-06-part-tooltips-design.md` §table, and the garage tooltip code).
3. Add `expect` ranges to `demo.json` once the numbers are final, so the suite guards the balance
   (for example `win_rate` [0.5, 0.9] and `mean_fight_seconds` [25, 55]).
4. Bring the open problems to the user, then rerun `demo` and `demo-matrix`.
5. Commit only when the user says so.

## State of the tree

Everything is committed in `4b5dc53` on `garage-battle-ui`. The 9 failing tests listed under Next
steps are failing in that commit, so fix them first.

## Update, second session (2026-11-07, uncommitted)

Next steps 1, 2 and 4 are done. Tests: 238 passed, 0 failed. If `tests/balance/*` fail with "did
not run", the local `.godot` class cache is stale: run `godot --headless --path . --import` once.

The user's calls on the open problems:

1. **Freeze:** a hull hit puts its freeze on the target's part nearest the attacker
   (`ChBattleContext.deal_hit`, `hit["freeze_part"]`; the Mace's Shatter reads that key).
   That alone changed nothing: a hit's full meter decayed below 1.0 on the next tick, so a freeze
   lasted one tick and `FROZEN` never fired. Now a part stays frozen until its meter decays to 0
   (`ChPartRuntime.frozen_held`; 4 s at `FREEZE_DECAY` 0.25), per the slice spec's "Freeze decays
   over time". A Shatter still thaws at once.
2. **Ember** counts only its own chariot's fires. Tooltip updated.

Also: tooltip copy for Rocket, Chainsaw, Firebolt, Freeze Charge and Ring of Fire now matches the
numbers. The Sparks 7/8 in the table above was stale: it's 5W 1L 2D on `4b5dc53` too.

Results now (`demo`, against `dozer_cook`): sparks 5-1-2, freeze 6-2, selfburn 7-0-1, artillery
8-0, hotmelee 6-2. The freeze build's enemy freezes 17 times per fight, and its Mace deals 45.6
damage per energy (the Shatter payoff).

`demo-matrix`: sparks 0.72, freeze 0.66, artillery 0.47, hotmelee 0.38, **selfburn 0.28**.

Tried and reverted: Ember `GAIN` 3 → 5 left selfburn exactly at 0.28 (it's starved for only about
6 s per fight, so energy isn't what it lacks) and lifted Sparks to 0.75. Selfburn's cost is the
flat 5 HP/s self-burn (`ChDamage.burn_tick`), which needs a design call (scale burn by parts
alight? Hearth/Ring self-ignite less?). `expect` ranges for `demo.json` are still left out until
the numbers are final.

### Selfburn follow-up (2026-11-08)

- **Burn per burning part: tried and reverted.** Selfburn went 1/8 against the cook at 2.5 HP/s per
  part, 4/8 at 1.5 and 7/8 at 1.0, against 7/8 on the flat rule. Hotmelee went 0–1/8 against 6/8.
  Hearth's ring lights most of its own chariot, so any per-part rule charges self-burners the most.
  The burn is back to flat 5 HP/s.
- **Self-burn isn't what sinks selfburn.** With burn damage off for both sides it still goes 7-0-1
  against the cook, and self-burn costs it only about 130 HP per fight. So "Hearth/Ring self-ignite
  less" can't lift its score and wasn't done.
- **Ring of Fire cost 5 → 3** (kept): 8 → 13.8 damage per energy, at baseline. Against the cook:
  selfburn 8/8, hotmelee 7/8. In `demo-matrix` selfburn stays at 0.25 (sparks 0.72, freeze 0.66,
  artillery 0.47, hotmelee 0.41).
- Hotmelee's Ring at Corsair `[2]` (rear) fires 9 times per fight and hits nothing. That's a
  placement problem in the reference build, not the part's numbers.
- Every mirror match in `demo-matrix` goes 1-3 or 0-4 against the player side, which hints at a
  spawn or side bias in the arena. The score counts both sides, so it cancels there, but check it.
- Round-robin fights last 13–25 s, against 30–47 s for the cook. Selfburn opens slowly (Hearth
  charges for 1 s on a 4 s cooldown) and loses short fights. That's the lead for its next pass.

Also fixed: `test_garage.gd` `test_main_draw_panel` fought the cached `dozer_cook.tres`, whose
`max_hp` 1800 wins over the catalog's `TALL_HP`. It now clears that `max_hp` for its own fight.

### Side bias and player skill (2026-11-08)

- **Side bias: an artefact of mirror matches, not a bug.** New suite `mirror` (each build against
  itself, 20 seeds): the player side wins 32/100, but artillery goes 10/10. A fully symmetric arena
  (tried, reverted) barely changes it. The cause: identical builds fire on the same frames and
  often kill each other on the same tick, and `ChBattle.result_for` gives a double knock-out to the
  enemy (by design). In selfburn mirrors that decides 12 of 20 fights. In `demo-matrix` only 3 of
  100 fights are double knock-outs, all in mirrors. Outside mirrors the player side wins 43/80, and
  the round-robin score counts both sides, so it isn't distorted. Each tick is effectively
  simultaneous: a chariot killed earlier in a tick still acts later in it.
- **The arena isn't mirror-symmetric** (wood 130/322, water 196/252, lava 172@142 / 246@148, and
  one-sided surface noise per seed). It isn't the cause of the bias, but it's there.
- **Player skill.** A human can drive better than `ai`. The best simple policy is `hold` (stand
  still and save the energy that driving costs). It wins as often as `ai` against the cook but ends
  with much more HP left (sparks 654 against 503, freeze 549 against 323). Taking the best policy
  per build, the cook loses 6–8 of 8 to every build, so it's easy for a careful player.
- **Cook HP isn't a uniform difficulty dial.** At 2400 or 3000 HP selfburn and hotmelee fall to
  0–1 of 8 while artillery stays at 7–8 of 8. Longer fights reward steady damage and punish
  self-burn, which piles up over time. A difficulty dial that doesn't reorder the builds would be
  the cook's damage or its AI, not its HP.
- **Smarter cook AI: a "careful driver" tried and reverted.** The rule, shared by both sides: stand
  off outside the other side's longest reach-limited weapon when you can outrange it, and don't
  drive toward the enemy below the energy cost of your dearest weapon. As a player stand-in it was
  worse. Backing away costs 2 energy/s, so careful players starved for 42–55 s of each fight and
  timed out (artillery drew all 8 against the cook). It didn't make the cook harder either: `hold`
  against it matched `hold` against the old cook exactly. While driving, the cook still nets
  +1 energy/s (Dozer regen 3, drive 2), so the reserve never triggered, and with no ranged weapon it
  never stands off. The cook's kit (Hearth, Mace, Harpoon) is a pure brawler, so there's little for
  a driving AI to do better. `hold` remains the best cheap stand-in for a careful human.

### Builds fixed, cook left as is (2026-11-08)

- **Cook difficulty by build:** a fourth weapon in the cook's empty slot `[4]` was tried and not
  kept. Hearth or Ring of Fire crush selfburn and hotmelee (0/8), and a Rocket made the cook easier
  by eating its energy. Every way of making the cook harder hit the two weakest builds first, so
  those were fixed before the cook.
- **hotmelee reference build:** Ring of Fire moved `[2]` → `[4]`, Hearth `[4]` → `[2]`. From the
  rear slot the Ring is 44 cells from the enemy, beyond its 36-cell radius, so it never hit.
  Score 0.41 → 0.72 (later 0.53 once the others were fixed).
- **selfburn reference build:** now Chainsaw `[6]`,`[5]`, Ring `[4]`, Hearth `[3]`, Ember `[2]`.
  The Mace version was hotmelee minus a weapon: it was starved of energy for only about 5 s, so
  Ember (about 13 energy per fight) was nearly a dead slot. A faster Hearth opening (first ring at
  1 s, or a 0.5 s charge) changed nothing (0.28–0.30). **Ember is still weak** in every build tried
  (starved 0.1 s, gain 5 no better). Paying out energy only matters to a build that's short of it,
  so what Ember pays is a design question.
- **Firebolt cost 3 → 1** (user's call over aiming the lob). Its fixed flat arc lands about 1 shot
  in 4 against builds that hold at range (5–6 damage per energy). The cook drives straight in,
  which is why it read 17 there. Artillery 0.22 → 0.41. Two Flamethrowers and three Rockets scored
  0.62, for comparison.
- **Final** `demo-matrix`: sparks 0.69, hotmelee 0.53, selfburn 0.47, freeze 0.41, artillery 0.41.
  Against the cook, with the AI driving the player: 5-1-2, 6-2, 7-0-1, 8-0, 8-0. With `hold`:
  7, 6, 5, 7, 4 of 8 (50–88%), about the 55–85% target. So the cook wasn't made harder, since
  hotmelee (4/8) would drop under. Playtest before tuning further.
- Open: sparks at 0.69 is just over 0.65 (4 seeds per pairing). `expect` ranges for `demo.json`
  are still to add once the user signs off on these numbers.

### Ember as the core of an energy-hungry build (2026-11-08)

- User's intent: Ember Battery is the core of builds whose parts exhaust energy.
- **The chain-3 reference build (still named `selfburn` in the suites) is now E1:** Chainsaw `[6]`,
  Rocket `[5]`,`[4]`, Hearth `[3]`, Ember `[2]`. The Hearth sets your own parts alight, Ember turns
  each catch into energy, and the same catches trigger the Rockets' Ignition, which spends it.
- Measured against a third Rocket in Ember's slot (40-fight slices): E1 0.55 with Ember against
  0.53 without; 2 Flamethrowers + 2 Rockets 0.60 either way. Without Ember these builds starve
  for 10–14 s per fight; with it, 4–6 s. Ember gain 5 drops starvation to 1.5–3.4 s but doesn't
  move the score. **Ember's ceiling is the starvation a build would otherwise have**, so it's worth
  about one weapon slot now. User's call: stop there, and revisit once more energy-hungry parts
  exist.
- Final `demo-matrix`: sparks 0.69, selfburn (E1) 0.56, artillery 0.47, hotmelee 0.41,
  freeze 0.38. Against the cook (AI-driven player): 5-1-2, 6-2, 8-0, 8-0, 8-0. With `hold`:
  7, 6, 6, 7, 4 of 8.

### Re-balance for presses (2026-11-09, button-and-bodies Task 9)

Cooldown auto-fire became the one-button volley, and the bodies became the Wedge, Tower and Barge
shapes. This pass re-tuned for both. Full try log: `tools/balance/README.md`, "Task 9".

- **Numbers kept:** Rocket 2→3 energy, 35→75 damage (25 per energy against the Chainsaw's 12, so
  saving for it should pay). Chainsaw 16→12 damage. Ring of Fire 25→18 damage. Cook 1800→700 HP.
  Body HP: Cutter 650→450, Dozer 1000→700, Corsair 900. Regen: Cutter 3.5→2.75, Corsair
  3.0→3.25, Dozer 3.0. Dozer mass 900 (it had none; the default tips at landing, 600 tips in
  `test_bodies`, 1200 can't drive 100 cells in 10 s). `PRESS_SHARE` stays 0.6 (0.8 was tried and
  did worse). The Dozer's `bodies` loadout is now Rocket `[5]`, Chainsaw `[3]`.
- **Suites:** `demo` and `demo-matrix` gained `-mash` / `-never` variants. Expect ranges pin the
  current results: `demo` within one fight and 5 s, `-never` at a win rate of 0, every matrix at 0
  aborts, and `matrix-never` at 0 wins. `bodies` was re-pinned within one fight.
- **Against the cook** (player AI-driven, `ai`/`mash`/`never` win rates): sparks .50/.50/0,
  freeze 0/.25/0, selfburn .88/.50/0, artillery 1.0/.88/0, hotmelee .88/.12/0.
- **`demo-matrix` scores under `ai`:** selfburn .67, hotmelee .61, sparks .50, freeze .44,
  artillery .28. Player win rate `ai`/`mash`: sparks .30/.45, freeze .05/0, selfburn .70/.75,
  artillery .20/.30, hotmelee .40/.20.
- **`bodies`:** Cutter .38, Dozer .53, Corsair .59. Pairs: Cutter–Dozer .41, Cutter–Corsair .34,
  Dozer–Corsair .47. MAD .094 against the box control's .042. The Dozer flipped in 7 of 16
  Cutter–Dozer fights.

**What holds:** `never` wins no fight. hotmelee needs the button (`ai` beats `mash` by 75 points
against the cook and 20 in the matrix). selfburn needs it against the cook (+38). No body is
above 65%. Shaped bodies are further from even than the box control.

**What doesn't hold, and why (measured):**

- **`ai` ≈ `mash` for sparks, freeze and artillery, and in the matrix for selfburn.**
  - Brawlers fight in contact, so every melee part is always in reach. In contact, mashing spends
    the same energy as waiting.
  - The AI counts a Rocket as "in reach while facing". Its straight shot hits the noisy ground at
    range: 38% of `ai` Rockets hit against 83% under `mash` (sparks vs cook), because `mash` mostly
    fires them in contact.
  - Making the dear part better per energy (Rocket 25 dpe against Chainsaw 12) did not change this.
    A test rule giving the Rocket a 60-cell reach in `should_press` did not help either; it was not
    kept.
  - The press only pays where the dear part has a long cooldown and a big hit: Hearth and Ring.
- **Band 0.35–0.65:** artillery is at .28 and selfburn at .67. The Flamethrower's damage is the
  behaviour's hard-coded `PULSE_DAMAGE` (5 × 9), not `def.damage`, so raising its def damage did
  nothing (left at 45 / 2 energy). *(Resolved in the fix round below: the pulses now read
  `def.damage`; the Flamethrower is 72 and artillery is at .38.)*
- **freeze (the only Dozer build) barely wins.** The Tower spends most fights flipped (40–58 s in
  the matrix). It wheelies over when it lands with its motor running.
- **No body cycle.** Every body spends 25–40 s of a fight flipped, mirrors included, so most pairs
  draw and pair scores sit near .5. Regen is the one knob that moved a pair: Wedge regen 2.5 / 3.0
  gives Barge-beats-Wedge .81 / .50. Neither Wedge > Tower nor Tower > Barge reached .6 in any try.
  - The Tower's guns can't hit a Wedge. Rockets at range hit the ground, so a kiting Tower is safe
    from the Wedge's guns too.
- **The `standalone` suite no longer measures DPS.** The Cutter flips itself against the dummy
  Tower (23–46 s flipped), which leaves part DPS at 0–4. Damage per energy per firing is 10–17.

**Needs a call:**
1. Body stability: the self-flips and the Tower's landing wheelie. These are shape or physics
   work, not numbers.
2. A reach for straight-shot parts in the press rule, or a Rocket that arcs.
3. ~~The Flamethrower and the Hearth reading `def.damage`.~~ **Resolved** in the fix round below: their pulses now split `def.damage`.
4. Whether the press criterion is meant to hold for melee brawlers at all.

**Fix round (same day):**
- **Pulse damage.** The Flamethrower's and the Hearth's pulses now split `def.damage` over their 9
  pulses (`pulse_damage()`; 45 → 9 x 5, so nothing changes at the old data).
- **Flamethrower re-tune:** damage 45→72, cost still 2. Artillery moves into the band at .38. Matrix
  scores are now sparks .50, freeze .41, selfburn .67, artillery .38, hotmelee .55; selfburn is
  the only build still outside 0.35–0.65.
- **`standalone`** now fights a plain-hull dummy Corsair, with the player on a plain hull too.
  - Under the shaped hulls the Cutter flipped itself: 11–46 s per fight at 2729c8a and at this task
    alike, so the suite measured flips rather than DPS.
  - With plain hulls, part DPS is: Flamethrower 21.3, Ring 12.9, Rocket 8.3, Chainsaw 4.7, Hearth
    2.7, Firebolt 2.0, Mace 0, Harpoon 0.2 (see the Task 9 report).
- **Known fails:** every criterion the suites pass while failing is listed in
  `tools/balance/README.md`, "Known-fail (Task 9)". `analysis/summary.py --press-gap` checks the
  `ai`−`mash` gap on a `demo` or `demo-matrix` run.
