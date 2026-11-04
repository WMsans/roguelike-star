# RoguelikeStar: parts list

169 parts that mount in slots on a chariot body: 43 common, 88 uncommon and 38 rare. Bodies and
relics are separate lists.

Each part is one SCAMPER move (Substitute, Combine, Adapt, Modify, Put to another use, Eliminate,
Reverse) on an item from the research catalogs or an example from the design discussion.

Related docs: [core-mechanics.md](core-mechanics.md) (rules),
[elements-list.md](elements-list.md) (materials and statuses), research in
[research/parts/](research/parts/README.md).

Markers follow `core-mechanics.md`: **Decided** was agreed in discussion, **Proposed** is a
starting point. All numbers are Proposed.

## 1. Conventions

### 1.1 Scale

**Decided**
- Numbers are on The Bazaar's scale. A plain common weapon hits for 40–120 every 3–8 seconds.
- Continuous weapons (chainsaws, drills, lasers, flamethrowers) deal about 10–20 damage per
  second.
- Status stacks are 1–10 per hit.

**Proposed**
- Starting body HP about 800, energy capacity about 20, regen about 4 per second.
- Wheels cost 1–2 energy per second while driving.

### 1.2 Firing modes

**Decided**
- **Cooldown parts** fire when their cooldown fills. Energy is paid per firing.
- **Continuous parts** have no cooldown. They pay energy per second while running, like driving.
  - **Melee** continuous weapons deal damage once per second of contact (a **tick**). Every tick
    counts as a hit and as firing, because going melee in a reactive arena is risky.
  - **Beam** continuous weapons deal damage each second the target is in the beam. Each second
    counts as a hit, but only switching on counts as firing.
  - Freeze stops a continuous part, Slow halves its tick rate, Speedup doubles it.
- **Wheels** pay their energy cost per second while the chariot is driving, so driving costs
  more the more wheels it has. Driving is still paid before any waiting part.
- **Passive parts** have no cooldown and usually cost no energy. Some react to triggers.
- There is no Continuous tag; the mode shows in the Cooldown column.

### 1.3 Statuses and wording

- The 9 statuses are Flame, Freeze, Block, Acid, Wet, Oil, Shock, Speedup and Slow
  ([elements-list.md](elements-list.md)). All effects that change a part over time are statuses:
  "speed up 1s" is "gain 1 Speedup".
- "Apply N Flame" puts the stacks on the enemy part the hit landed on.
- "The enemy's Flame" means the total across all enemy parts. "Your body's Block" means one part.
- "For the battle" lasts until the battle ends. "Permanently" lasts the rest of the run (Balatro
  style scaling). The shop always offers a part in its base state.

### 1.4 Triggers

**Decided**

| Group | Triggers |
|---|---|
| Clock | Own cooldown (the default). Every N seconds. Start of battle. N seconds into the battle. The first or Nth time this fires. |
| Own parts | This fires. A neighbour, a tagged part, the part in front or behind, or a part mounted on this fires. A part breaks. A part starts waiting in the energy queue. |
| Combat | You hit the enemy, or hit a particular enemy part (the body, a wheel). You take damage. Block absorbs a hit. Block reaches 0. HP falls below a threshold. You would die. An enemy part breaks. The enemy fires. |
| Statuses | For each of the 9, on your parts or the enemy's: a part gains it, reaches N stacks or loses its last stack. Two statuses cancel ("Flame is put out", "thawed"). An Oil or Wet doubling happens. Shock jumps. |
| Energy and driving | Energy is full or empty. Energy is spent or gained. You start or stop driving. |
| Sand sim | A part starts or stops touching a material. An explosion happens nearby. A battery breaks. Cells are dug or dissolved. A reaction happens nearby. You go airborne or land. You ram the enemy. |
| Shop and run | You buy or sell this part, or a part with a tag. You reroll. You enter a shop stage or open a pack. You win a battle, an elite or the boss. The shop phase ends. |

- **Scopes:** this part, neighbours (within this part's range), in front of (within range, on the
  side this part faces), behind (within range, on the other side), mounted on this part, parts
  with a tag, all your parts, enemy parts.
- **Conditions and counters:** "while…", "if…", "for every N…".
- **Effects:** apply a status, deal damage, spawn a material, gain energy, gain gold, heal,
  permanent scaling, and (rarely) making another part fire.
- **Inventory parts** react to shop and run triggers. Battle triggers only reach mounted parts.

### 1.5 Columns

| Column | Meaning |
|---|---|
| ID | C (common), U (uncommon), R (rare) plus a number |
| Tags | Shop themes (Weapon, Defence, Tricky, Attack, Fire, Ice, Wind, Earth, Electric, Acid, Stats) and kind tags (Melee, Beam, Wheel, Negative). The Passive and Triggered shop themes read the effect, not a tag |
| En | Energy per firing, or per second (`/s`) for continuous parts and for wheels while driving. 0 for passives |
| CD | Cooldown in seconds, `Melee` or `Beam` for continuous parts, `—` for passives |
| Int | Integrity |
| Rng | Proximity range in cells, measured centre to centre: **S** = 12 (about the adjacent slots), **M** = 20, **L** = 32. `—` means the part has no proximity effect |
| Ext | Extension slots this part carries. Parts mounted on it move with it and fall off if it breaks (`core-mechanics.md` §4.1) |
| SCAMPER | Method letter (S, C, A, M, P, E, R) and the source item |

## 2. Target builds

**Decided.** Every build has uncommons and rare cores made for it; commons work anywhere.

| # | Build | Theme | Plan | Uncommons | Rares | Bridges to other builds |
|---|---|---|---|---|---|---|
| 1 | Inferno | Fire | Stack Oil on the enemy, double Flame. Oil keeps water from saving them. | U01–U06 | R01–R03 | U03 Heat Shield → Fortress. U06 Bellows → Overclock |
| 2 | Deep Freeze | Ice | Soak with Wet, double Freeze, lock cooldowns and wheels. | U07–U13 | R04–R06 | U13 Ice Scope → Sniper |
| 3 | Shock Chain | Electric | Batteries, wet terrain and packed enemy parts make Shock jump. | U14–U19 | R07–R09 | U17 Capacitor → Reactor. U18 Wet Wire → Deep Freeze |
| 4 | Acid Eater | Acid | Strip Block, dissolve terrain, sink the enemy. | U20–U24 | R10–R11 | U21 Corroder → Grinder. U24 Sinkhole Flask → Demolition |
| 5 | Fortress | Defence | Stack Block, turn Block into damage. | U25–U30 | R12–R14 | U30 Thermal Plating → Inferno |
| 6 | Grinder | Weapon | Melee ticks fire every second, so on-fire buffs stack fast. | U31–U36 | R15–R17 | U32 Hot Teeth → Inferno. U35 Rotary Drill → Fortress |
| 7 | Sniper | Weapon | Beams and slow heavy weapons, big hits from range. | U37–U41 | R18–R19 | U40 Stabiliser → Overclock |
| 8 | Demolition | Earth | TNT, gunpowder, chained explosions, digging to lava. | U42–U47 | R20–R22 | U44 Blast Shield → Fortress |
| 9 | Gale | Wind | Push smoke, acid gas and steam onto the enemy. Slow them. | U48–U52 | R23–R24 | U49 Smokestack → Inferno. U51 Steam Vent → Deep Freeze |
| 10 | Overclock | Wind / Tricky | Stack Speedup and pass it along facing chains. | U53–U58 | R25–R26 | U58 Static Gears → Shock Chain |
| 11 | Reactor | Tricky / Stats | Energy as a resource: overflow, gains, the queue. | U59–U63 | R27–R28 | U61 Dynamo Wheel → Rammer. U62 Power Siphon → Shock Chain |
| 12 | Merchant | Stats / Tricky | Scale from selling and buying, bench parts in inventory. | U64–U68 | R29–R30 | U68 Collector's Shelf → Fortress |
| 13 | Steam | Fire + Ice | Feed off statuses cancelling each other. | U69–U72 | R31 | U69 Boiler and U71 Thermal Shock Gun join Inferno and Deep Freeze |
| 14 | Rammer | Wheel | Driving, ramming, landing. Make moving pay. | U73–U77 | R32–R33 | U76 Spiked Wheel → Grinder |
| 15 | Last Stand | Defence / Tricky | Low HP thresholds and "would die" triggers. | U78–U81 | R34 | U81 Last Rites → Demolition |
| 16 | Thorns | Defence | Punish the enemy for hitting you. | U82–U85 | R35–R36 | U84 Shock Plate → Shock Chain |

**Decided**
- Every build has one or two bridge parts that pull another build in.

Frames (C42–C43, U86–U88, R38) and Mimic Module (R37) serve every build.

## 3. Common parts (43)

Simple, universal, weak. Price 2 gold.

### Weapon (10)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C01 | Rocket Pod | Weapon | 4 | 4 | 60 | — | — | Fire a rocket: 60 damage. | A: CATS Rocket Launcher |
| C02 | Cannon | Weapon | 6 | 7 | 80 | — | — | Fire a heavy shell: 120 damage. | M: CATS Potato Cannon (slower, heavier) |
| C03 | Chainsaw | Weapon, Melee | 2/s | Melee | 60 | — | — | 15 damage per tick. | A: CATS Chainsaw |
| C04 | Drill | Weapon, Melee | 2/s | Melee | 70 | — | — | 12 damage per tick. Digs terrain up to hardness 5. | C: CATS Drill + Noita Digging Bolt |
| C05 | Stinger | Weapon, Melee | 3 | 2 | 50 | — | — | Stab: 25 damage. Reaches twice as far as other melee weapons. | A: CATS Stinger |
| C06 | Spinning Blade | Weapon, Melee | 1/s | Melee | 50 | — | — | 10 damage per tick. Still hits when upside down or airborne. | A: CATS Blade |
| C07 | Laser | Weapon, Beam | 3/s | Beam | 40 | — | — | 12 damage per second along the beam. | A: CATS Laser |
| C08 | Shotgun | Weapon | 5 | 5 | 60 | — | — | 7 pellets of 12 damage. Knocks both chariots back. | A: CATS Shotgun |
| C09 | Minigun | Weapon | 1 | 0.5 | 50 | — | — | Fire a bullet: 6 damage. | A: CATS Minigun |
| C10 | Bayonet | Weapon, Attack | 1 | — | 40 | S | — | When the weapon behind this fires, deal 20 damage. | A: Bazaar Bayonet (left → behind) |

### Defence (5)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C11 | Steel Plate | Defence | 0 | — | 150 | — | 1 | Start of battle: gain 40 Block. | E: Bazaar Coral Armor (cooldown and scaling removed) |
| C12 | Shield Generator | Defence | 3 | 5 | 60 | — | — | Your body gains 30 Block. | A: Bazaar Coral Armor |
| C13 | Bumper | Defence | 0 | — | 120 | — | — | When this part is hit, gain 5 Block. | R: CATS Repulse (absorbs instead of repels) |
| C14 | Plating Rig | Defence | 0 | — | 60 | S | — | When a neighbour fires, it gains 3 Block. | A: Bazaar Defense Matrix |
| C15 | First Aid Kit | Defence | 4 | — | 50 | — | — | The first time HP falls below half each battle, heal 120. | A: CATS First Aid Kit |

### Fire (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C16 | Flamethrower | Weapon, Fire, Beam | 2/s | Beam | 50 | — | — | Short beam: 4 damage and 1 Flame per second. Sprays fire cells. | C: CATS Laser + Noita Burning Trail |
| C17 | Molotov | Weapon, Fire | 4 | 6 | 40 | — | — | Lob a bottle: 30 damage, apply 4 Flame, leaves a patch of fire. | A: CATS Molotov Cocktail |
| C18 | Igniter | Fire | 2 | 3 | 40 | S | — | Apply 1 Flame. Neighbours apply 2 more Flame whenever they apply Flame. | A: Bazaar Incendiary Rounds |

### Ice (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C19 | Frost Sprayer | Weapon, Ice | 3 | 4 | 50 | — | — | 15 damage, apply 3 Freeze. | A: Bazaar Frost Potion |
| C20 | Water Cannon | Weapon, Ice | 3 | 4 | 60 | — | — | A jet of water: 10 damage, apply 4 Wet, pushes the enemy back. Spawns water cells. | A: Noita Water Trail |
| C21 | Ice Pick | Weapon, Ice, Melee | 2 | 2 | 50 | — | — | 20 damage. 40 instead if the part hit has Freeze. | M: Bazaar Ice Pick |

### Electric (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C22 | Zap Gun | Weapon, Electric | 3 | 3 | 50 | — | — | 15 damage, apply 3 Shock. | A: CATS Zap Gun |
| C23 | Battery Dropper | Electric, Earth | 3 | 8 | 40 | — | — | Drop a battery block on the ground in front. | P: battery material as a deployable |
| C24 | Lightning Rod | Electric, Defence | 0 | — | 80 | M | — | Shock your parts within range would gain goes to this part instead. | R: Noita Electric Charge (draws charge in) |

### Acid (2)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C25 | Acid Squirter | Weapon, Acid | 3 | 4 | 40 | — | — | 10 damage, apply 3 Acid. | A: Noita Acid Ball |
| C26 | Acid Dripper | Acid | 0 | — | 40 | — | — | Every 2 seconds, drip acid cells under the chariot. | A: Noita Acid Trail |

### Earth (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C27 | Dynamite Toss | Weapon, Earth | 4 | 6 | 40 | — | — | Throw a lit stick that explodes (small) after 2 seconds. | A: Noita Dynamite |
| C28 | Gunpowder Hopper | Earth | 2 | 5 | 40 | — | — | Pour a line of gunpowder on the ground in front. | P: gunpowder material as a deployable |
| C29 | Sandbag | Earth, Defence | 0 | — | 100 | — | — | Start of battle: gain 20 Block. When an explosion happens within 30 cells, gain 10 Block. | M: Steel Plate (C11) for explosions |

### Wind (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C30 | Fan | Wind | 1/s | Beam | 40 | — | — | Blows gases and fire forward along the beam. | A: Noita Burst of Air |
| C31 | Smoke Bomb | Wind | 3 | 6 | 40 | — | — | Release a cloud of smoke in front. | P: smoke (gives Slow) as a weapon |
| C32 | Turbo Booster | Wind | 2 | 5 | 40 | S | — | Neighbours gain 1 Speedup. | A: Bazaar Companion Core |

### Attack (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C33 | Targeting Computer | Attack | 2 | 5 | 40 | — | — | Deal 10 damage. Your weapons gain +2 damage for the battle. | A: Bazaar Sharkclaws |
| C34 | Sharpener | Attack | 0 | — | 40 | S | — | Neighbouring melee weapons deal +3 damage per tick. | A: Noita Damage Plus |
| C35 | Heavy Rounds | Attack | 0 | — | 40 | S | — | The weapon in front deals +20 damage per hit and costs +1 energy. | A: Noita Heavy Shot |

### Stats (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C36 | Spare Cell | Stats | 0 | — | 40 | — | — | +5 energy capacity. | A: Noita Add Mana |
| C37 | Generator | Stats | 0 | — | 50 | — | — | +1 energy regen per second. | M: Noita Add Mana (one-off → ongoing) |
| C38 | Reinforced Frame | Stats | 0 | — | 80 | — | 1 | +100 max HP. | P: CATS body health as a part |

### Wheel (3)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C39 | Roller | Wheel | 1/s | — | 60 | — | — | Average speed and grip. | A: CATS Roller |
| C40 | Bigfoot | Wheel | 2/s | — | 90 | — | — | Fast and climbs well, but makes the chariot less stable. | A: CATS Bigfoot |
| C41 | Sticky Tire | Wheel | 1/s | — | 70 | — | — | Excellent grip. Hard to push back. | A: CATS Sticky Tire |

### Frame (2)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| C42 | Strut | Stats | 0 | — | 50 | — | 1 | No effect of its own. Holds one more part. | P: CATS body slots as a part |
| C43 | Long Arm | Stats | 0 | — | 40 | — | 1 | Holds one part 30 cells out from its slot, past the edge of the body. | M: Strut (longer) |

## 4. Uncommon parts (88)

More powerful and leaning towards a build. Price 6 gold.

### 4.1 Inferno (Fire)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U01 | Oil Sprayer | Fire | 3 | 5 | 50 | — | — | Spray oil: apply 4 Oil, spawns oil cells. | A: Noita Oil Trail |
| U02 | Fuel Line | Fire | 0 | — | 50 | S | — | When a neighbour applies Flame, it also applies 2 Oil. | C: Bazaar Incendiary Rounds + Noita Oil Trail |
| U03 | Heat Shield | Fire, Defence | 0 | — | 80 | — | — | While this part has Flame, it gains Block equal to its Flame each second. | discussion example |
| U04 | Incinerator | Weapon, Fire | 4 | 6 | 60 | — | — | Deal damage equal to 5 × the Flame on the part hit. | M: Bazaar Infernal Greatsword |
| U05 | Napalm Launcher | Weapon, Fire | 5 | 7 | 50 | — | — | 30 damage, apply 3 Oil then 3 Flame. Leaves burning oil. | C: CATS Molotov Cocktail + Noita Oil Trail |
| U06 | Bellows | Fire, Wind | 0 | — | 40 | S | — | When a neighbour applies Flame, neighbours gain 1 Speedup. | A: Bazaar Pyrocarbon |

### 4.2 Deep Freeze (Ice)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U07 | Rainmaker | Ice | 3 | 5 | 40 | — | — | Spawn a small rain cloud above the enemy for 3 seconds. | M: Noita Sea of Water (small, overhead) |
| U08 | Cryo Cannon | Weapon, Ice | 5 | 7 | 60 | — | — | 40 damage, apply 6 Freeze. If the part hit is Wet, parts touching it gain 2 Freeze. | C: Bazaar Frost Potion + Ice Luge |
| U09 | Icebreaker | Weapon, Ice | 4 | 7 | 70 | — | — | 100 damage. When any enemy part gains Freeze, this gains 1 Speedup. | A: Bazaar Icebreaker |
| U10 | Antifreeze Coat | Ice, Defence | 0 | — | 60 | M | — | Your parts within range lose Freeze twice as fast. | A: Bazaar Cryosleeve |
| U11 | Cold Snap | Ice | 3 | 6 | 40 | — | — | The enemy part with the most Wet gains Freeze equal to half its Wet. | P: Wet doubling as a payoff |
| U12 | Freeze Ray | Weapon, Ice, Beam | 3/s | Beam | 40 | — | — | 1 Freeze per second, no damage. When it switches on, apply 3 Wet. | A: Noita Freezing Gaze |
| U13 | Ice Scope | Ice, Attack | 0 | — | 40 | S | — | Neighbouring weapons deal +25 damage per hit to parts that have Freeze. | C: Ice Pick (C21) + Sniper build |

### 4.3 Shock Chain (Electric)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U14 | Tesla Coil | Weapon, Electric | 4 | 5 | 60 | S | — | 40 damage, apply 3 Shock. When a neighbour fires, this gains 1 Speedup. | A: Bazaar Tesla Coil |
| U15 | Chain Lightning | Weapon, Electric | 5 | 6 | 50 | — | — | 30 damage, apply 4 Shock. This Shock jumps one extra hop. | A: Noita Chain Bolt |
| U16 | Ball Lightning | Weapon, Electric | 5 | 8 | 40 | — | — | Launch 3 slow orbs, each 10 damage and 3 Shock. They spark through water. | A: Noita Ball Lightning |
| U17 | Capacitor | Electric, Stats | 0 | — | 40 | M | — | When a part within range gains Shock (yours or the enemy's), gain 1 energy. | P: Shock as an energy source |
| U18 | Wet Wire | Electric, Ice | 0 | — | 40 | — | — | Shock you apply to Wet enemy parts is doubled. | S: Noita Critical On Burning (burning → wet, crit → Shock) |
| U19 | Grounding Spike | Electric, Earth | 3 | 6 | 60 | — | — | Send a spark through the ground towards the enemy. It travels along water and steel and applies 4 Shock on contact. | P: electric spark material as a weapon |

### 4.4 Acid Eater (Acid)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U20 | Acid Cannon | Weapon, Acid | 4 | 6 | 50 | — | — | 20 damage, apply 5 Acid. Splashes acid cells. | A: Noita Circle of Acid |
| U21 | Corroder | Acid | 0 | — | 40 | S | — | Neighbouring melee weapons also apply 1 Acid per tick. | C: Sharpener (C34) + Acid |
| U22 | Acid Gas Vent | Acid, Wind | 3 | 6 | 40 | — | — | Release a cloud of acid gas in front. | P: acid gas material as a weapon |
| U23 | Etching Ray | Weapon, Acid, Beam | 3/s | Beam | 40 | — | — | 6 damage per second. Damage to Block is doubled. | M: CATS Laser for Block |
| U24 | Sinkhole Flask | Acid, Earth | 4 | 8 | 40 | — | — | Throw a flask that bursts into a pool of acid under the enemy, dissolving the ground beneath its wheels. | M: Noita Sea of Acid (small, aimed) |

### 4.5 Fortress (Defence)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U25 | Spiked Shield | Defence, Attack | 3 | 6 | 70 | — | — | Deal damage equal to your body's Block. | A: Bazaar Spiky Shield |
| U26 | Shield Battery | Defence | 0 | — | 60 | S | — | When a neighbour gains Block, it gains 3 more. | A: Bazaar Turtle Shell |
| U27 | Rampart | Defence | 4 | 5 | 120 | S | 1 | This part and every neighbour gain 15 Block. | A: Noita Circle of Shielding |
| U28 | Bunker Frame | Defence, Negative | 0 | — | 100 | — | 2 | +1 inventory slot. Start of battle: your body gains 30 Block. | C: Negative tag + Steel Plate (C11) |
| U29 | Compound Plating | Defence | 0 | — | 100 | — | — | Every 5 seconds, your body gains Block equal to 10% of its Block (at least 5). | M: Bazaar Nesting Doll (grows in battle) |
| U30 | Thermal Plating | Defence, Fire | 0 | — | 100 | S | — | When this part gains Block, neighbouring weapons apply +1 Flame per hit for the battle. | discussion example |

### 4.6 Grinder (Weapon, melee)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U31 | Buzzsaw Arm | Weapon, Melee | 2/s | Melee | 60 | S | — | 12 damage per tick. When a neighbour fires, this deals +5 on its next tick. | C: CATS Chainsaw + Bazaar Bayonet |
| U32 | Hot Teeth | Fire, Melee | 0 | — | 40 | S | — | When a neighbouring melee weapon fires, apply 1 Flame to what it hit. | C: Sharpener (C34) + Flame |
| U33 | Gear Train | Stats, Melee | 0 | — | 50 | S | — | Every 4th time a neighbouring melee weapon fires, gain 1 energy. | P: melee ticks as an energy source |
| U34 | Heavy Grinder | Weapon, Melee | 3/s | Melee | 80 | — | — | 20 damage per tick, +2 for each second of unbroken contact. Resets when contact breaks. | A: CATS Minigun (spin-up) |
| U35 | Rotary Drill | Weapon, Melee, Earth | 2/s | Melee | 70 | — | — | 12 damage per tick. Digs up to hardness 7. Gains 1 Block per cell dug. | A: Noita Luminous Drill |
| U36 | Overdrive Clutch | Melee, Tricky | 0 | — | 40 | S | — | Every 10th time a neighbouring melee weapon fires, it gains 3 Speedup. | M: Bazaar Rolling Pin (count instead of haste) |

### 4.7 Sniper (Weapon, ranged)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U37 | Railgun | Weapon | 8 | 10 | 50 | — | — | 220 damage. | M: CATS Laser (charge, one big shot) |
| U38 | Focus Lens | Attack, Beam | 0 | — | 40 | S | — | When a neighbouring beam switches on, it deals +30 damage in its first second. | A: Noita Concentrated Light |
| U39 | Rangefinder | Attack | 0 | — | 40 | S | — | Neighbouring weapons deal +1 damage per hit for every 10 cells between you and the enemy. | R: melee reach (far rewarded, not near) |
| U40 | Stabiliser | Attack | 0 | — | 50 | S | — | While you are not driving, neighbouring weapons gain 1 Speedup every 3 seconds. | P: driving cost as a sniper reward |
| U41 | Long Barrel | Attack | 0 | — | 40 | S | — | The weapon in front deals +50 damage per hit and has +3 seconds cooldown. | M: Noita Heavy Shot |

### 4.8 Demolition (Earth)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U42 | TNT Launcher | Weapon, Earth | 5 | 8 | 50 | — | — | Lob a TNT crate that lands in front. It explodes when Flame or a spark reaches it. | A: Noita Summon Explosive Box |
| U43 | Detonator | Earth | 3 | 6 | 40 | — | — | Set off every TNT and gunpowder within 40 cells. | A: Noita Explosive Detonator |
| U44 | Blast Shield | Earth, Defence | 0 | — | 120 | S | — | When an explosion happens within range, neighbours gain 10 Block. | M: Sandbag (C29) for neighbours |
| U45 | Demolition Charge | Weapon, Earth | 6 | 9 | 40 | — | — | A large explosion where it lands: 80 damage, digs up to hardness 6. | A: Noita Bomb |
| U46 | Mine Layer | Earth | 3 | 7 | 40 | — | — | Drop a mine behind you. It explodes (medium) when an enemy part comes near. | A: Noita Unstable Crystal |
| U47 | Excavator | Earth, Melee | 2/s | Melee | 70 | — | — | 8 damage per tick. Digs straight down under this part up to hardness 6, opening the way to lava. | A: Noita Digging Bolt |

### 4.9 Gale (Wind)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U48 | Gust Cannon | Weapon, Wind | 3 | 5 | 50 | — | — | A blast of air: 10 damage, pushes the enemy and all gases in front 20 cells. | A: Noita Burst of Air |
| U49 | Smokestack | Wind, Fire | 0 | — | 50 | — | — | When one of your Fire parts fires, release a puff of smoke in front of it. | C: Fire parts + smoke |
| U50 | Turbine | Wind, Stats | 0 | — | 40 | — | — | When an enemy part gains Slow, gain 1 energy. | P: Slow as an energy source |
| U51 | Steam Vent | Wind, Ice | 3 | 6 | 40 | — | — | Release a burst of steam in front. | P: steam material (gives Wet) as a weapon |
| U52 | Weather Vane | Wind | 0 | — | 40 | L | — | Gases within range drift towards the enemy instead of rising. | R: gas rising (sideways, aimed) |

### 4.10 Overclock (Wind / Tricky)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U53 | Overclocker | Wind, Tricky | 2 | 4 | 40 | S | — | The part in front gains 2 Speedup. | E: Bazaar Power Sander (slow half removed) |
| U54 | Gear Linkage | Tricky | 0 | — | 40 | S | — | When the part behind this gains Speedup, the part in front gains 1. | A: Bazaar Fiber Optics |
| U55 | Momentum Hammer | Weapon | 3 | 5 | 60 | — | — | 30 damage. When this gains Speedup, it gains +10 damage for the battle. | A: Bazaar Rolling Pin |
| U56 | Coolant Pump | Tricky, Ice | 0 | — | 40 | S | — | Neighbours lose Slow twice as fast. | R: Antifreeze Coat (U10) for Slow |
| U57 | Pulse Gun | Weapon, Wind | 3 | 4 | 50 | S | — | 20 damage. Neighbours gain 1 Speedup. | discussion example |
| U58 | Static Gears | Tricky, Electric | 0 | — | 40 | S | — | When a neighbour gains Speedup, its next hit applies 2 Shock. | C: Gear Linkage (U54) + Shock |

### 4.11 Reactor (Tricky / Stats)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U59 | Overflow Valve | Stats, Defence | 0 | — | 50 | — | — | While energy is full, your body gains 3 Block each second. | M: Noita Mana To Damage (to Block) |
| U60 | Priority Relay | Tricky | 0 | — | 40 | S | — | Neighbours skip to the front of the energy queue. | R: energy queue order |
| U61 | Dynamo Wheel | Wheel, Stats | 1/s | — | 60 | — | — | A wheel. While driving, gain 2 energy per second. | R: driving cost |
| U62 | Power Siphon | Electric, Tricky | 4 | 6 | 40 | — | — | 20 damage. If the part hit has Shock, gain 3 energy. | C: Zap Gun (C22) + energy |
| U63 | Surge Cannon | Weapon | all | 8 | 50 | — | — | Spend all your energy: deal 15 damage per energy spent. | A: Noita Mana To Damage |

### 4.12 Merchant (Stats / Tricky)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U64 | Piggy Bank | Stats | 0 | — | 40 | — | — | When you win a battle, this gains +1 sell value. | A: Bazaar Lockbox |
| U65 | Scrap Cannon | Weapon | 4 | 5 | 50 | — | — | 30 damage. When you sell a part, this gains +5 damage permanently. | A: Bazaar Coral Armor (scaling on sell) |
| U66 | Safe | Negative | 0 | — | 40 | — | — | +1 inventory slot. When you sell this, gain 3 gold. | A: Bazaar Safe |
| U67 | Trade-In Coupon | Tricky | 0 | — | 30 | — | — | The first reroll in each shop phase is free. | P: Balatro reroll vouchers |
| U68 | Collector's Shelf | Negative, Defence | 0 | — | 60 | — | — | +1 inventory slot. Start of battle: your body gains 10 Block for each part in your inventory. | C: Negative tag + bench |

### 4.13 Steam (Fire + Ice)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U69 | Boiler | Fire, Ice | 4 | 6 | 60 | — | — | Apply 4 Wet, then 4 Flame, to the part hit. They cancel into a burst of steam. | C: Water Cannon (C20) + Molotov (C17) |
| U70 | Pressure Valve | Fire, Ice | 0 | — | 50 | — | — | When Flame is put out on any part, your Fire and Ice parts gain 1 Speedup. | P: cancelling as a trigger |
| U71 | Thermal Shock Gun | Weapon, Fire, Ice | 4 | 5 | 50 | — | — | 30 damage. If the part hit has Freeze, apply Flame equal to its Freeze. Otherwise apply 4 Freeze. | R: Flame and Freeze cancelling (one feeds the other) |
| U72 | Condenser | Ice, Wind | 0 | — | 40 | L | — | Steam within range turns back into water at once. | M: steam condensing (instant) |

### 4.14 Rammer (Wheel)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U73 | Ram Spike | Weapon, Melee | 0 | — | 100 | — | — | When you ram the enemy, deal 40 damage to the part rammed. | A: CATS Climbing Wheel (damage on contact) |
| U74 | Booster Rocket | Wind | 3 | 8 | 40 | — | — | Launch the chariot forward. | A: CATS Booster |
| U75 | Pogo Spring | Tricky | 3 | 7 | 50 | — | — | Jump. When you land, deal 30 damage to enemy parts underneath. | R: CATS Lifter (lifts you, not them) |
| U76 | Spiked Wheel | Wheel, Melee | 2/s | — | 80 | — | — | A wheel. While driving, it fires as a melee weapon each second, dealing 8 damage to what it touches. | A: CATS Climbing Wheel |
| U77 | Harpoon | Tricky | 3 | — | 40 | — | — | Start of battle: pull both chariots together. | A: CATS Harpoon |

### 4.15 Last Stand (Defence / Tricky)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U78 | Adrenaline Injector | Tricky | 0 | — | 40 | — | — | The first time HP falls below half each battle, all your parts gain 5 Speedup. | A: Bazaar "first time below half health" |
| U79 | Emergency Plating | Defence | 0 | — | 60 | — | — | The first time you would die each battle, survive with 1 HP and your body gains 50 Block. | A: Bazaar "first time you would die" |
| U80 | Berserker Chip | Attack | 0 | — | 40 | — | — | Your weapons deal +1 damage per hit for every 2% of HP missing. | A: Noita Bloodlust |
| U81 | Last Rites | Tricky, Earth | 0 | — | 60 | — | — | When one of your parts breaks, it explodes (medium) where it falls. | C: part breaking + explosions |

### 4.16 Thorns (Defence)

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U82 | Spiked Armour | Defence | 0 | — | 120 | — | — | When this part is hit, deal 15 damage to the attacking part. | R: CATS Repulse (damages instead of pushing) |
| U83 | Reactive Plate | Defence | 0 | — | 100 | S | — | When Block on this part absorbs a hit, neighbouring weapons gain 1 Speedup. | P: Block absorbing as a trigger |
| U84 | Shock Plate | Defence, Electric | 0 | — | 100 | — | — | When this part is hit, apply 3 Shock to the attacking part. | C: Spiked Armour (U82) + Shock |
| U85 | Mirror Plating | Defence | 0 | — | 80 | S | — | When Block on a neighbour reaches 0, deal 30 damage to the attacking part. | P: Block breaking as a trigger |

### 4.17 Frames

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| U86 | Turret Mount | Tricky | 0 | — | 60 | — | 1 | A weapon mounted on this fires both forward and back, at half damage each way. | A: CATS Double Rocket |
| U87 | Gantry | Defence | 0 | — | 120 | — | 3 | Start of battle: parts mounted on this gain 10 Block. | M: Strut (more slots) |
| U88 | Hub Frame | Tricky | 0 | — | 60 | — | 2 | Parts mounted on this count as neighbours of each other and of this part, whatever the distance. | P: the mount tree as proximity |

## 5. Rare parts (38)

Very strong, usually a build's core. Price 12 gold.

### 5.1 Inferno

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R01 | Inferno Core | Fire | 6 | 10 | 60 | — | — | Double the Flame on every enemy part. | discussion example |
| R02 | Eternal Flame | Fire | 0 | — | 60 | — | — | Enemy parts that have Oil don't lose Flame over time. | E: Flame decay |
| R03 | Pyre | Fire | 5 | 5 | 60 | — | — | Deal damage to the enemy body equal to the enemy's Flame. | M: Bazaar Infernal Greatsword (whole chariot) |

### 5.2 Deep Freeze

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R04 | Absolute Zero | Weapon, Ice | 6 | 6 | 60 | — | — | Deal damage equal to 3 × the enemy's Freeze. | discussion example |
| R05 | Permafrost | Ice | 0 | — | 60 | — | — | Enemy parts that are Wet don't lose Freeze over time. | E: Freeze decay |
| R06 | Glacier Engine | Ice | 0 | — | 60 | — | — | When an enemy part gains Freeze, parts touching it gain half as much. | S: Shock jumping (Shock → Freeze) |

### 5.3 Shock Chain

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R07 | Storm Core | Electric | 0 | — | 60 | — | — | Your Shock keeps jumping, halving each hop, until it would be less than 1. | E: Shock's one-hop limit |
| R08 | Lightning Bolt | Weapon, Electric | 8 | 10 | 50 | — | — | 150 damage, apply 15 Shock. Sets off a large electric explosion. | A: Noita Lightning Bolt |
| R09 | Superconductor | Electric, Defence | 0 | — | 80 | — | — | Your Shock deals double damage. Your parts can't gain Shock. | C: damage boost + immunity |

### 5.4 Acid Eater

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R10 | Universal Solvent | Acid | 0 | — | 60 | — | — | Acid on enemy parts also damages the enemy's HP. | E: the integrity-only rule for part statuses |
| R11 | Matter Eater | Weapon, Acid, Beam | 4/s | Beam | 50 | — | — | 8 damage and 2 Acid per second. Dissolves all terrain in the beam except concrete. | A: Noita Matter Eater |

### 5.5 Fortress

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R12 | Aegis Mirror | Defence | 10 | 20 | 100 | — | — | Your body gains Block equal to your current HP. | discussion example |
| R13 | Iron Will | Defence, Tricky | 0 | — | 100 | — | — | Every 10 seconds, if your body's Block is greater than your HP, all your parts gain 10 Speedup. | discussion example |
| R14 | Citadel | Defence | 0 | — | 150 | — | 2 | Damage to any of your parts uses up your body's Block first. | M: Block (body's Block covers every part) |

### 5.6 Grinder

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R15 | Meshing Gearbox | Melee, Tricky | 0 | — | 60 | S | — | When a neighbouring melee weapon fires, every other neighbouring melee weapon also fires (once per tick). | C: Bazaar Bayonet + melee ticks |
| R16 | Bloodsaw | Weapon, Melee | 2/s | Melee | 80 | — | — | 15 damage per tick, +1 for every tick dealt this battle. | M: Bazaar Rolling Pin (grows per tick) |
| R17 | Grinding Engine | Melee, Stats | 0 | — | 60 | S | — | Neighbouring melee weapons cost no energy. | E: continuous energy cost |

### 5.7 Sniper

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R18 | Distance Lens | Attack, Beam | 0 | — | 50 | — | — | Your beams deal +1 damage per second for every 5 cells between you and the enemy. | discussion example |
| R19 | Piercing Railgun | Weapon | 10 | 12 | 60 | — | — | 500 damage, split evenly across every enemy part in a line. | M: Railgun (U37) |

### 5.8 Demolition

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R20 | Chain Detonator | Earth | 0 | — | 60 | — | — | When an explosion happens near the enemy, spawn a TNT crate there. | discussion example |
| R21 | Earthquake | Earth | 10 | 15 | 60 | — | — | Collapse the ground under the enemy down to hardness 8, exposing lava. | A: Noita Earthquake |
| R22 | Blast Amplifier | Earth, Defence | 0 | — | 100 | — | — | Explosions you cause are one size bigger. Your parts take no damage from your own explosions. | C: bigger blasts + immunity |

### 5.9 Gale

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R23 | Toxic Tempest | Wind | 4 | 3 | 60 | — | — | Every gas within 40 cells moves onto the enemy chariot. | M: Weather Vane (U52), stronger |
| R24 | Stormfront | Wind, Tricky | 0 | — | 60 | — | — | When an enemy part gains Slow, your parts gain the same amount of Speedup. | R: Slow (theirs becomes yours, reversed) |

### 5.10 Overclock

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R25 | Perpetual Gear | Tricky | 0 | — | 60 | S | — | When this gains Speedup, the part in front gains double. | discussion example |
| R26 | Overdrive | Tricky | 0 | — | 60 | — | — | Speedup on your parts runs cooldowns at triple speed instead of double. | M: Speedup |

### 5.11 Reactor

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R27 | Fusion Core | Stats, Tricky | 0 | — | 80 | — | — | While energy is full, the next part to fire fires twice. | discussion example |
| R28 | Blood Cell | Tricky | 0 | — | 60 | — | — | A part that would wait for energy fires anyway. You lose 10 HP for each energy you were short. | S: HP for energy |

### 5.12 Merchant

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R29 | Golden Gear | Weapon | 4 | 5 | 60 | — | — | 20 damage, +10 for every part you have sold this run. | discussion example |
| R30 | Bench Warmer | Negative, Tricky | 0 | — | 40 | — | — | +1 inventory slot. Passive effects of parts in your inventory work in battle. | P: inventory as a second chariot |

### 5.13 Steam

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R31 | Steam Engine | Fire, Ice | 0 | — | 80 | — | — | When statuses cancel on an enemy part, it takes 5 × the stacks cancelled as damage. | discussion example |

### 5.14 Rammer

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R32 | Juggernaut | Wheel, Tricky | 0 | — | 100 | — | — | While driving, your parts other than wheels cost no energy. | discussion example |
| R33 | Wrecking Gear | Melee | 0 | — | 100 | — | — | When you ram the enemy, each of your melee weapons fires 3 times. | C: ramming + melee firing |

### 5.15 Last Stand

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R34 | Death Wish | Tricky | 0 | — | 60 | — | — | While HP is below half, all your parts gain 1 Speedup each second. | discussion example |

### 5.16 Thorns

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R35 | Retribution | Defence | 0 | — | 120 | — | — | When Block absorbs damage on any of your parts, deal that much damage to the attacking part. | discussion example |
| R36 | Guardian Core | Defence | 0 | — | 150 | S | — | When a neighbour would take damage, this part takes it instead and gains Block equal to half. | discussion example |

### 5.17 Tricky and frames

| ID | Name | Tags | En | CD | Int | Rng | Ext | Effect | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| R37 | Mimic Module | Tricky | 0 | — | 50 | — | — | Copies the part in the slot immediately in front of it (the side it faces): same effect, firing mode, cooldown and energy cost. Its own integrity. | A: Balatro Blueprint |
| R38 | Exo-Frame | Tricky, Stats | 0 | — | 80 | — | 4 | Parts mounted on this have one size more range (S → M → L). | M: Hub Frame |

## 6. Open

- All numbers need playtesting, especially continuous energy costs against driving cost.
- Loops to watch for under the per-event chain cap: Meshing Gearbox (R15), Perpetual Gear (R25)
  with Gear Linkage (U54), Bench Warmer (R30) with inventory passives, and two Mimic Modules (R37)
  facing each other (proposed: a Mimic copying a Mimic does nothing).
