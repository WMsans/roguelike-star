# RoguelikeStar: core mechanics

## Elevator pitch

RoguelikeStar is a deckbuilder roguelike with a run loop modelled on Balatro. The player owns a
machine chariot and fights procedurally generated enemy chariots in a falling-sand simulated
arena. Between battles, a shop phase in several stages lets the player buy, swap and sell parts
to rebuild the chariot. Most of the fun should come from chains between parts, from the sand sim
reacting to what parts do, and from managing resources: energy in battle, gold and inventory
space in the shop.

References:
- Balatro: the run loop, chains between items, inventory pressure and selling.
- CATS: Crash Arena Turbo Stars: auto-firing machine parts, slot-based chariot building, and
  the feel of battles.
- The Bazaar: proximity-based item interactions, item triggers and cooldowns.
- Bad Piggies: physical building, where positions matter.
- Noita: the falling-sand world, elemental reactions, and parts that behave like spells.

## 2. Run structure

- A run is a sequence of rounds, each a battle followed by a shop phase (battle → shop phase).
- Every third battle is an elite, and every third elite is a boss. A run is therefore
  3 × (2 battles + 1 elite) followed by the boss, which is the last fight.
- Defeating the boss wins the run. Losing a battle (HP reaches 0) ends it.
- There is no map. The fights come in a fixed linear sequence.
- HP does not carry over between battles, as in Balatro and The Bazaar. Every battle starts at
  full HP with the build intact.
- Each elite has a modifier that changes the rules of that fight, like Balatro's boss blinds.
  Examples: fire damage is reduced, the enemy must be killed within a time limit, or chains are
  weakened.
- Each boss also has a modifier, like Balatro's showdown blinds. Boss modifiers are stronger
  versions of some of the elite modifiers.

## 3. Battle

### 3.1 Win condition

- Each chariot has a single HP number on its body. HP reaching 0 is the only way to win or lose.

### 3.2 Control

- The player only drives left and right.
- Parts fire on their own, on cooldowns or on triggers, as in CATS. The player never fires parts
  manually.
- The enemy chariot follows the same rules.

### 3.3 Energy

- Everything costs energy, including moving.
- A part that is ready when energy is short waits in a queue until energy regenerates. Waiting
  parts are paid in strict first-in, first-out order.
- Driving is paid first. While the player holds a direction, driving takes energy before any
  waiting part gets paid. Moving visibly costs firepower, and that trade-off is the main decision
  the player makes during a battle.
- Driving costs a flat amount per second (for instance, 2/s) regardless of the number of wheels.
- Trigger effects usually cost energy and passive effects usually don't. More powerful parts
  cost more energy.
- The body sets energy capacity and regen per second.

### 3.4 Physical damage to parts

- Reactions from the sand sim (fire, ice, lava, cutting) physically damage parts, but part damage
  is not a win condition. A frozen or burned-up wheel, for example, stops the chariot driving
  while its weapons keep firing.
- A hit on a part lowers chariot HP by the full damage and also wears down that part. Parts do
  not act as armour that shields HP.
  - Each part has its own integrity, separate from chariot HP. At 0 the part breaks: it stops
    working for the rest of the fight and falls off, along with anything mounted on it.
- Part damage lasts for one fight only, so every battle starts with the build intact. Lasting
  damage could be added later as a deliberate mechanic, for example a cursed relic.
- Burning deals damage over time to chariot HP while any of its parts is burning.
- Freezing locks a wheel's motor and pauses a weapon's cooldown. It wears off over time.
- Water puts out a burning chariot, which gives driving a defensive use.

### 3.5 Arena

- The arena is a closed pit with indestructible concrete walls on both sides and concrete
  beneath, so nothing can escape sideways or downward.
- The surface is terrain made of sand, wood, water pools and other reactive elements. Below it is
  solid stone with pools of lava. There are no caves.
- The arena's layout changes as the game progresses.

**Proposed**
- About 1.5 screens wide (≈480×180 cells at a 320×180 resolution), with a camera that keeps both
  chariots in view.
- Lava comes into play only once blasts or cuts dig down to it. Late fights can then produce
  hazards nobody scripted, such as wood catching fire or water boiling into steam.

**Open**
- Whether arenas vary by battle, elite or boss (biomes, themed terrain).

## 4. The chariot

### 4.1 Bodies and slots

- Building works like CATS, with slots, rather than like the crates in Bad Piggies. A body has
  fixed slot positions, and parts snap into slots.
- Slots are untyped, so any part can go in any slot. A wheel mounted on top just spins in the air.
- Position matters physically. Where a part sits decides where it fires from, how it interacts
  with terrain, and what gets hit first.
- Some parts carry their own extension slots, so a build can branch outward from the body. A
  chariot is a tree of parts.
- Each part fires the way it faces on its slot. The player can flip a part left or right by
  clicking it in the garage. Parts can't be rotated, and nothing auto-aims.
- Bodies differ in shape, HP, energy capacity and regen, and in how many slots they have and
  where those slots sit. A new body therefore opens up new layouts.
- Swapping bodies keeps as many parts as it can, so picking a new body doesn't mean rebuilding
  from scratch. Parts move to the nearest slot by position, and each part takes everything
  mounted on it along. Parts that don't fit go back to inventory.
- Wheels are not necessary. They are ordinary parts, and like other parts they come in many types.
- The enemy chariot is mirrored so that its parts face the player.

### 4.2 Parts

- Each part has a trigger effect, a passive effect, or both.
- Trigger effects usually cost energy and passive effects usually don't. More powerful parts cost
  more energy.
- Parts never change. There are no upgrades or levels: a Chainsaw found at the start of a run is
  identical to one bought near the end. A build gets stronger over a run through *which* parts the
  player holds and how they combine them.
- A part's data: rarity, tags (element, kind), energy cost, cooldown, damage, integrity,
  proximity range, extension slots, charges (for limited-use parts), and its chain hook.
- Tags drive shop themes. A fire shop offers parts tagged fire.

### 4.3 Inventory

- The inventory holds 5 parts. Parts mounted on the chariot don't count toward it.
- Because space is limited, the player has to sell extra parts, as in Balatro. Selling is a
  resource decision and can also trigger chains.
- Sell value is half the buy price.
- The inventory can only be expanded by parts with the "negative" tag, similar to Balatro.

## 5. Chain reactions

Chains come in two kinds, and the two combine.

### 5.1 Proximity chains (Bazaar-style)

- A part affects other parts within a physical distance on the chariot.
  - Example: "Weapons within range also freeze what they hit."

### 5.2 Event chains (Balatro × Noita)

- A part listens for an event happening anywhere and reacts to it.
- Events can come from the sand sim, from combat or from the shop.
- Reactions don't have to be elemental. Examples from the design:
  - "Spawn some fire." + "When something catches fire, gain energy."
  - "When selling parts related to fire, gain 2 HP and 2 extra gold."
  - "When defence items are triggered, gain x extra defence against burning."

### 5.3 How they work together

**Proposed**
- Both kinds run on one shared event system. Every event carries its source part, position and
  side. Proximity is a filter on who receives an event.
- Example chain: spawn fire → enemy burns → "caught fire" event → a part gains energy → another
  part fires sooner → more fire.
- Event types: part fired, hit, caught fire, frozen, thawed, part broken, cells cut, energy
  gained. Shop events (part sold, part bought, shop entered…) use the same system.
- Chains are capped per event, so an infinite loop can't freeze the game.

## 6. Shop phase

### 6.1 Structure

**Decided**
- After each battle comes a shop phase of 4 stages.
- Stage 1 is fixed: the player receives some gold.
- Stages 2, 3 and 4 each offer 3 options, and each option leads to a different set of items or
  rewards.
- Options 1 and 2 are random. They are never resource options, never the same as each other, and
  never repeat an option from the previous stage.
- Option 3 is always a resource option, which gives a non-combat reward.

### 6.2 Shops vs. packs

**Decided**
- Shop: spawns 3 items, each with its own price. The player buys any they can afford, and can
  reroll once for gold.
- Pack: costs some gold to enter, then offers 3 items. The player takes one of them for free.
  Packs can't be rerolled.

### 6.3 Option themes

Each theme can appear as a shop or as a pack:

| Theme | Contents |
|---|---|
| Weapon | Weapons |
| Defence | Defence items |
| Tricky | "Tricky stuff": utility and unusual effects |
| Chariot body | Bodies |
| Attack | Attack items |
| Fire | Fire-related items |
| Ice | Ice-related items |
| Wind | Wind-related items |
| Earth | Terrain-related items |
| Relics | Relics |
| Stats | Basic stat boosts |
| Passive | Parts with passive effects |
| Triggered | Parts with trigger effects |

### 6.4 Resource options (always option 3)

- Resource options are non-combat rewards, such as extra gold or revive health.
  - Revive health raises maximum HP for the rest of the run. HP resets each battle, so the boost
    applies to every later fight.

**Open**
- The full list of resource options.

### 6.5 Gold and prices

| | Gold |
|---|---|
| Starting gold | 20 |
| Reward for a normal battle | 5 |
| Reward for an elite | 10 |
| Common item | 2 |
| Uncommon item | 3 |
| Rare item | 4 |
| Pack entry | 3 |

- Stage 1 of the shop phase (the fixed gold stage) pays the reward for the battle just won.

### 6.6 The garage

- The garage is where the player edits the chariot.
- It takes an inventory and a chariot layout and returns an edited layout. The shop phase
  supplies the inventory, and the battle reads the layout.

## 7. Elements and the sand sim

- The falling-sand environment is part of the core fun, as in Noita.
- Element themes named so far: fire, ice and wind.
- Materials in play: sand, wood, water, oil, rock, lava, fire, smoke, steam, frost, ice, concrete,
  acid, gas, acid gas, coal, dirt, obsidian, steel, and many more.
- Fire ignites wood and oil and turns water into steam. Water puts it out.
- Ice and frost freeze water into ice and freeze parts. Fire thaws them.
- Explosions dig terrain (except concrete) and often start fires.
- Lava sits under the arena surface and can be exposed by digging.
- Wind moves smoke, gas and steam around and affects nothing else.

## 8. Enemies

- Enemy chariots are procedurally generated and similar to the player's: same rules, same kinds
  of parts.
- An enemy is described in the same layout format as the player's chariot, so the generator
  outputs a layout.
- The driving AI is simple: approach until in weapon range, then hold position. Enemies obey the
  same energy rules, but the player cannot see their energy.
- Enemies get stronger over the run through rarer parts and more max HP. Because parts never
  change (§4.2), the rarity mix, the builds and body max HP are the only difficulty curve.
- Elites and bosses follow the same rules, but each one also gets a "blind rule" that handicaps
  the player in a particular way, similar to Balatro.

**Open**
- The exact rarity mix per fight.

## Design principles

- Placement must matter. If every layout plays the same, the slot system has failed.
- Chains must be visible in the fight as well as in text. When an ability triggers, the part
  reacts on screen, similar to the jokers in Balatro.
- The player must be able to tell why they won or lost. Energy, HP, part states and waiting parts
  are all readable on screen.
- The sim can change the outcome. Terrain, fire, water and lava can turn a fight in ways nobody
  scripted.
