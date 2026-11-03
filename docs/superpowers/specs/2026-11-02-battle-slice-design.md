# Chariot Battle Slice — Design

Date: 2026-11-02
Project: RoguelikeStar (Godot 4.7, `addons/noita_engine`, 320×180 viewport)

## 1. Intent

The full game is a deckbuilder roguelike with Balatro's run structure. A player's machine
chariot fights a procedurally generated enemy chariot in a falling-sand arena, then edits and
improves the chariot in a shop phase. A run is 3 battles → elite, three times over, then a boss;
beating the boss wins.

The core fun is **chains between parts** (Balatro jokers, Bazaar adjacency, Noita spell
interactions) running through a **falling-sand simulated arena**, plus **resource management**
(energy in battle, gold and inventory space in the shop).

**This document covers only the first slice:** one battle against one fixed enemy, with a
handful of parts, and a garage to build the chariot in. Its purpose is to answer one question:
*is the battle fun?* That is, do auto-firing parts competing for energy, chains between parts, and
the sand sim produce interesting fights and interesting building decisions?

## 2. Goals, non-goals, anti-goals

**Goals**
- A garage screen in which the player places parts onto a body's slots and extension slots,
  swaps bodies, then starts a fight.
- One battle in a closed sand arena against a fixed enemy chariot, ending in win or loss and
  returning to the garage.
- Every part listed in §5.6 working, including its chain hook where it has one.
- A data model and module boundaries that the later shop, run map and enemy generator plug
  into without rewriting the garage or battle (§8).

**Non-goals (later, not this slice)**
- Shop phase, gold, packs, selling, inventory limits, run map, elites, bosses, procedural
  enemies, meta progression, final art, audio polish, save/load.
- Cell-level erosion of chariot bodies (approach B, §4). It may be added later on top.

**Anti-goals (would make the slice a failure even if it technically works)**
- Chains that exist only in tooltips. The player must be able to *see* a chain happen in the
  fight: fire appears, the Ember Battery pulses, the Rocket fires sooner.
- The player not being able to tell why they won or lost. Energy, HP, part states and the
  queue of waiting parts must be readable on screen.
- Hard-coding parts, bodies or the enemy in battle code so that the shop or generator would need a
  rewrite. Everything is data.
- Placement not mattering. If any layout plays the same, the slot system has failed.

## 3. Constraints

- Godot 4.7, GDScript for game code; native engine is `addons/noita_engine` (GDExtension,
  already built: `bin/libnoita_engine.linux.template_debug.x86_64.so`).
- Game code lives outside the addon (e.g. `res://game/`). Per the addon README, do not
  reference `res://addons/noita_engine/demo/` from game code; copy the materials and helper code
  that are needed into the game folder.
- The addon registers global class names `PixelCharacter`, `CharacterSystem`, `CarController`,
  `TexturesUtil`; game classes must not reuse them.
- `PixelRigidBody` takes its shape once at join and is stamped into and then unstamped from the grid every
  tick; there is no API for permanently removing a body's cells. This is why approach A was chosen.
- Pixel-art resolution 320×180, nearest filtering (already configured).
- Part names and behaviours borrowed from CATS and Noita are working names for this prototype.
  A released game would need original names and art.

## 4. Approaches considered

| | Approach | Trade-off |
|---|---|---|
| **A (chosen)** | **Each part is its own small `PixelRigidBody` jointed to the chassis.** Part damage is computed in gameplay code by sampling the sand around each part. | Works on the existing engine (only an ice material is new); parts swing, fall off and get pulled for real; damage rules stay tunable. Parts don't visibly erode. |
| B | Add true cell erosion to bodies in C++ (remove burned/melted/cut cells, rebuild the shape). | Most Noita-like, but a serious engine project with performance risk. Since HP is the only win condition, most of the gain is visual. |
| C | One body per chariot; parts are logical markers that sample the sand at their slot. | Cheapest, but parts can't move, fall off or be pulled individually, which weakens "position matters physically". |

The user picked **A**. B stays possible later, because part damage in A is already modelled
per part.

## 5. Decided design

### 5.1 Battle rules (user's decisions)

- Each chariot has one **HP** number on its body. HP reaching 0 is the **only** win/lose
  condition.
- **Parts fire on their own**, on cooldowns or triggers (CATS style). The player only drives
  **left / right**.
- **Everything costs energy, including moving.** When a part is ready but energy is short, it
  **waits in line** until energy regenerates; nothing stalls or overheats.
- **Reactions physically damage parts** but are not a win condition. A frozen or burned-up wheel
  can't drive while weapons keep firing.

### 5.2 Battle rules (my calls, agreed in conversation)

- **Part damage lasts for one fight only.** Every battle starts with the build intact.
- **A broken part is disabled for the rest of the fight.** By default its joint is removed and
  it falls off into the sand.
- **Physical events feed chains.** "Part destroyed", "wheel frozen" and "caught fire" are
  events alongside combat events.

### 5.3 Energy

- The body defines **energy capacity** and **regen per second** (CATS "power" is mapped to
  this).
- A part whose cooldown is complete tries to pay its energy cost. If it can't, it joins a
  **FIFO queue** and fires as soon as the energy at the head of the queue is available.
- Driving drains energy continuously while a direction is held. With no energy, the chariot
  doesn't drive (the input is ignored and does not queue).
- **Driving is paid first (user's decision).** While a direction is held, the driving drain
  comes out of energy before the waiting parts are paid. Holding a direction visibly delays
  your weapons, and that trade-off is the point.
- Passive and event effects cost no energy unless stated.

Starting numbers (tuning placeholders, my call):

| Body | HP | Energy cap | Regen/s | Shape / slots |
|---|---|---|---|---|
| Cutter | 500 | 20 | 6 | Small, light, fast; few slots close together |
| Dozer | 500 | 20 | 5 | Round, stable; slots spread around the edge |
| Corsair | 600 | 24 | 5 | Long, top-heavy (can flip); the most slots |

Driving: 2 energy/s. Part costs: CATS power 5 → 1 energy, power 10 → 2 energy.

### 5.4 Chariot building (user's decisions)

- **CATS-style slots, not Bad Piggies crates.** A body has fixed slot positions. **Slots are
  untyped**, so any part goes in any slot (a wheel on top just spins in the air).
- **Some parts carry extension slots**, so builds can branch out from the body.
- **Swapping bodies keeps parts as best as it can.** Parts move to the nearest matching slot by
  position; leftovers return to inventory. A new body is a choice, not a reset.
- **Inventory is limited** (enforced in the full game; the slice uses a fixed starter
  inventory large enough for every part).
- **Wheels are ordinary parts** (my call, agreed). A chariot with no grounded wheels can't drive but
  still fights.
- **Facing (user's decision):** every part fires the way it faces on its slot. Clicking a
  placed part in the garage flips it left/right. `ChariotLayout` stores the flip per slot. The
  enemy's layout is mirrored so it faces the player. No rotation, and no auto-aim.
- **Extension slots in the slice (user's decision):** a plain **Strut** part with 2 extension
  slots. Layout is a tree. If a part breaks and falls off, everything mounted on it falls too.
  On a body swap, a part moves together with its children as one group.

### 5.5 Chains

Two kinds, as the user chose:
- **Proximity chains (Bazaar-style):** a part affects parts within a **physical distance** on
  the chariot (measured between part anchors in cells, computed from the layout).
- **Event chains (Balatro × Noita):** a part listens for an event happening anywhere and reacts.

My call (agreed): **both run on one event bus.** Every gameplay event carries a source part,
position and chariot. Proximity is a filter on who receives it. Event types needed for the slice:
`part_fired`, `hit` (damage dealt / received), `caught_fire` (a part or chariot becomes
burning), `frozen`, `thawed`, `part_broken`, `cells_cut`, `energy_gained`. Shop events
(`part_sold`, …) are added later on the same bus.

### 5.6 Parts in the slice (user's selection; hooks proposed by me and agreed)

| Part | Source | Behaviour | Energy | Chain hook |
|---|---|---|---|---|
| Ice Cream Mace | CATS melee | Cheap contact blade | 1 | **Shatter:** hitting a frozen part deals ×3 damage and ends its freeze |
| Cutter Chainsaw | CATS melee, long reach | High-damage long blade | 2 | **Sparks:** cutting through enemy parts or terrain throws sparks that can ignite flammables |
| Flamethrower | CATS special | Burst of fire cells; target keeps burning; then a pause | 2 | none (elemental by itself) |
| Hearth | CATS special | Charges up, then heats its own chariot so it burns everything touching it | 2 | none |
| Cutter Rocket | CATS ranged | Fires about once a second; explosion digs terrain | 2 | **Ignition:** whenever anything catches fire, its next shot charges faster |
| Corsair Harpoon | CATS tool | Shoots forward, attaches to the enemy, drags it closer | 1 | none |
| Ember Battery | user | Passive | 0 | **When anything catches fire, gain energy** |
| Firebolt Launcher | Noita Firebolt | Lobs a fireball that explodes, digs terrain and starts fires; limited charges per fight | 1 + charges | — |
| Ring of Fire | Noita Circle of Fire | Expanding ring of burning air around the part; **hits its own chariot too** | 4 | — |
| Freeze Charge | Noita Freeze Charge | Passive proximity: weapons within range also freeze what they hit | 0 | **Proximity modifier** |
| Wheel | my call (needed to drive) | Motorised wheel (one type in the slice); can freeze or burn up | driving cost | — |
| Strut | user (extension slots) | Plain frame with 2 extension slots | 0 | — |

Driving cost stays a flat 2 energy/s regardless of wheel count (my call; tune later).

Intended chains this set should make visible:
1. Chainsaw sparks → enemy burns → Ember Battery gives energy and the Rocket recharges faster.
2. Freeze Charge near weapons → the enemy wheel freezes → Harpoon drags it in → Mace shatters.
3. Hearth or Ring of Fire burns your own chariot → Ember Battery pays you for the risk.

### 5.7 Damage and status model (my call, consistent with approach A)

- **Chariot HP** takes damage from weapon hits and from burning (damage over time while any of its parts is
  burning).
- **A hit on a part (user's decision)** lowers chariot HP by the full damage, and the part that
  was hit also loses some integrity. Parts wear down and can break, but they do not shield HP.
  Multipliers such as the Mace's ×3 apply to the HP damage.
- **Each part has integrity**, which is separate from HP. Fire, lava and cutting reduce it. At 0 the part is
  broken (§5.2).
- **Status from sampling:** each tick, each part samples cells in a margin around its body,
  using `PixelWorld.get_material_at` or `scan_boxes`. Fire/lava cells → `burning`. Frost/ice
  exposure builds up freeze → `frozen`. Water contact puts out burning.
- **Frozen effects:** a wheel's motor locks; a weapon's cooldown pauses. Freeze decays over
  time.
- **Hits:** melee needs to know *which* enemy body it touched. `PixelWorld.body_contacts`
  only reports contact sides, so this needs a new engine query (§6). Projectiles are small
  bodies or swept boxes. Explosions use `PixelWorld.explode`, which digs terrain.

### 5.8 Arena (user's decision)

- A closed pit. **Indestructible concrete walls** (obsidian-like) on both sides and a concrete
  floor at the bottom; nothing escapes.
- Surface terrain of **sand, wood and water pools**. Below it, **solid stone with lava pools**.
  No caves.
- My calls (agreed): about **480×180 cells**, with a camera that keeps both chariots in frame.
  Lava comes into play only once blasts or cuts dig down to it. Water puts out burning chariots,
  which gives driving a defensive use.

### 5.9 Fixed enemy (my call, agreed)

- **Build:** a Dozer with 2 Wheels + Hearth + Corsair Harpoon + Ice Cream Mace. It drags you
  in and cooks you. Its wheels sit low and exposed, so a freeze build can really lock them
  (chain 2).
- **AI:** drives toward the player until in weapon range, then holds. It pays the same energy
  rules.
- **Defined as data** in the same layout format as the player's chariot (§8).

### 5.10 Garage (user's decision: included; my calls on the details)

- **Screen:** the current body is drawn with slot markers. The inventory list holds the starter
  parts. The player drags a part onto a slot, and any extension slots on that part appear.
  Dragging a part off a slot returns it to inventory.
- **Body swap:** a button cycles Cutter / Dozer / Corsair and re-seats parts by nearest
  position (§5.4).
- **Info:** hovering or selecting a part shows its cost, cooldown and hook text, plus an outline of
  its proximity range on the chariot.
- **Fight** starts the battle with the current layout. The result screen returns to the garage
  with the layout unchanged.

## 6. Engine work needed

- New materials as `.tres` data in the game's material set (copied from the addon demo set):
  - `concrete`: an indestructible solid. `explode` currently clears every cell that isn't part of a
    body, so the C++ needs an "indestructible" material flag that `explode` respects.
  - `rock` (used as the arena's stone layer) and `lava`, both in the demo set.
  - `frost`: a cold gas or particle with a low fixed temperature.
  - `ice`: water's `low_temperature` / `low_into` → `ice`; ice's `high_into` → `water`.
- A new query that reports **which bodies are in contact** (pairs of body handles, plus the contact point and
  speed). Box2D already has this data (`BodyHit` in `engine/core/physics.h`). Melee hits
  need it.
- Small additive C++ changes to the addon are allowed (my call). Body and joint *behaviour* stays as it
  is: a weld is a `PixelRevoluteJoint` with limits locked at 0.

## 7. Calls made without the user (to check)

- Wheel is an added part type; there's one wheel type, and driving costs a flat 2 energy/s.
- Enemy carries 2 low, exposed wheels.
- Small additive C++ changes to the addon are allowed (an indestructible flag, a body-contact query).
- `rock` from the demo set serves as the stone layer.

## 8. Integration seams for the full game

These boundaries exist so that the shop, run map and generator can plug in later:

- **`PartDef` (Resource):** id, display name, tags (`fire`, `ice`, `melee`, `ranged`, …),
  energy cost, cooldown, integrity, proximity range, extension slot positions, and a behaviour
  script. Shops filter on tags (a "fire shop" is a tag query).
- **`BodyDef` (Resource):** id, HP, energy cap, regen, texture, slot positions.
- **`ChariotLayout` (Resource):** body id + a tree of slot → part id (extension slots nest).
  The garage produces it, the battle consumes it, and the enemy is one too. The procedural
  generator later outputs this same type.
- **`Inventory`:** a list of part ids with a capacity. The garage reads from it and writes to it.
  The shop later fills it and empties it (selling).
- **Event bus:** shared by battle and, later, the shop (`part_sold` and similar), so
  shop-phase chains ("when selling a fire part, +2 HP, +2 gold") use the same hooks.
- **Garage scene API:** takes an `Inventory` and a `ChariotLayout` and emits `fight_requested(layout)`.
  The shop phase later wraps or embeds this scene.

## 9. Left to the builder

- Scene and folder layout under `res://game/`, class names, and how part behaviour scripts are
  structured.
- Exact tuning numbers beyond the placeholders above.
- Camera behaviour, HUD layout and placeholder art (procedural textures such as the demo's
  `TexturesUtil.box`/`disc` are fine).
- Testing approach (e.g. headless tests for the energy queue, event bus, layout re-seating).
- Projectile implementation (bodies vs. swept boxes) per weapon.
