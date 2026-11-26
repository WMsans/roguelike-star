# All parts, statuses and enemies design

Date: 2026-11-25. Branch base: `main`.

## Intent

Make every part in [`docs/design-doc/parts-list.md`](../../design-doc/parts-list.md) (169 parts: 43
common, 88 uncommon, 38 rare) work in the game as its Effect column says, so that a **full run can be
playtested with all 16 target builds** (parts-list §2). The point is to learn whether the builds work
and how they compare, not only whether each part fires.

Today the game has 12 parts that are not on the list, two statuses (a burning flag and a 0..1 freeze
meter), 15 materials, one enemy (the Cook) and one-button firing. The list assumes all 9 stacking
statuses from `elements-list.md`, materials the sim does not have yet (sparks, battery, steel, acid gas…),
many new trigger types, and run-long part scaling. So this is five stages that build on each other:

1. Statuses
2. Materials and the sim
3. The firing rule
4. The parts, in batches by build
5. Enemies: a generator and 19 archetypes

Every stage ends with the game playable and the test suite green.

Success:
- A run can be started, and each of the 16 builds can be assembled from what the shop offers.
- Every part does what its tooltip says, and one test per part proves its effect.
- The balance runner fights every enemy archetype.
- No combination of parts hangs a fight.

## Decided by the user

- **All 169 parts**, behaving as `parts-list.md` describes, with the firing rewording below.
- **The firing rule stays one-button** (the newer `core-mechanics.md` §3.2 rule wins over
  parts-list §1.2):
  - A press fires every ready **cooldown** part, the way it does now: dearest first, a part that
    doesn't fit is skipped, nothing carries over.
  - **Continuous** parts (CD column `Melee` or `Beam`, and the Fan) run **while the button is held**,
    paying their energy per second.
  - The energy-queue parts are reworded for volleys:
    - **U60 Priority Relay:** neighbours are paid first in a volley, ahead of the dearest-first order.
    - **R28 Blood Cell:** a part a volley can't afford fires anyway, and you lose 10 HP for each
      energy you were short.
    - The trigger "a part starts waiting in the energy queue" becomes **"a part is skipped in a volley"**.
- **Retire today's 12 parts** (Cutter Chainsaw, Cutter Rocket, Corsair Harpoon, Ember Battery,
  Firebolt Launcher, Flamethrower, Freeze Charge, Hearth, Ice Cream Mace, Ring of Fire, Strut, Wheel).
  The bodies' starting loadouts and the enemies are rebuilt from list parts.
- **19 enemy archetypes: 3 weak, 10 normal, 6 elite/boss.** Each one is procedurally generated
  every fight from a list of parts it may use (`core-mechanics.md` §8: the generator outputs a layout).
- **Accepted from my proposals** ("correct, continue"):
  - The 6 elites/bosses split into 4 elites and 2 bosses.
  - Weak archetypes fight 1–2, normal archetypes fight 4, 5, 7 and 8. Elites are drawn for fights 3, 6
    and 9, and a boss for fight 10. No archetype repeats within a run.
  - An archetype is a name, a tier, one of the three bodies, a part pool themed on one or two builds,
    HP and a drive style.
  - The generator puts the pool's wheels on the body's lower slots and fills the rest from the pool.
    The rarity mix rises with the fight index (commons early, rares from the elites on). It is seeded
    by the run's seed, so a fight replays the same.
  - Elites and bosses keep the existing modifiers (`fire_halved`, `time_limit`, `chains_weak`).
  - The balance runner gets a suite that fights each archetype.
- **Not objected to** (proposed, then the conversation moved on):
  - Parts use the flat coloured placeholder the game already draws for a def with no texture.
    Sprites are a later project.
  - Build order: statuses, then materials, then parts batched by build.

## Approaches

The how-it-gets-built choice was for the 169 behaviours:

1. **One script per part, as today, on shared helpers** (picked by the user). Each part is a `.tres`
   def plus one script extending `ChBehaviour`. Common operations become `ChBehaviour` helpers. It
   matches the codebase, and any part reads on its own. Cost: the plain weapons become many
   near-identical small files.
2. **Shared weapon kinds plus per-part scripts.** About 6 generic scripts (projectile, lobbed, melee,
   beam, sprayer, wheel) configured from the `.tres`, with scripts only for the odd parts. Less
   repetition, but two ways to build a part.
3. **A trigger → scope → effect grammar from parts-list §1.4, read from data,** with an interpreter.
   The most uniform, but the biggest framework, and the odd parts fight the grammar.

The user picked 1. Every part gets its own script, even the one-line stat parts (Spare Cell,
Generator), so there is exactly one way a part is built.

## Goals, non-goals, anti-goals

**Goals:** the five stages below, with the docs updated to match (see "Docs to update").

**Non-goals:**
- Sprites for the new parts. Exception: where a list part matches a retired part's art, the sprite is
  reused (wheel → C39 Roller, strut → C42 Strut, cutter_chainsaw → C03 Chainsaw, cutter_rocket → C01
  Rocket Pod, flamethrower → C16 Flamethrower, corsair_harpoon → U77 Harpoon). My call.
- The rest of `shop-list.md`: its 15 option themes, rule options, resource options and act gates.
- Relics, new bodies, and lasting damage between fights.
- Retuning every number. The numbers in parts-list are a starting point. The balance suite should show
  where they are badly off, and fixing them is tuning work after this project.

**Anti-goals** (failures even if everything "works"):
- A part whose tooltip says one thing while the part does another.
- A combination of parts that hangs or stalls a fight. The bus cap must hold for every loop in
  parts-list §6.
- A status the player can't see. `core-mechanics.md` design principles: the player must be able to
  tell why they won or lost.
- Rules that apply to one side only. The player and the enemy run on the same rules, and the
  modifiers remain the only deliberate asymmetry.
- Old balance numbers silently trusted. The Cook tuning (`cdc3219`) assumed the old burn and freeze
  rules, so it is void.

## Constraints

- Godot 4, GDScript, the existing headless test runner (`tests/run_tests.gd`) and the balance runner
  (`tools/balance/`). Both must keep working headless.
- Fights are deterministic for a seed. Anything random draws from a seeded RNG.
- The `noita_engine` addon is ours to change. Commit `1396466` is the precedent for engine additions
  with tests in `tests/engine/test_engine_additions.gd`. Prefer GDScript over existing bindings
  (`get_material_at`, `set_cell`, `fill_circle`, `count_materials`, `spawn_particles`, `explode`,
  `displace_cells`, `body_contacts`). Add C++ only when per-cell GDScript would be too slow or can't
  reach the sim. The builder makes that call per feature.
- Every effect goes through `ChBattleContext` and `ChEventBus`: one damage entry point, one bus with
  its per-emit cap (`MAX_DELIVERIES`).
- Parts-list §1.3: parts never give Flame, Freeze, Acid, Wet, Oil or Shock directly. They spawn
  material cells, and statuses come from contact. Parts may give Block, Speedup and Slow directly.

## Design

### Stage 1: Statuses

The burning flag, the freeze meter and the chariot-wide burn tick (`ChDamage.burn_tick`,
`BURN_DPS`) are replaced by **9 stacking statuses** on every part and on the body. The rules are
`elements-list.md` §1 and §2, both the **Decided** and the **Proposed** lines:

- **What each does:**
  - Flame, Acid and Shock deal their stacks as damage each second.
  - Acid hits Block first.
  - Freeze pauses cooldowns and locks wheel motors.
  - Block absorbs damage.
  - Wet and Oil do nothing alone.
  - Speedup doubles cooldown speed and Slow halves it.
- **Decay:** every status except Block, Wet and Oil loses 1 stack per second. All statuses tick
  together on one shared once-per-second battle clock.
- **Cancelling:** Flame–Wet, Flame–Freeze, Wet–Acid and Speedup–Slow cancel one for one. New stacks
  cancel the opposite status first, and only the remainder is added. An oiled part can't gain Wet.
- **Doubling:**
  - Oil doubles Flame gained, up to its Oil stacks, using that Oil up.
  - Wet doubles Freeze gained the same way.
- **Shock jumps:** each touching part gains half, rounded down. Jumped Shock doesn't jump again,
  except from a Wet part, which passes it one more hop. "Touching" means the two parts' footprints are
  adjacent or overlapping (`ChBehaviour._part_box` grown by 1 cell). My call.
- **Where damage lands:** status damage on a part wears its integrity only. On the body it hits HP.
  Weapon hits still lower HP and integrity together (`core-mechanics.md` §3.4).
- **Body statuses:**
  - Freeze pauses energy regen.
  - Speedup doubles regen and Slow halves it.
  - Block protects HP.
- **Flame cancelling Wet** releases a puff of steam cells next to the part.
- **Block on a weapon hit:** Block on the part that was hit (the body's Block for a hull hit) absorbs
  the damage first. Only the remainder lowers HP and wears integrity. My reading of "absorbs damage on
  this part before integrity (or HP, on the body)".

**Material → status** (`elements-list.md` §5), once per second on the shared clock:
- A part gains the material's rate when at least one cell of it is in the part's sample rect.
- It gains double when more than half the rect is that material.
- Sparks give +2 Shock for each spark that reaches the part.

**Status → sim** (`elements-list.md` §6), once per second for each part holding the status:
- Flame ignites, sets off charges, boils and melts.
- Freeze makes ice from water.
- Acid dissolves one cell.
- Shock sparks into water or steel.
- Oil drips one cell every 2 seconds.

**Code shape (builder's call within this):** a status holder (a small class or a dictionary of 9
ints) on `ChPartRuntime` and on `ChChariotRuntime` for the body. It has one `gain(status, n)` entry
point that applies cancel, doubling and jump in that order and emits the events. `apply_sample`
becomes the once-per-second material read. `is_frozen()` becomes `Freeze > 0`.
`ChChariotRuntime.drive` and `tick_cooldown` read Freeze, Speedup and Slow.

**Events** (new `ChEvent` types, each carrying the part, side, position, status and amount):
- status gained
- status reached N
- last stack lost
- statuses cancelled (which pair, how many)
- doubling happened
- Shock jumped

`CAUGHT_FIRE`, `FROZEN` and `THAWED` are removed. The feedback profiles that listen to them
(`caught_fire`, `frozen`, `thawed`) move to "Flame gained from 0", "Freeze gained from 0" and "last
Freeze lost".

**Visibility:** each status on a part shows as a small coloured stack number on or next to it, and
the part tooltip lists them. `ChKeywords` gains an entry and colour for each of the 9 statuses. The
exact look is the builder's call, kept minimal.

### Stage 2: Materials and the sim

**Materials to add** to `game/materials/` and `game_set.tres`, per `elements-list.md` §3 and §4:
- electric spark (particle)
- battery (solid)
- steel (solid)
- acid gas (gas)
- coal (solid)
- flammable gas (gas)
- dirt (powder)
- obsidian (solid)

**Reactions to add:**
- lava + frost → obsidian
- acid dissolving releases acid gas
- a broken battery leaks acid
- fire or spark + flammable gas → medium explosion
- fire or spark + gunpowder / TNT → explosion, which sparks now set off as well as fire

**Sim behaviours that need real support:**
- **Sparks travel through water and steel,** reach parts (Shock), and set off gunpowder and TNT.
  Batteries emit a spark every second.
- **Hardness** per material (the table in `elements-list.md` §3). A dig or blast with power N removes
  only cells of hardness ≤ N, and never concrete. Explosion sizes dig small 2, medium 4, large 6. Parts
  that dig give their own number (Drill 5, Rotary Drill 7, Excavator 6, Demolition Charge 6,
  Earthquake 8).
- **Wind:** a force that pushes gases and fire particles in a direction, over a region, and nothing
  else. The Fan, Gust Cannon, Weather Vane and Toxic Tempest use it.
- **One explosion event** for every blast, carrying position, size and source side. It covers
  material blasts from `take_blasts` and part-made blasts. `ChHazards` damages parts and HP by size
  with falloff, as it does now for TNT and gunpowder, extended to the three sizes.

**Ownership: what counts as "yours"** (decided by the user, option A of three; the other two were
an owner on every cell, and only blasts a part makes directly). This governs R22 Blast Amplifier, R07
Storm Core, R09 Superconductor, U15 Chain Lightning and the explosion event's source side.
- **Yours:**
  - a blast one of your parts makes
  - a blast from TNT, gunpowder or a mine one of your parts spawned, whatever set it off
  - a blast that chains off one of yours: a blast reported by `take_blasts` in the same chain inside an
    owned blast's radius
- **Unowned:** terrain charges set off by fire, sparks or unowned blasts. Nothing traces fire or
  sparks through the sand back to a part.
- **"Your Shock"** means Shock on enemy parts.
- **U15's "Shock from these sparks"** means the Shock its firing throws at the part it hit. The builder
  picks how to attribute it (for example, Shock gained by that part within a short window after the
  hit).
- **No engine change:** `Cell` stays 8 bytes. Owned charges are tracked in GDScript by the cells or
  positions a part spawned, and the blast queue's order and positions give the chains.

**The arena** (`ch_arena_builder.gd`) gains some batteries, steel and water. `elements-list.md` §3 has
gunpowder, TNT and batteries in the terrain from the start, so the Shock and Demolition builds have
something to use. Amounts and placement are the builder's call.

### Stage 3: The firing rule

- **Input:** `ChBattleContext.tick` gets the button's **held** state per side as well as its press
  edge. The edge fires the volley as today.
- **Continuous parts** run on every tick the button is held.
  - They pay their `/s` cost per tick after the drive and after any volley.
  - A continuous part the pool can't cover this tick doesn't run this tick.
- **Melee continuous parts:**
  - Deal damage once per second of contact. A **tick** is a hit and a firing (`PART_FIRED`).
  - Freeze stops them, Slow halves the tick rate and Speedup doubles it (parts-list §1.2).
- **Beam continuous parts:**
  - Deal damage each second the target is in the beam. Each second is a hit.
  - Only switching on counts as firing: the first held tick after a release, or after the part
    couldn't be paid.
- **Wheels** cost their own `/s` while driving (parts-list En column, `core-mechanics.md` §3.3), summed
  over unbroken wheels. This replaces the flat `ChEnergy.drive_cost`. The `WHEEL_ID` check becomes a
  `wheel` tag. Driving is still paid first.
- **Triggered passives with an energy cost** (C10 Bayonet 1, C15 First Aid Kit 4, U77 Harpoon 3) pay
  when they trigger. If the pool can't cover it, they don't trigger that time. My call.
- **A forced fire** ("makes another part fire": R15 Meshing Gearbox, R33 Wrecking Gear, R27 Fusion
  Core) costs no energy and doesn't touch the forced part's cooldown. It still counts as firing for
  triggers. My call.
- **The ready outline** (`ChBattle._show_ready`) also lights continuous parts that would run if held.
- **Enemy AI:** `ChEnemyAI.should_press` keeps its rule, and a new hold rule makes the enemy hold
  while a continuous part is in reach and the pool is above a share of the per-second cost.
- **Weapon reach becomes its own field.** Today melee reach reuses `def.proximity_range`, but on the
  list the Rng column is the proximity-chain range (S 12, M 20, L 32). `ChPartDef` gains a `reach` in
  cells for weapons. `ChEnemyAI.reach` reads it, and its Harpoon special case goes away.
- **Melee reach is generous** (user: today's Cutter Chainsaw, at 14 cells, barely hits even from the
  front slot).
  - Melee weapons start at 24 cells of reach from the part's edge, and the contact test below proves
    it: every body pair lands a tick inside 10 seconds, most on the hull and three on the defender's
    leading wheel, which reaches 3–4 cells further out. C05 Stinger's "twice as far" is about 48.
  - The real requirement is a test, not the number: for every pair of bodies, a melee weapon on the
    attacker's front slot lands ticks once the two chariots have driven into contact.
  - Reach is raised until that test passes. The test lives with the Stage 3 work and re-runs whenever
    a body or a melee part changes.

### Stage 4: The parts

**Data.** One `.tres` per part in `game/data/parts/`:

| Field | Source |
|---|---|
| `id` | snake_case of the name (`rocket_pod`, `heat_shield`) |
| `rarity` | the section it's listed in |
| `tags` | the Tags column in lowercase. `passive` and `triggered` are not tags: the shop reads them from the firing mode |
| `energy_cost` | the En column. `/s` costs go in a per-second field |
| `cooldown` | the CD column |
| firing mode | a new `ChPartDef` field: `cooldown`, `melee`, `beam`, `passive` or `wheel` |
| `integrity` | the Int column |
| `proximity_range` | the Rng column: S = 12, M = 20, L = 32, `—` = 0 |
| `extension_slots` | as many as the Ext column says. Positions are the builder's call |
| `damage` | the effect's number, where there is one |
| `description` | the Effect text, marked up with `ChKeywords` tags |
| `size` and `color` | placeholder size by kind, and a colour by primary theme. Builder's call |

**Behaviour.** One script per part, extending `ChBehaviour`, in `game/battle/behaviours/parts/`. The
helpers grow on `ChBehaviour` as the batches need them. The likely set:
- scopes: neighbours within range, in front, behind, mounted on this, tagged, all own, enemy
- give a status
- spawn material cells
- fire a projectile or a lobbed charge
- cast a beam
- melee contact
- explode with a size
- gain energy, heal, gain gold

The exact API is the builder's.

**Triggers** (parts-list §1.4): new `ChEvent` types are added only as some part needs them. The ones
the list needs include:
- rammed the enemy
- went airborne, landed
- started or stopped driving
- energy full, empty, spent, gained
- HP fell below a threshold
- would die (a hook that can cancel the death)
- Block absorbed a hit, Block reached 0
- explosion
- cells dug or dissolved
- battery broke
- started or stopped touching a material
- reaction nearby
- part skipped in a volley

**Shop and run triggers** (sold, bought, rerolled, shop entered, pack opened, won a battle / elite /
boss, shop phase ended) reach parts both **in the inventory and mounted**. Battle triggers reach
mounted parts only (parts-list §1.4). They go through a run-level bus or direct calls from `ChRun` and
`ChShopPhase`. Builder's call.

**Run-long state:**
- `ChInventory.part_ids` and `ChSlotNode.part_id` hold ids only. Permanent scaling (U64 Piggy Bank,
  U65 Scrap Cannon, R29 Golden Gear) needs per-instance state that travels with the part between
  inventory and chariot, lasts the run, and is dropped when the part is sold.
- "Parts sold this run" is a counter on `ChRun`.
- The shop always offers base-state parts.

**Inventory and the Negative tag:**
- `ChInventory.capacity` is 5 plus 1 for each owned part with an "+1 inventory slot" effect. Those
  are U28 Bunker Frame, U66 Safe, U68 Collector's Shelf and R30 Bench Warmer.
- The extra slot counts while the part is owned, mounted or in the inventory. My call.

**Shop themes:**
- `ChShopPhase.THEMES` becomes the parts-list shop themes: weapon, defence, tricky, attack, fire, ice,
  wind, earth, electric, acid, stats.
- passive (firing mode `passive`) and triggered (any other mode) are computed from the mode, not from
  tags.
- body stays.
- The existing `MIN_MATCHING` rule decides which themes are in play.

**Special rules to honour:**
- **R37 Mimic Module:** copies the part directly in front of it: its behaviour, mode, cooldown and
  energy cost, with its own integrity. A Mimic copying a Mimic does nothing (parts-list §6).
- **U88 Hub Frame and R38 Exo-Frame** change proximity for parts mounted on them. Proximity checks go
  through one helper, so these two can hook it.
- **U86 Turret Mount:** a weapon mounted on it fires both ways at half damage.
- **R14 Citadel and R36 Guardian Core** redirect damage in `deal_hit` before Block and wear.
- **R30 Bench Warmer:** the passive effects of inventory parts work in battle. Those parts get
  behaviours with no body. Their scope helpers answer nothing physical, and their own-chariot effects
  still apply.
- **Loops** in parts-list §6 (Meshing Gearbox, Perpetual Gear with Gear Linkage, Bench Warmer, two
  Mimics) each get a test showing the fight keeps running under the bus cap.

**Batches.** Each batch is a stage of the plan that ends with its parts in the shop, tested and
playable:

| Batch | Parts | Why it sits here |
|---|---|---|
| 1 | All 43 commons | Universal. They create most of the helpers, and the starting loadouts come from them |
| 2 | Inferno, Deep Freeze, Steam | Stress the new status rules hardest |
| 3 | Shock Chain, Acid Eater | Need the new materials |
| 4 | Fortress, Thorns, Last Stand | Block and damage redirection |
| 5 | Grinder, Rammer, Sniper | Continuous parts, driving and reach |
| 6 | Demolition, Gale | Explosions, hardness and wind |
| 7 | Overclock, Reactor, Merchant | Speedup chains, volley energy, run state |
| 8 | Frames, R37 Mimic Module, R38 Exo-Frame | Mount and proximity rules |

**Retirement** happens in batch 1:
- The 12 old `.tres` files, their behaviour scripts, unused sprites and their tests are deleted.
- The three bodies' starting loadouts and the run's starting kit are rebuilt from commons.
- The bodies' HP, energy and regen move to the parts-list §1.1 scale (HP about 800, energy about 20,
  regen about 4/s). My call: the list's numbers assume that scale.

**Tests:** each part gets at least one test that its effect happens, using the existing headless world
helpers (`ChTest.make_world`) where the sim is involved.

### Stage 5: Enemies

- **`ChEnemyArchetype`** (a Resource, files in `game/data/enemies/`) holds:
  - id and display name
  - tier: `weak`, `normal`, `elite` or `boss`
  - body id
  - part pool (ids, optionally weighted)
  - HP
  - drive style (`brawler`, `kiter` or empty, which `ChEnemyAI.decide` already reads)
- **`ChEnemyGenerator.generate(archetype, fight_index, rng) -> ChChariotLayout`:**
  - puts wheels on the body's lowest slots, enough to drive
  - fills the remaining slots and any extension slots from the pool, drawing rarity by fight index
  - outputs a layout that `ChRun.enemy_layout` hands to the battle, mirrored as today
  - places parts randomly among the remaining slots (agreed). The builder may add simple
    sanity rules (a weapon must face the player, no wheel on a top slot).
- **`ChRun`** draws the run's 10 opponents from the tiers at the start of the run, from its seed:
  - weak: fights 1–2
  - normal: 4, 5, 7, 8
  - elite: 3, 6, 9
  - boss: 10

  No archetype repeats. `enemy_hp` uses the archetype's HP with the existing elite and boss
  multipliers.
- **The 19 archetypes:** each one is themed on one or two of the 16 builds, so that between them the
  archetypes test every build's counter-play (an enemy that stacks Block, one that hits often, one
  with packed parts for Shock, an Inferno Cook…). The roster and pools are the builder's to draft, and
  the balance suite to check.
- **`dozer_cook.tres`** is replaced by archetypes.
- **Balance:** a suite in `tools/balance/suites/` fights each archetype against a fixed set of player
  builds across seeds. Its first job is to flag archetypes that never or always win.

## Docs to update

- `parts-list.md`:
  - §1.2 and §1.4: the hold rule and the "skipped in a volley" trigger.
  - Rows U60 and R28: the reworded effects.
- `core-mechanics.md` §3.2: holding runs continuous parts.
- `elements-list.md` §3: the "In the sim today" list, once Stage 2 lands.

## Left to the builder

- Every number: cells spawned per firing (parts-list §6 asks for statuses near the old stack counts),
  placeholder sizes, extension slot positions, enemy HP and pools, arena amounts.
- The status holder's code shape, the helper API, which events exist (only those a part needs), and
  the run-level trigger delivery.
- GDScript or engine C++ per sim feature (sparks, hardness, wind).
- How statuses look on parts, kept minimal and readable.
- The 19 archetypes' names, themes and pools.

## Carried from Stage 1 (statuses, landed on `all-parts-statuses`)

These came out of the Stage 1 reviews. Each later plan picks up the ones in its stage.

**How the status second works:**
- Pass A: damage, then cell effects, for every holder on both chariots.
- Pass B: material gains, then decay.
- A status gained from cells that second skips its decay. So 1/s sources (ice, smoke) hold at 1 while touching, and fire nets +1 Flame per second.
- STATUS_LOST fires on every path to 0.

**Before Stage 4 batch 1:**
- Add a status-damage event. "HP fell below" triggers and fight-stats attribution need it, and today it emits nothing, so there is no pop-up.
- Unify `ChPartRuntime.status_box` with `ChBehaviour._part_box`, and `ChBattle.hull_box` with `_hull_box`.
- Feedback ignores body-holder events, so the hull gets no caught-fire, frozen or thawed beat.

**Design checks, answered by the user (2026-11-26): all intended.**
- A Frozen part over water turns the water to ice and then holds its Freeze for good, because the ice's +1 cancels the decay's −1.
- The Acid status dissolves arena sand and wood every second, so a chariot in the acid cistern reshapes the ground. It dissolves by a list, not by hardness: sand, dirt, wood, coal, gunpowder, TNT, battery and steel, never rock, so the cistern still holds.
- Wet never decays and has no cap.

**Polish:**
- Two opposing materials on one holder (fire and ice) still flap GAINED/LOST every second.
- Flame under `fire_halved` rounds per second, so Flame 1 still deals 1.
- Keyword texts leave out body effects: Freeze pausing regen, Speedup and Slow changing it.
- `sample_rect` ignores chassis rotation, and `touching` ignores part rotation.
- Wet and Freeze badges are both blue; revisit before the Deep Freeze batch.
- Badge rows of adjacent narrow parts can overlap.

## Carried from Stage 2 (materials, landed on `all-parts-materials`)

These came out of the Stage 2 final review. Stage 4 picks them up.

- Parts make blasts through `ctx.explode`, or pass an explicit dig to `world.explode`; never rely on the `-1` default (the old Rocket, Firebolt and Chainsaw still do, until they retire in batch 1).
- Material-blast EXPLOSION events have no source, so "explosion nearby" triggers subscribe chariot-wide and measure `event.position`.
- `discharge` will need an owner side (Wet Wire, R07), hops (U15), a stop-at-first-holder mode (U19) and a redirect hook (C24); TNT Launcher calls `own_charge` where the crate lands.
- Wind moves grid cells only; decide before the Fan whether in-flight fire particles should be pushed too.

**Design checks, answered by the user (2026-11-26):**
- Intended: the steel rails (hardness 7) shield the lava under x 210–223 / 256–269 from digs of 6 or less.
- Intended: acid eats battery, so a breached battery dissolves within a second or two and stops sparking.
- **R22 Blast Amplifier changes:** besides "explosions you cause are one size bigger", your parts and body take no damage from your own explosions **and none from environmental blasts** (unowned terrain TNT, gunpowder and flammable gas). Blasts the enemy owns still hurt. Stage 4 updates parts-list row R22 to match.
