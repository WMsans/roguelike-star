# The Cook and the arena: a fight worth building for

Date: 2026-11-10. Branch: `garage-battle-ui`.

## Intent

Playtesters find the combos fun (one played with the elemental reactions for about 20 minutes),
but the demo's only enemy, the Cook (`game/data/enemies/dozer_cook.tres`), is a pushover. A Corsair
with one Flamethrower or one Rocket on `[6]`, no wheels, spamming the button, beats it.

What the user wants:

- **A lazy build fails badly.** One gun, standing still, spamming should lose clearly, not draw
  and not scrape a win.
- **A proper full build still finds the fight difficult and strategic.**
- **Part of that difficulty comes from the simulated level.** The arena today is "very lame": a
  bumpy sand floor with two 1-cell water strips, two wood patches and lava 30 cells down. Nothing
  in it changes a decision.
- **The Cook and the arena are tuned together**, so that a new arena doesn't undo the Cook's tune.

The moments the user named as the target feel (not all are in scope, see Non-goals):

- Digging a hole, pouring frost in and melting it into a trap.
- Noita's TNT, acid and oil buckets and gunpowder piles: explosions everywhere.
- A chariot that hops behind the enemy to dodge its melee is a real tactic, and a Ring of Fire
  that punishes it is a real counter.

## What we measured (2026-11-10, current tree)

The runner (`tools/balance/run.sh`) ran a Corsair with one weapon on `[6]`, `press.player: mash`,
against the Cook, with 8 seeds:

| Build | W/L/D | Fight | Notes |
|---|---|---|---|
| Rocket, no wheels | 7/1/0 | 22 s | 42 DPS from one Rocket: the Cook drives into it, so nearly every shot hits |
| Rocket, wheels | 4/3/1 | 33 s | |
| Flamethrower, no wheels | 0/2/6 | 54 s | Mostly draws: the Cook deals about 12 DPS and can't kill a bare 900 HP Corsair in 60 s |
| Flamethrower, wheels | 0/3/5 | 50 s | |

Why it's weak:

- The Cook's HP went from 1800 to 700 in `0d2968b` (the press-volley re-cost).
- It's a Corsair brawler with Harpoon `[4]`, Hearth `[5]` and Mace `[6]`. **Slots `[2]` and `[3]`
  are empty**, and all of its damage is up close.
- **Standing still is free.** The Cook drives to you, so wheels are optional. With wheels you
  drive into its Hearth fire (lit 29–33 s per fight, against 2 s without wheels).
- The reference builds don't all win: the `demo` pins today are sparks .50, freeze 0,
  selfburn .88, artillery .88 and hotmelee .88 under `ai` presses.

What the engine does today (it bears on the arena):

- Materials and reactions are data (`PixelMaterial` and `PixelReaction` `.tres` in
  `game/materials/`, listed in `game_set.tres`). Burning, ignition, phase changes and decay already
  run in `addons/noita_engine/rules/chemistry.cpp`.
- **Nothing explodes on its own.** The only explosion is `PixelWorld.explode(position, radius,
  power)`, called from GDScript (`ch_rocket.gd`). It removes cells and throws powders and liquids.
  It pushes no bodies and ignites nothing.
- **Blasts don't hurt chariots.** A Rocket's blast digs; only its direct hit pays, through
  `ChBattleContext.deal_hit`, which needs a source part.
- Liquid deeper than about one cell floats a chassis off its wheels (`PhysicsWorld::apply_buoyancy`),
  which made deep pools act as walls (see `ch_arena_builder.gd`).

## Goals

1. **Lazy builds lose badly.** Every one-weapon Corsair (each of the 8 damaging parts on `[6]`,
   with and without wheels, `mash`) loses to the Cook in at least 7 of 8 fights, and the Cook ends
   with at least half its HP in the median fight.
2. **Full builds face a hard fight.** Each of the five `demo` reference builds beats the Cook
   40–70% of the time under `ai` presses, in fights of 35 s or more.
3. **Moving matters.** Each `demo` reference build without its wheels wins at least 0.25 less than
   the same build with them.
4. **The arena matters.** In the `demo` suite, hazard damage deals at least 10% of all damage
   taken, summed over both sides, and isn't zero for either side. *Hazard damage* means material
   blasts (§2) plus lava wear. Burn damage doesn't count, because burning carries no record of who
   lit it, so a weapon's fire and the arena's fire can't be told apart. Tracking who started each
   fire is out of scope. (My call.)
5. **The arena reacts the way the user pictured.** It has explosives that chain (gunpowder through
   a pile, TNT set off by fire or by another blast), oil that can be spilled and lit, acid that eats
   terrain, lava a dig can reach, and room to dig a pit and freeze it.

The numbers in 1–4 are my proposal (the earlier handoff used 55–85% for "every build beats the
Cook"; the user now wants it harder). Tune to them, and report any you can't reach rather than
bending the bound.

## Non-goals

- The booster part, a jump, and any other movement parts (the next project).
- Electric sparks, batteries, Shock and the Acid status on parts.
- A Cook AI that knows about hazards or lures you into them. The AI stays as it is (brawler drive,
  the enemy press rule).
- Arenas that vary by seed, biome or fight. One designed arena; the noise surface may still vary
  by seed.
- Fixing the freeze chain (handoff open problem 1) unless it is the only thing keeping the freeze
  build out of Goal 2's band. If it is, stop and report before changing any rules.

## Anti-goals (a failure even if every number passes)

- **The arena decides fights on its own.** If a chariot dies at its spawn to a crate it never
  touched, or the side that spawns nearer a hazard wins much more often, the level is a coin flip,
  not strategy. The layout is mirrored left-to-right, and no hazard goes off without a shot, a
  flame, a blast or a dig reaching it.
- **The Cook blows itself up.** If the Cook loses to its own Hearth lighting a TNT crate,
  standing still beats it again. Track Cook deaths where hazards dealt the killing damage; keep it
  under 1 fight in 4 per build.
- **A stat wall.** Raising the Cook's HP until nothing but sparks wins. The Cook should get more
  dangerous, not only tankier.
- **A slideshow.** A long gunpowder chain must not drop the game under 60 fps or make the runner's
  60 s fight take much more than its current ~1.5 s.
- **A wall of liquid.** No pool deep enough to float a chassis sits where chariots have to drive.

## Constraints

- Godot 4 with the project's `noita_engine` GDExtension (`addons/noita_engine`, rebuilt with
  `addons/noita_engine/build.sh`). Engine additions get a test in
  `tests/engine/test_engine_additions.gd`, in the style of the ones already there.
- The full test run (`godot --headless --path . --script res://tests/run_tests.gd`) ends `0 failed`.
  Tests that pin old arena or Cook numbers are updated to the new values, keeping what each test's
  comments say it checks.
- Balance runs go through `tools/balance/run.sh` (it sets `--fixed-fps 60`, which reproduction needs).
- The Cook uses only parts in the catalog, at most two of each, and keeps the Corsair body and its
  fire-cook identity (Hearth stays).
- Spawns stay hanging in air (`ch_arena_builder.gd` explains why), and both chariots must still be
  able to drive off their spawn ground.
- The one-button rules (`core-mechanics.md` §2) don't change.

## Approaches

The user picked **A**.

- **A. Explosives built into the sim, plus a hand-built arena and a re-armed Cook (picked).**
  Materials get an "explodes" setting in C++. A lit explosive cell goes off and reports the blast to
  the game, which deals the damage and knockback. Gunpowder chains through a pile, and any TNT
  works, including TNT that a blast uncovers or acid exposes. Cost: an engine change, a rebuild and
  engine tests.
- **B. No engine changes.** GDScript remembers where each TNT crate was placed and checks each tick
  whether it's burning. Cheaper, but only placed crates explode, gunpowder can't chain (too many
  cells to watch), and spilled or uncovered explosives never go off. Dropped because it loses the
  Noita chaos the user asked for.
- **C. Like A, with set pieces placed at random from the fight seed.** More variety, but every seed
  is a different fight, so the Cook's tune needs many more runs and gets noisy. The game uses one
  fixed seed (`ch_main.gd` `SEED`), and `core-mechanics.md` puts arena variety later in the run.
  Dropped.

## The design

### 1. Explosive materials (engine)

- `PixelMaterial` gains two fields, `explode_radius` (int, 0 = doesn't explode) and
  `explode_power` (float), carried into `MaterialDef`.
- An explosive cell detonates when it is burning (it reached its `ignite_temperature`, so fire,
  lava, burning oil and hot blasts set it off through the existing heat rules) or when another
  blast covers it. Detonating removes the cell and runs the existing `explode` at that cell.
- **Blasts chain.** Explosive cells inside a blast detonate on a later tick (a short fuse, so a
  gunpowder pile ripples rather than going off in one frame) instead of vanishing.
- **Blasts start fires.** Cells that can ignite near the blast's edge are heated past their ignite
  temperature (`core-mechanics.md` §7: "Explosions dig terrain and often start fires").
- **The game hears about every blast.** `PixelWorld` reports each blast of the tick (position,
  radius, power), whether a material or `explode()` caused it, for example as a signal or a
  per-tick list. Either works; the builder chooses.
- **A budget.** Detonations per tick are capped. Neighbouring gunpowder cells that go off on the
  same tick may merge into one blast, so a chain costs about the same however big the pile is. The
  cap and the merge rule are the builder's to set against the 60 fps and runner-speed anti-goal.

Materials (data, in `game/materials/` and `game_set.tres`; numbers are the builder's to tune):

| Material | Class | Explodes | Notes |
|---|---|---|---|
| Gunpowder | Powder | small radius (about 3) | Lights easily; chains through a pile |
| TNT | Solid | large radius (about 10–14) | Placed as crates; lit by fire or by a blast |
| Acid | Liquid | no | Reactions dissolve sand, wood, gunpowder and TNT into air plus a little smoke (no acid gas this project). Not rock: rock is what holds acid in the arena's basins (plan-time call) |

Acid touching a chariot does nothing in this project (Acid status is a non-goal). It changes the
terrain only: it opens pits, uncovers TNT and lava, and eats ledges.

### 2. Blast damage and knockback (game)

- The fight turns each reported blast into damage and a push on every chariot within its radius:
  full damage at the centre, falling to none at the edge, plus an impulse away from the centre at
  the hull's own centre (the way `ch_harpoon.gd` applies its pull).
- This damage has **no source part**. It goes through the same damage entry point as hits, so HP,
  Block-style rules, the HUD, popups and events all see it. A blast caught by a part damages that
  part's integrity the way a hull or part hit does today. The builder decides how `deal_hit` (or a
  sibling) takes a hit with no source.
- **The Rocket keeps its own numbers.** Its blast still reports (so it sets off TNT and starts
  fires), but its own explosion deals no area damage to chariots; only its direct hit pays, as
  today. Rocket damage is tuned, and area damage on top would re-open the Rocket cheese. Area damage
  comes only from material blasts.
- **Chariot HP pays once per blast**, scaled by the hull's distance from the centre. Each part
  inside the radius loses integrity only, so a blast over a 6-part chariot doesn't cost 6× the HP.
  (My call.)
- `ChFightStats` records, per side, hazard damage as Goal 4 defines it (`hazard_damage`: material
  blasts and lava, not burn) and whether the killing damage was hazard damage (`killed_by_hazard`).
  It stays separate from the existing `unattributed_damage`, which includes burn. The README documents both.
  `analysis/summary.py` prints them.

### 3. The arena

One hand-designed layout built by `ChArenaBuilder`, **mirrored left-to-right** around x 240. The
surface noise stays, seeded as today. Keep the spawns at x 170 and 310. The set pieces (sizes and
exact placement are the builder's, tuned against Goals 3–5 and the anti-goals):

- **A thin crust over lava in the middle.** A lava pocket a few cells under the surface between the
  spawns, so a Rocket, a Chainsaw cut or a TNT blast exposes it. Lava under where the chariots
  fight makes digging a risk to both sides.
- **TNT crates on each flank**, half-buried, a few cells of sand over them, clear of the spawn
  footprints. Nothing sets them off but a shot, a flame or a dig reaching them.
- **A gunpowder seam** just under the surface, running from each crate toward the middle, so a lit
  seam walks a fuse to the crate.
- **An oil tank on a raised ledge** at each end: a wood-walled tank of oil on a rock shelf near the
  arena walls. Breaking or burning the wall spills oil downhill toward the middle, and lit oil is a
  moving fire.
- **A sealed acid pocket** in the rock on each side, behind wood or sand, so a dig or a blast
  releases acid that eats down toward the lava or a crate.
- **Room to dig a trap.** Plain sand in the stretch between the spawns, deep enough (about 10
  cells) for a pit that frost fills and that holds a chariot, so the frost trap the user described
  is possible.
- **No liquid deeper than about one cell on the driving line.** The oil and acid sit off it or
  below it until something lets them out.
- Today's water strips, wood patches and deep lava pools are replaced or kept as the builder sees
  fit, as long as the anti-goals hold.

Tests in `tests/battle/test_arena.gd` that pin the old layout move to the new one. Add a test that
the layout is mirrored (material counts left and right of x 240 match), and one that each chariot
still drives off its spawn.

### 4. The Cook

- **HP back up**, in the range the earlier tune found (it was 1800; the builder tunes it). This
  must not be the main lever (anti-goal: a stat wall).
- **Fill `[2]` and `[3]` with reach.** Today it only hurts what touches it. Proposed: a Firebolt
  Launcher (lobbed fire, hits a chariot that holds still at range and lights the terrain around
  it) and a Ring of Fire (punishes a chariot that hops or hugs it, which is the counter the user
  named). Swaps are open if another catalog part reaches the goals better; the Hearth stays.
- **The Cook's fire is part of the arena.** Its Firebolt landing near a gunpowder seam or an oil
  spill is intended. Its Hearth setting off a crate under itself is the anti-goal to watch.

### 5. Balance tooling

- A new suite, `tools/balance/suites/lazy.json`: a Corsair with each of the 8 damaging parts alone
  on `[6]`, with and without wheels, `press.player: mash`, against the Cook, 8 seeds. `expect`
  holds Goal 1.
- **The player's test driver may change; the Cook's AI may not.** Each `demo` reference build may
  drive with whichever existing drive style suits it (`brawler` or `kiter`, from `ch_enemy_ai.gd`)
  instead of always closing in, and the builder may add a player drive policy to
  `ChBalanceDrivers` if a goal can't be measured without one. Otherwise Goal 3 only measures what a
  charging driver does with wheels. (My call.)
- `demo.json` gains a no-wheels twin of each reference build (Goal 3). Its `expect` ranges are
  re-pinned to the final values, and they hold Goal 2's band.
- `demo-matrix`, `bodies` and `standalone` run on the new arena too. Rerun them and re-pin. The
  round-robin band (every build 0.35–0.65) should still hold.
- **Part numbers are a main tuning lever (user's decision).** Tune parts alongside the Cook and the
  arena, not as a last resort. The single Rocket that the Cook drives into is the clearest case
  (for example, less damage at point-blank range). Keep the standalone baseline in view: a common
  weapon deals 10–20 DPS, at roughly equal damage per energy (`parts-list.md` §1.1). Behaviour
  constants in `game/battle/behaviours/` count as part numbers.
- A tuning log row and an updated Known-fail table in `tools/balance/README.md`, in the existing
  format.

### 6. Docs

- `core-mechanics.md` §3.5 (Arena) and `elements-list.md`: say which materials and reactions are now
  in the sim (gunpowder, TNT, acid dissolving terrain) and that blasts hurt chariots and chain.
- Update the tooltip copy (the `description` lines in each part's `.tres`) for every part whose
  numbers or behaviour change. Tooltip tests that pin old numbers move with them.

## Left to the builder

- Every number: part costs, damage, cooldowns and reach; material densities, ignite temperatures, blast radii and power, the fuse, the
  per-tick cap, the blast damage and falloff, the impulse, the Cook's HP, and set-piece sizes and
  positions.
- How the engine reports blasts (signal or per-tick list) and how no-source damage enters the
  damage path.
- Which old arena features stay.
- The Cook's exact `[2]`/`[3]` parts, within §4.
- The order of work. Suggested: engine explosives and their test; blast damage; the arena; then
  tuning the Cook and arena together with the runner.
