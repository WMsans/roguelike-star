# RoguelikeStar — Core Mechanics

This document records the concepts of the game as decided so far. Each section marks its
statements as:

- **Decided:** settled by the designer.
- **Proposed:** a working assumption agreed during design, which can still be changed.
- **Open:** not decided yet.

For the first playable slice, see `docs/superpowers/specs/2026-11-02-battle-slice-design.md`.

---

## 1. The game in one paragraph

A deckbuilder roguelike with a Balatro-style run loop. The player owns a **machine chariot**
and fights procedurally generated enemy chariots in a **falling-sand simulated arena**. Between
battles, a multi-stage **shop phase** lets the player buy, swap and sell parts to rebuild the
chariot. The core fun is **chains between parts**, **the sand sim reacting to what parts do**,
and **managing resources**: energy in battle; gold and inventory space in the shop.

**References**
- **Balatro:** the run loop, chains between items, inventory pressure and selling.
- **CATS: Crash Arena Turbo Stars:** auto-firing machine parts, slot-based chariot building,
  the battle feel.
- **The Bazaar:** proximity-based item interactions, item triggers and cooldowns.
- **Bad Piggies:** physical building, where positions matter.
- **Noita:** the falling-sand world, elemental reactions, and spell-like part behaviour.

---

## 2. Run structure

**Decided**
- A run is a sequence of **battle → shop phase** rounds.
- **Every 3rd battle is an elite. Every 3rd elite is a boss.** That gives 3 × (2 battles +
  1 elite) followed by the boss, with the boss as the last fight.
- **Defeating the boss wins the run.** Losing a battle (HP reaches 0) ends the run.
- **No map.** The run is a fixed linear sequence of fights.
- **HP does not carry over between battles,** as in Balatro and The Bazaar. Every battle starts
  at full HP with the build intact.
- **Each elite has a modifier** that changes the rules of that fight, like Balatro's boss blinds.
  Examples: fire damage is reduced; the enemy must be killed within a time limit; chains are
  weakened.

**Open**
- The full list of elite modifiers, and whether the player sees an elite's modifier ahead of time.
- Whether the boss has a modifier too (like Balatro's showdown blinds), and how it differs from
  elites.

---

## 3. Battle

### 3.1 Win condition

**Decided**
- Each chariot has one **HP** number on its body. **HP reaching 0 is the only win/lose
  condition.**

**Proposed**
- If both chariots reach 0 HP on the same tick, the player loses.

### 3.2 Control

**Decided**
- The player only **drives left and right**.
- **Parts fire on their own**, on cooldowns or on triggers, as in CATS. The player doesn't fire
  parts manually.
- The enemy chariot follows the same rules.

### 3.3 Energy

**Decided**
- **Everything costs energy, including moving.**
- When a part is ready but energy is short, it **waits in line** until energy regenerates.
  Nothing stalls, overheats or breaks from running out of energy.
- **Driving is paid first.** While the player holds a direction, driving takes energy before
  the waiting parts are paid. Moving visibly costs firepower, and that trade-off is the main
  live decision in a battle.
- Trigger effects usually cost energy. Passive effects usually don't. **More powerful parts cost
  more energy.**

**Proposed**
- The body sets **energy capacity** and **regen per second**.
- Waiting parts are paid in strict first-in, first-out order.
- Driving costs a flat amount per second (2/s in the slice), whatever the number of wheels.

### 3.4 Physical damage to parts

**Decided**
- Reactions from the sand sim (fire, ice, lava, cutting) **physically damage parts**, but this
  is **not a win condition**.
- Example: a frozen or burned-up wheel stops the chariot driving, while its weapons keep firing.
- **A hit on a part** lowers chariot HP by the full damage, *and* wears down that part. Parts
  don't act as armour that shields HP.

**Proposed**
- Each part has its own **integrity**, separate from chariot HP. At 0 the part **breaks**: it
  stops working for the rest of the fight and falls off, together with anything mounted on it.
- **Part damage lasts for one fight only.** Every battle starts with the build intact. Lasting
  damage could come later, but only as a deliberate mechanic (for example a cursed relic).
- **Burning** deals damage over time to chariot HP while any of its parts is burning.
- **Frozen:** a frozen wheel's motor locks, and a frozen weapon's cooldown pauses. Freeze wears
  off over time.
- **Water** puts out a burning chariot, which gives driving a defensive use.

### 3.5 Arena

**Decided**
- A **closed pit** with **indestructible concrete walls** on both sides and concrete beneath,
  so nothing can escape sideways or downward.
- The surface is terrain of **sand, wood and water pools**. Below it is **solid stone with lava
  pools**. There are **no caves**.

**Proposed**
- About 1.5 screens wide (≈480×180 cells at a 320×180 resolution), with a camera that keeps both
  chariots in view.
- Lava comes into play only once blasts or cuts dig down to it. Late fights can then turn into
  unscripted hazards: wood catches fire and water boils into steam.

**Open**
- Whether arenas vary by battle, elite or boss (biomes, themed terrain).

---

## 4. The chariot

### 4.1 Bodies and slots

**Decided**
- Building is **CATS-style with slots**, not Bad Piggies crates. A **body** has fixed slot
  positions, and parts snap into slots.
- **Slots are untyped.** Any part can go in any slot. A wheel mounted on top just spins in the
  air.
- **Position matters physically:** where a part sits decides where it fires from, what it touches in
  the sand, and what gets hit first.
- **Extension slots:** some parts carry their own slots, so a build can branch outward from the
  body. A chariot is a tree of parts.
- **Swapping bodies keeps parts as best as it can.** A new body is a choice, not a reset.
- **Facing:** each part fires the way it faces on its slot. The player can flip a part
  left/right by clicking it in the garage. Parts can't be rotated, and nothing auto-aims.

**Proposed**
- **Bodies** differ in shape, HP, energy capacity and regen, and in how many slots they have
  and where. A new body therefore means a new layout possibility.
- On a body swap, parts move to the nearest slot by position, and each part takes everything
  mounted on it along. Parts that don't fit go back to inventory.
- **Wheels are ordinary parts.** A chariot with no wheels on the ground can't drive but still
  fights.
- The enemy chariot is mirrored so that its parts face the player.

### 4.2 Parts

**Decided**
- Each part has a **trigger effect** and/or a **passive effect**.
- Trigger effects usually cost energy; passive effects usually don't.
- More powerful parts cost more energy.

- Each part has a **rarity**: common, uncommon or rare.
- **Parts never change.** There are no upgrades or levels: a Chainsaw found at the start of a run
  is identical to one bought near the end. Power over a run comes from *which* parts you hold and
  how you combine them.

**Proposed**
- A part's data: rarity, tags (element, kind), energy cost, cooldown, damage, integrity,
  proximity range, extension slots, charges (for limited-use parts), and its chain hook.
- Tags drive shop themes. A "fire shop" offers parts tagged fire.

### 4.3 Inventory

**Decided**
- **The inventory is limited.** The player has to **sell** extra parts, as in Balatro. Selling is
  a resource decision and can also be a chain trigger.

- **Inventory size: 5.** Parts mounted on the chariot don't count toward it.

**Open**
- Whether inventory can be expanded.
- Sell value (for example half the buy price).

---

## 5. Chains

The heart of the game. There are two kinds, and they combine.

### 5.1 Proximity chains (Bazaar-style)

**Decided**
- A part affects other parts **within a physical distance** on the chariot.
- Example: "Weapons within range also freeze what they hit."

### 5.2 Event chains (Balatro × Noita)

**Decided**
- A part **listens for an event happening anywhere** and reacts.
- Events can come from the **sand sim**, from **combat**, or from the **shop**.
- Reactions don't have to be elemental. Examples from the design:
  - "Spawn some fire." + "When something catches fire, gain energy."
  - "When selling parts related to fire, gain 2 HP and 2 extra gold."
  - "When defence items are triggered, gain x extra defence against burning."

### 5.3 How they work together

**Proposed**
- Both kinds run on **one shared event system**. Every event carries its source part, position and
  side. Proximity is a filter on who receives an event.
- Example chain: spawn fire → enemy burns → "caught fire" event → a part gains energy → another part
  fires sooner → more fire.
- Event types: part fired, hit, caught fire, frozen, thawed, part broken, cells cut, energy
  gained. Shop events (part sold, part bought, shop entered…) join the same system.
- Chains are capped per event, so an infinite loop can't freeze the game.

**Anti-goal**
- Chains that exist only in tooltips. The player must **see** a chain happen in the fight.

---

## 6. Shop phase

### 6.1 Structure

**Decided**
- After each battle comes a shop phase of **4 stages**.
- **Stage 1 is fixed:** the player receives some gold.
- **Stages 2–4 each offer 3 options.** Each option leads to a different set of items or rewards.
- **Options 1 and 2 are random** and are never resource options.
- **Option 3 is always a resource option**: a non-combat reward.

### 6.2 Shops vs. packs

**Decided**
- **Shop:** spawns 3 items, each with its own price. The player buys any they can afford.
- **Pack:** costs some gold to enter, then offers 3 items, of which the player **takes one for free**.

### 6.3 Option themes

**Decided.** Each theme can appear as a shop or as a pack:

| Theme | Contents |
|---|---|
| Weapon | Weapons |
| Defence | Defence items |
| Skill | "Tricky stuff": utility and unusual effects |
| Chariot body | Bodies |
| Attack | Attack items (pack form named in the design) |
| Fire | Fire-related items |
| Ice | Ice-related items |
| Wind | Wind-related items |
| Relics | Relics |
| Stats | Basic stat boosts |
| Passive | Parts with passive effects |
| Triggered | Parts with trigger effects |

### 6.4 Resource options (always option 3)

**Decided**
- Non-combat rewards, for example **extra gold** or **revive health**.
- **Revive health increases maximum HP** for the rest of the run. Since HP resets each battle,
  this is a permanent boost to every later fight.

**Open**
- The full list of resource options.
- Whether rerolls exist.

### 6.5 Gold and prices

**Decided** (starting values, to be tuned)

| | Gold |
|---|---|
| Starting gold | 20 |
| Reward for a normal battle | 5 |
| Reward for an elite | 10 |
| Common item | 2 |
| Uncommon item | 3 |
| Rare item | 4 |
| Pack entry | 3 |

**Proposed**
- Stage 1 of the shop phase (the fixed gold stage) pays the reward for the battle just won.

### 6.6 The garage

**Decided**
- The garage is where the chariot is edited. The slice builds it standalone, and it will be
  **reused in the shop phase**.

**Proposed**
- Its interface: an inventory and a chariot layout go in, and an edited layout comes out. The shop
  phase supplies the inventory, and the battle reads the layout.

---

## 7. Elements and the sand sim

**Decided**
- The falling-sand environment is part of the core fun, Noita-style.
- Element themes named so far: **fire, ice, wind**.

**Proposed**
- Materials in play: sand, wood, water, oil, rock, lava, fire, smoke, steam, frost, ice, concrete.
- **Fire:** ignites wood and oil, turns water into steam, is put out by water.
- **Ice / frost:** freezes water into ice and freezes parts. Fire thaws it.
- **Explosions** dig terrain (except concrete) and often start fires.
- Lava is under the arena surface and can be exposed by digging.

- **Wind only interacts with smoke, gas and steam.** It moves those around, and nothing else.

**Open**
- Other elements (acid is available in the engine).

---

## 8. Enemies

**Decided**
- Enemy chariots are **procedurally generated**, and are "similar" to the player's: same rules,
  same kinds of parts.

**Proposed**
- An enemy is described in the same layout format as the player's chariot, so the generator outputs
  a layout.
- Simple driving AI: approach until in weapon range, then hold position. It obeys the same energy
  rules.

- **Enemies get stronger by getting rarer parts** as the run goes on. Because parts never change
  (§4.2), the rarity mix and the builds are the only difficulty curve.

**Open**
- The exact rarity mix per fight, and how elites and bosses are built beyond their modifiers.

---

## 9. Starting content (first slice)

**Decided.** The parts are the designer's selection. The chain hooks were agreed during design.

**Bodies:** Cutter (small and fast), Dozer (round and stable), Corsair (long, tough, can flip).

| Part | Source | What it does | Chain hook |
|---|---|---|---|
| Ice Cream Mace | CATS | Cheap contact blade | Shatter: ×3 damage to a frozen part, ending its freeze |
| Cutter Chainsaw | CATS | Long-reach melee | Sparks: cutting throws sparks that ignite flammables |
| Flamethrower | CATS | Fire burst; the target keeps burning | — (elemental by itself) |
| Hearth | CATS | Charges up, then makes its own chariot burn everything touching it | — |
| Cutter Rocket | CATS | Fires about once a second; blasts terrain | Ignition: each time something catches fire, it recharges faster |
| Corsair Harpoon | CATS | Hooks the enemy and drags it closer | — |
| Ember Battery | Original | Passive | When anything catches fire, gain energy |
| Firebolt Launcher | Noita Firebolt | Lobbed exploding fireball; limited charges | — |
| Ring of Fire | Noita Circle of Fire | Expanding ring of fire; **hits its own chariot too** | — |
| Freeze Charge | Noita Freeze Charge | Proximity: weapons within range freeze what they hit | Proximity modifier |
| Wheel | — | Drives the chariot | — |
| Strut | — | Frame with 2 extension slots | — |

**Chains the starting set is built to show**
1. Chainsaw sparks → enemy burns → Ember Battery gives energy, and the Rocket recharges faster.
2. Freeze Charge near weapons → the enemy wheel freezes → the Harpoon drags it in → the Mace shatters.
3. Hearth or Ring of Fire burns your own chariot → the Ember Battery pays you for the risk.

The CATS and Noita names and behaviours are prototype placeholders. A released game needs
original names and art.

---

## 10. Design principles

- **Placement must matter.** If every layout plays the same, the slot system has failed.
- **Chains must be visible** in the fight, not only in text.
- **The player must be able to tell why they won or lost.** Energy, HP, part states and waiting
  parts are readable on screen.
- **Builds are choices, not resets.** Body swaps keep parts. Selling is a decision, not cleanup.
- **The sim is a participant.** Terrain, fire, water and lava can turn a fight in ways nobody
  scripted.
