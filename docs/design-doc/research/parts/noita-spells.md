# Noita: Spells and Modifiers

All 422 spells in Noita (Epilogue 2 / current build), pulled from the Noita wiki's Spells Cargo table on 2026-11-03.

Source: https://noita.wiki.gg/wiki/Spell_Information_Table (Cargo table `Spells`). Stats are base values per the wiki.

## How spells work (summary)

- A wand holds a deck of spell cards and fires them left to right (or shuffled). Each cast draws spells until it has a projectile; **modifiers** in front of a projectile alter it, **multicasts** make the wand draw several more spells into one cast, **triggers/timers/expiration** spells carry a second payload cast that fires on hit, after a delay, or on death.
- Every spell has a mana cost; many also add to **cast delay** (time between casts) and **recharge time** (time to reload the deck once empty). Negative values speed the wand up.
- Spells with **uses** run out until refreshed at a Holy Mountain. **Tiers** (0-10) are where the spell can spawn in shops/wands; higher = deeper.
- **Always Cast** spells baked into a wand fire with every cast.

## Counts by type

| Type | Count |
|---|---|
| Projectile | 122 |
| Static projectile | 45 |
| Projectile modifier | 143 |
| Multicast | 14 |
| Material | 26 |
| Utility | 25 |
| Passive | 5 |
| Other | 42 |

Column key: **Mana** mana drain · **Uses** limited charges (blank = unlimited) · **Damage** base damage by type · **Delay** cast delay (s) · **Recharge** recharge time change (s) · **Mods** other stat changes · **Tier** spawn tiers · **Price** shop gold.

## Projectile (122)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| ??? | FUNKY_SPELL | 5 |  | proj 3.75, expl 10 | -0.05 |  | spread +2, crit% +1 | ??? *(Unlock: Find the Experimental wand (funky))* | 6,10 | 50 |
| Acid Ball | ACIDSHOT | 20 | 20 | proj 6 | +0.17 |  |  | A terrifying acidic projectile | 1,2,3,4 | 180 |
| Arrow | ARROW | 15 |  | proj 0, slice 5 | +0.17 |  | spread -20, bounces 1, recoil =30 | Summons an arrow | 1,2,4,5 | 140 |
| Ball Lightning | BALL_LIGHTNING | 70 |  | expl 6.25, elec 12.5 | +0.83 |  | recoil =120 | Summons three short range electrical orbs | 1,2,4,5 | 250 |
| Big Magic Guard | BIG_MAGIC_SHIELD | 60 |  | proj 2.25 | +0.50 |  |  | Eight guarding lights rotate around you for a time | 2,4,5,6,10 | 120 |
| Black Hole | BLACK_HOLE | 180 | 3 |  | +1.33 |  |  | A slow orb of void that eats through all obstacles | 0,2,4,5 | 200 |
| Black Hole with Death Trigger | BLACK_HOLE_DEATH_TRIGGER | 200 | 3 |  | +1.5 |  |  | A slow orb of void that eats through all obstacles and casts another spell as it expires | 2,4,5,6 | 220 |
| Blood Mist | MIST_BLOOD | 40 | 10 |  | +0.17 |  |  | A cloud of blood mist | 1,2,3,4 | 120 |
| Bomb | BOMB | 25 | 3 | expl 125 | +1.67 |  |  | Summons a bomb that destroys ground very efficiently | 0,1,2,3,4,5,6 | 200 |
| Bomb Cart | BOMB_CART | 75 | 6 | expl 100 | +1.00 |  | recoil +200 | Summons a self-propeled mine cart loaded with explosives | 2,3,4,5,6 | 200 |
| Bouncing Burst | RUBBER_BALL | 5 |  | proj 3 | -0.03 |  | spread -1, bounces 10 | A very bouncy projectile | 0,1,6 | 60 |
| Bubble Spark | BUBBLESHOT | 5 |  | proj 5 | -0.08 |  | bounces 20 | A bouncy, inaccurate spell | 0,1,2,3 | 100 |
| Bubble Spark With Trigger | BUBBLESHOT_TRIGGER | 16 |  | proj 5 | -0.08 |  | bounces 20 | A bouncy, inaccurate spell that casts another spell upon collision | 1,2,3 | 120 |
| Burst Of Air | AIR_BULLET | 5 |  | proj 5.75 | +0.05 |  | spread -2 | A brittle burst of air capable of greatly pushing objects | 1,2 | 80 |
| Chain Bolt | CHAIN_BOLT | 80 |  | proj 25 | +0.75 |  | spread +14 | Fires a mysterious bolt that jumps from enemy to enemy | 0,4,5,6 | 240 |
| Chainsaw | CHAINSAW | 1 |  | slice 12.75 | =0.00 | -0.17 | spread +6 | A good tool for cutting meat. Also has some magical properties... | 0,2 | 80 |
| Concentrated Light | LASER | 30 |  | proj 9.75, expl 5.5 | -0.37 |  | bounces 10, recoil +20 | A pinpointed beam of light | 1,2,4 | 180 |
| Cursed Sphere | CURSED_ORB | 40 |  | proj 15 | +0.33 |  | recoil =40 | A projectile that brings bad luck to anyone it hits | 1,2,3 | 200 |
| Deadly Heal | ANTIHEAL | 20 | 20 | proj 30 | +0.13 |  | recoil +12 | A projectile that at first deals damage, then heals over time | 2,3,4,5 | 200 |
| Death Cross | DEATH_CROSS | 80 |  | expl 75 | +0.67 |  | bounces 20 | A deadly energy cross that explodes after a short time | 1,2,3,4,5,6 | 210 |
| Digging Blast | POWERDIGGER | 0 |  | drill 2.5 | +0.02 | -0.17 |  | More powerful digging | 2,3,4 | 110 |
| Digging Bolt | DIGGER | 0 |  | drill 7.5 | +0.02 | -0.17 |  | A bolt that is ideal for mining operations | 1,2 | 70 |
| Disc Projectile | DISC_BULLET | 20 |  | slice 20 | +0.17 |  | spread +2, bounces 2, recoil =20 | Summons a sharp disc projectile | 0,2,4 | 120 |
| Dormant Crystal | PIPE_BOMB | 20 | 20 | expl 137.5 | +0.50 |  | speed× 0.75, bounces 4 | A crystal that explodes when caught in an explosion | 2,3,4 | 200 |
| Dormant Crystal With Trigger | PIPE_BOMB_DEATH_TRIGGER | 20 | 20 | expl 137.5 | +0.50 |  | speed× 0.75, recoil +60 | A crystal that explodes and casts another spell when caught in an explosion | 2,3,4,5 | 230 |
| Dropper Bolt | GRENADE_LARGE | 80 | 35 | proj 95, expl 97.5, fire 45 | +0.67 |  | bounces 1, recoil =80 | A very heavy explosive bolt | 0,1,2,3,4,5 | 150 |
| Dynamite | DYNAMITE | 50 | 16 | expl 62.5 | +0.83 |  | spread +6 | Summons a small explosive | 0,1,2,3,4 | 160 |
| Earthquake | CRUMBLING_EARTH | 240 | 3 |  |  |  |  | Calls the anger of the earth *(Unlock: Collect its Orb)* | 2,3,4,5,6 | 300 |
| Eldritch Portal | TENTACLE_PORTAL | 140 | 5 |  | +0.50 |  |  | Summons a one-way portal to a sinister realm | 1,2,3,4,10 | 220 |
| Energy Orb | SLOW_BULLET | 30 |  | proj 11.25, expl 4.5 | +0.10 |  | spread +3.6, recoil +20 | A slow but powerful orb of energy | 1,2,3,4 | 160 |
| Energy Orb With A Timer | SLOW_BULLET_TIMER | 50 |  | proj 11.25, expl 4.5 | +0.10 |  | spread +3.6, recoil +20 | A slow but powerful orb of energy that casts another spell after a timer runs out | 1,2,3,4,5,6 | 200 |
| Energy Orb With A Trigger | SLOW_BULLET_TRIGGER | 50 |  | proj 11.25, expl 4.5 | +0.42 |  | spread +10, recoil +20 | A slow but powerful orb of energy that casts another spell upon collision | 1,2,3,4,5 | 200 |
| Energy Sphere | BOUNCY_ORB | 20 |  | proj 5, slice 5 | +0.17 |  | bounces 5, recoil =20 | A fast, arcing projectile | 0,2,4 | 120 |
| Energy Sphere With Timer | BOUNCY_ORB_TIMER | 50 |  | proj 5, slice 5 | +0.17 |  | bounces 5, recoil =20 | A fast, arcing projectile that casts another spell after a timer runs out | 0,2,4 | 150 |
| Expanding Sphere | EXPANDING_ORB | 70 |  | proj 75 | +0.50 |  | recoil =20 | A slow projectile that increases its damage over time | 2,3,4,5,6 | 200 |
| Fireball | FIREBALL | 70 | 15 | expl 50, fire 6.25 | +0.83 |  | spread +4, recoil +20 | A powerful exploding spell | 0,3,4,6 | 220 |
| Firebolt | GRENADE | 50 | 25 | proj 32.5, expl 47.5, fire 12.5 | +0.50 |  | bounces 4, recoil =80 | A bouncy, explosive bolt | 0,1,2,3,4 | 170 |
| Firebolt With Trigger | GRENADE_TRIGGER | 50 | 25 | proj 32.5, expl 47.5, fire 12.5 | +0.50 |  | bounces 4, recoil =80 | A bouncy, explosive bolt that casts another spell upon collision | 0,1,2,3,4,5 | 210 |
| Firebomb | FIREBOMB | 10 |  | fire 10 |  |  |  | Slow, fiery bolt | 1,2,3 | 90 |
| Fireworks! | FIREWORK | 70 | 25 | proj 25, expl 30 | +1.00 |  | recoil =120 | A fiery, explosive projectile *(Unlock: Collect its Orb)* | 1,2,3,4,5,6 | 220 |
| Flamethrower | FLAMETHROWER | 20 | 60 | expl 12.5, fire 11.25 |  |  | spread +4 | A stream of fire!! | 2,3,4,6 | 220 |
| Flock Of Ducks | EXPLODING_DUCKS | 100 | 20 | proj 40, expl 60, fire 30 | +1.0 | +0.33 | bounces 5 | Summons a chaotic flock of spicy ducks *(Unlock: Collect its Orb)* | 3,4,5 | 200 |
| Freezing Gaze | FREEZING_GAZE | 45 | 20 | proj 0, ice 10 | +0.33 |  | bounces 10 | A heart-freezingly sinister aura | 2,3,4 | 180 |
| Giant Firebolt | GRENADE_TIER_3 | 90 | 20 | proj 50, expl 72.5, fire 45 | +1.33 |  | bounces 7, recoil =140 | The most powerful version of Firebolt | 1,2,3,4,5 | 220 |
| Giant Magic Missile | ROCKET_TIER_3 | 120 | 6 | proj 125, expl 130 | +2.00 |  | recoil =180 | The most powerful version of Magic missile | 2,3,4,5,6 | 250 |
| Giant Spitter Bolt | SPITTER_TIER_3 | 40 |  | proj 15 | -0.07 |  | spread +9, bounces 10 | The most powerful version of Spitter Bolt | 3,4,5,6 | 240 |
| Giant Spitter Bolt With Timer | SPITTER_TIER_3_TIMER | 45 |  | proj 15 | -0.07 |  | spread +9, bounces 10 | The most powerful version of Spitter Bolt that casts another spell after a timer runs out | 4,5,6 | 260 |
| Giga Death Cross | DEATH_CROSS_BIG | 150 | 8 | proj 0, expl 100 | +1.17 |  | bounces 20, recoil +30 | A giant, deadly energy cross that explodes after a short time | 2,3,4,5,6,10 | 310 |
| Giga Disc Projectile | DISC_BULLET_BIG | 38 |  | slice 62.5 | +0.33 |  | spread +3.4, bounces 2, recoil +20 | Summons a large, serrated disc with a curious flight pattern | 0,2,4 | 180 |
| Giga Holy Bomb | BOMB_HOLY_GIGA | 600 | 2 | expl 500, holy 0 | +2.0 | +2.67 | recoil +100 | Bigger and therefore holier *(Unlock: Bring a friend to the Avarice Diamond.)* | 10 | 600 |
| Giga Nuke | NUKE_GIGA | 500 | 1 | proj 250, expl 500 | =0.83 | +13.33 | speed× 0.50, recoil +300 | What do you expect? *(Unlock: Friendship achievement)* | 10 | 800 |
| Glitter Bomb | GLITTER_BOMB | 70 | 16 | expl 25 | +0.83 |  | spread +12 | Summons a bomb that explodes into volatile fragments | 0,1,2,3,4 | 200 |
| Glowing Lance | LANCE | 30 |  | proj 35 | +0.33 |  | spread -20, recoil =60 | A magical lance that cuts through soft materials | 1,2,5,6 | 180 |
| Glue Ball | GLUE_SHOT | 25 |  | proj 3 | +0.50 |  | spread +5, bounces 2 | A projectile that explodes into a sticky mess | 2,3,4,5 | 140 |
| Healing Bolt | HEAL_BULLET | 15 | 20 | heal -8.75 | +0.07 |  | spread +2 | A magical bolt that heals other beings | 2,3,4 | 60 |
| Holy Bomb | BOMB_HOLY | 300 | 2 | expl 200, holy 0 | +0.67 | +1.33 | recoil +100 | Summons a bomb that... well... *(Unlock: Collect its Orb)* | 2,3,4,5,6,10 | 400 |
| Holy Lance | LANCE_HOLY | 120 |  | proj 0, expl 30, holy 43.75 | +0.5 |  | spread -10, bounces 3, recoil =60 | A fast-flying, penetrating lance that glows with power | 3,5,6 | 250 |
| Homebringer Teleport Bolt | TELEPORT_PROJECTILE_CLOSER | 20 |  | proj 0, expl 0 |  |  | spread -2 | Brings the target hit closer to you | 0,1,2,4,5,6 | 130 |
| Hookbolt | HOOK | 30 |  | proj 7.5, expl 0 | +0.2 |  | recoil +10 | A glowing hook that pulls the caster towards itself upon collision | 1,2,3,4,5 | 120 |
| Iceball | ICEBALL | 90 | 15 | expl 50, ice 6 | 1.33 |  | spread +8, recoil +20 | A magical ball of frozen fire | 2,3,4,6 | 260 |
| Infestation | INFESTATION | 40 |  | proj 1.25 | -0.03 |  | spread +25, bounces 20 | A bunch of magical sparks that fly in every direction | 2,3,4 | 160 |
| Intense Concentrated Light | MEGALASER | 110 |  | proj 25, expl 5.5 | +1.50 |  | bounces 10, recoil +20 | A spectral wand is summoned that casts a huge beam of light | 3,4,5,6,10 | 300 |
| Large Firebolt | GRENADE_TIER_2 | 90 | 20 | proj 40, expl 60, fire 30 | +0.83 |  | bounces 5, recoil =120 | A more powerful version of Firebolt | 1,2,3,4,5 | 220 |
| Large Magic Missile | ROCKET_TIER_2 | 90 | 8 | proj 100, expl 117.5 | +1.50 |  | recoil =160 | A more powerful version of Magic missile | 2,3,4,5,6 | 240 |
| Large Spitter Bolt | SPITTER_TIER_2 | 25 |  | proj 12.5 | -0.03 |  | spread +7.5, bounces 10 | A more powerful version of Spitter Bolt | 2,3,4,5 | 190 |
| Large Spitter Bolt With Timer | SPITTER_TIER_2_TIMER | 30 |  | proj 12.5 | -0.03 |  | spread +7.5, bounces 10 | A more powerful version of Spitter Bolt that casts another spell after a timer runs out | 2,3,4,5 | 220 |
| Lightning Bolt | LIGHTNING | 70 |  | expl 125, elec 25 | +0.83 |  | recoil =180 | The primordial force of nature | 1,2,5,6 | 250 |
| Luminous Drill | LUMINOUS_DRILL | 10 |  | proj 10 | -0.58 | -0.17 |  | A pinpointed, short-ranged beam of concentrated light | 0,2,10 | 150 |
| Luminous Drill With Timer | LASER_LUMINOUS_DRILL | 30 |  | proj 10 | -0.58 | -0.17 |  | A pinpointed, short-ranged beam of concentrated light that casts another spell after a timer runs out | 0,2,6,10 | 220 |
| Magic Arrow | BULLET | 20 |  | proj 10 | +0.07 |  | spread +2, crit% +5, recoil +23 | A handy magical arrow | 1,2,3,4,5 | 150 |
| Magic Arrow With Timer | BULLET_TIMER | 35 |  | proj 10 | +0.07 |  | spread +2, crit% +5, recoil +23 | A magical arrow that casts another spell after a timer runs out | 2,3,4,5,6 | 190 |
| Magic Arrow With Trigger | BULLET_TRIGGER | 35 |  | proj 10 | +0.07 |  | spread +2, crit% +5, recoil +23 | A magical arrow that casts another spell upon collision | 1,2,3,4,5 | 190 |
| Magic Bolt | HEAVY_BULLET | 30 |  | proj 12.75 | +0.12 |  | spread +5, crit% +5, recoil +50 | A powerful magical bolt | 1,2,3,4,5,6 | 200 |
| Magic Bolt With Timer | HEAVY_BULLET_TIMER | 40 |  | proj 12.75 | +0.12 |  | spread +5, crit% +5, recoil +50 | A powerful magical bolt that casts another spell after a timer runs out | 2,3,4,5,6 | 240 |
| Magic Bolt With Trigger | HEAVY_BULLET_TRIGGER | 40 |  | proj 12.75 | +0.12 |  | spread +5, crit% +5, recoil +50 | A powerful magical bolt that casts another spell upon collision | 2,3,4,5,6 | 240 |
| Magic Guard | MAGIC_SHIELD | 40 |  | proj 1.25 | +0.33 |  |  | Four guarding lights rotate around you for a time | 2,4,5,6 | 100 |
| Magic Missile | ROCKET | 70 | 10 | proj 75, expl 105 | +1.00 |  | recoil =120 | A fiery, explosive projectile | 1,2,3,4,5 | 220 |
| Meteor | METEOR | 150 | 10 | expl 125, fire 56.25 |  |  |  | A destructive projectile from the skies! | 4,5,6,10 | 280 |
| Mist Of Spirits | MIST_ALCOHOL | 40 |  |  | +0.17 |  |  | A cloud of potent alcohol | 1,2,3,4 | 80 |
| Nuke | NUKE | 200 | 1 | proj 75, expl 250 | =0.33 | +10.00 | speed× 0.75, recoil +300 | Take cover! *(Unlock: Collect its Orb)* | 1,5,6,10 | 400 |
| Odd Firebolt | GRENADE_ANTI | 50 | 25 | proj 25, expl 47.5, fire 20 | +0.50 |  | bounces 4, recoil =80 | A somewhat peculiar bouncy, explosive bolt | 0,1,2,3,4,5 | 170 |
| Path Of Dark Flame | DARKFLAME | 90 | 60 | proj 20 | +0.33 |  |  | A trail of dark, deadly flames | 3,5,6 | 180 |
| Pinpoint Of Light | GLOWING_BOLT | 65 |  | proj 5, expl 10 | +0.67 |  | spread +6 | An extremely concentrated point of light that explodes after a moment | 3,4,5,10 | 220 |
| Plasma Beam | LASER_EMITTER | 60 |  | proj 20 | +0.10 |  | recoil +20 | An instantaneous, dangerous beam of light | 1,2,3,4 | 180 |
| Plasma Beam Cross | LASER_EMITTER_FOUR | 80 |  | proj 20 | +0.25 |  | recoil +30 | Four deadly plasma beams in a cross-shape. Look out, they can hurt you as well! | 1,2,3,4,5 | 200 |
| Plasma Cutter | LASER_EMITTER_CUTTER | 40 |  | proj 20 |  | +0.17 |  | A plasma beam specialized in cutting materials! | 0,1,2,3,4 | 120 |
| Pollen | POLLEN | 10 |  | proj 5, expl 5 | +0.03 |  | spread +20, bounces 1 | A small, floating projectile that homes towards nearby creatures | 0,1,3,4 | 110 |
| Prickly Spore Pod | SPORE_POD | 20 |  | proj 2.5 | +0.67 |  | recoil +30 | Summons a spore pod that attaches to a surface and then grows and explodes into spikes | 1,2,3,4,5 | 200 |
| Propane Tank | PROPANE_TANK | 75 | 10 | expl 325 | +1.67 |  |  | Summons a propane tank. Be careful what you wish for. | 2,3,4,5,6 | 200 |
| Random Projectile Spell | RANDOM_PROJECTILE | 20 |  |  |  |  |  | Casts one random projectile spell *(Unlock: Defeat Kolmisilmän koipi)* | 2,4,5,6,10 | 150 |
| Return | TELEPORT_PROJECTILE_STATIC | 40 |  |  | +0.05 |  | spread -2 | After a period of time, you'll be returned to where you cast this spell | 0,1,2,4,5,6 | 90 |
| Rock | SUMMON_ROCK | 100 | 3 |  |  |  |  | Create a mighty rock out of thin air | 0,1,2,3,4,5,6 | 160 |
| Slime Mist | MIST_SLIME | 40 |  |  | +0.17 |  |  | A cloud of slimy mist | 1,2,3,4 | 80 |
| Slimeball | SLIMEBALL | 20 |  | proj 6.25, expl 7.5 | +0.17 |  | spread +4, speed× 1.10 | A dripping ball of poisonous slime | 0,3,4 | 130 |
| Small Teleport Bolt | TELEPORT_PROJECTILE_SHORT | 20 |  |  |  |  | spread -2 | A shortlived magical bolt that moves you wherever it ends up flying | 0,1,2,4,5,6 | 130 |
| Spark Bolt | LIGHT_BULLET | 5 |  | proj 3 | +0.05 |  | spread -1, crit% +5 | A weak but enchanting sparkling projectile | 0,1,2 | 100 |
| Spark Bolt With Double Trigger | LIGHT_BULLET_TRIGGER_2 | 15 |  | proj 3.75, expl 2.5 | +0.07 |  | crit% +5 | A spark bolt that casts two new spells upon collision | 2,3,5,6,10 | 250 |
| Spark Bolt With Timer | LIGHT_BULLET_TIMER | 10 |  | proj 3 | +0.05 |  | crit% +5 | A spark bolt that casts another spell after a timer runs out | 1,2,3 | 140 |
| Spark Bolt With Trigger | LIGHT_BULLET_TRIGGER | 10 |  | proj 3 | +0.05 |  | crit% +5 | A spark bolt that casts another spell upon collision | 0,1,2,3 | 140 |
| Spiral Shot | SPIRAL_SHOT | 50 | 15 | proj 5 | +0.33 |  |  | A mystical whirlwind of magic sparks *(Unlock: Collect its Orb)* | 4,5,6 | 190 |
| Spitter Bolt | SPITTER | 5 |  | proj 7.5 | -0.02 |  | spread +6, bounces 10 | A short-lived magical bolt | 0,1,2,3 | 110 |
| Spitter Bolt With Timer | SPITTER_TIMER | 10 |  | proj 7.5 | -0.02 |  | spread +6, bounces 10 | A short-lived magical bolt that casts another spell after a timer runs out | 0,1,2,3 | 140 |
| Summon Deercoy | EXPLODING_DEER | 120 | 10 | expl 100 | +1.33 |  |  | Summons a seemingly-innocuous deer *(Unlock: Collect its Orb)* | 3,4,5 | 170 |
| Summon Egg | SUMMON_EGG | 100 | 2 |  |  |  |  | Summons an egg that houses a friendly creature | 0,1,2,3,4,5,6 | 220 |
| Summon Explosive Box | TNTBOX | 40 | 15 | expl 125 |  |  |  | Summons a box of explosive matter | 1,2,3,5 | 150 |
| Summon Fish | FISH | 90 | 20 |  | +1.33 |  | bounces 4 | FISH! *(Unlock: Upgrade a Hauen Leukaluu at the Anvil)* | 3,4,5 | 250 |
| Summon Hollow Egg | SUMMON_HOLLOW_EGG | 30 |  | expl 5 | -0.20 |  |  | Summons an otherwise empty egg that casts a spell upon cracking open | 0,1,2,5,6 | 140 |
| Summon Large Explosive Box | TNTBOX_BIG | 40 | 15 | expl 200 |  |  |  | Summons a large box of explosive matter | 2,4,5 | 170 |
| Summon Missile | MISSILE | 60 | 20 | proj 50, expl 25 |  | +0.50 | recoil +60 | A missile!!! | 1,2,3,5 | 200 |
| Summon Omega Sawblade | DISC_BULLET_BIGGER | 70 |  | proj +5, slice 38 | +0.67 |  | spread +6.4, bounces 10, recoil +30 | That's a lot of sawblade *(Unlock: Learn how to use the Broken Spell)* | 2,3,5,10 | 270 |
| Summon Rock Spirit | PEBBLE | 120 | 10 |  | +1.33 |  |  | Summons an autonomous rock ally | 1,2,4,6 | 200 |
| Summon Tentacle | TENTACLE | 20 |  | melee 20 | +0.67 |  |  | Calls a terrifying appendage from another dimension *(Unlock: Collect its Orb)* | 3,4,5,6 | 200 |
| Summon Tentacle With Timer | TENTACLE_TIMER | 20 |  | melee 20 | +0.67 |  |  | Calls a terrifying appendage from another dimension! Comes with a timer *(Unlock: Collect its Orb)* | 3,4,5,6 | 250 |
| Swapper | SWAPPER_PROJECTILE | 5 |  | proj 0, expl 0 | +0.05 |  | spread -2, crit% +5 | It was theorized that the source of qualia would be transferred ...But it turns out it was the whole body all along. | 0,1,2,4,5,6 | 100 |
| Teleport Bolt | TELEPORT_PROJECTILE | 40 |  |  | +0.05 |  | spread -2 | A magical bolt that moves you wherever it ends up flying | 0,1,2,4,5,6 | 130 |
| Thunder Charge | THUNDERBALL | 120 | 3 | expl 45, elec 37.5 | +2.00 |  |  | A projectile with immense stored electricity | 2,4,6,10 | 300 |
| Toxic Mist | MIST_RADIOACTIVE | 40 |  |  | +0.17 |  |  | A cloud of toxic mist | 1,2,3,4 | 80 |
| Triplicate Bolt | BUCKSHOT | 25 |  | proj 4.625 | +0.13 |  | spread +14, bounces 1 | A formation of three small, fast bolts | 0,1,2,3,4 | 160 |
| Unstable Crystal | MINE | 20 | 15 | expl 100 | +0.50 |  | speed× 0.75, recoil =60 | A crystal that explodes when someone comes nearby | 1,3,4,6 | 200 |
| Unstable Crystal With Trigger | MINE_DEATH_TRIGGER | 20 | 15 | expl 100 | +0.50 |  | speed× 0.75, recoil =60 | A crystal that explodes and casts another spell when someone comes nearby | 2,6 | 240 |
| White Hole | WHITE_HOLE | 180 | 3 |  | +1.33 |  |  | An orb of positive energy that destroys everything in its path | 0,2,4,6,10 | 200 |
| Worm Launcher | WORM_SHOT | 150 | 10 | melee 3 | +1.33 | +0.67 | bounces 10 | Summons a giant worm to cause havoc for a moment! *(Unlock: Collect its Orb)* | 3,4,5,6,10 | 200 |

## Static projectile (45)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Acid Cloud | CLOUD_ACID | 90 | 8 |  | +0.25 |  |  | Creates a rain of acid | 0,1,2,3,4,5 | 180 |
| Blood Cloud | CLOUD_BLOOD | 60 | 3 |  | +0.50 |  |  | Creates a rain of blood | 0,1,2,3,4,5 | 200 |
| Circle of Buoyancy | LEVITATION_FIELD | 10 | 15 |  | +0.25 |  |  | A field of levitative magic | 1,2,3,4 | 120 |
| Circle of Displacement | TELEPORTATION_FIELD | 30 | 15 |  | +0.25 |  |  | A field of teleportative magic | 0,1,2,3,4,5 | 150 |
| Circle of Fervour | BERSERK_FIELD | 30 | 15 |  | +0.25 |  |  | A field of berserk magic | 2,3,4 | 200 |
| Circle of Shielding | SHIELD_FIELD | 20 | 10 |  | +0.25 |  |  | A field of protective magic | 2,3,4,5,6 | 160 |
| Circle of Stillness | FREEZE_FIELD | 50 | 15 |  | +0.25 |  |  | A field of freezing magic | 0,2,4,5 | 200 |
| Circle of Thunder | ELECTROCUTION_FIELD | 60 | 15 |  | +0.25 |  |  | A field of electrifying magic | 1,3,5,6 | 200 |
| Circle of Transmogrification | POLYMORPH_FIELD | 50 | 5 |  | +0.25 |  |  | A field of sheep-like magic | 0,1,2,3,4,5,6 | 200 |
| Circle of Unstable Metamorphosis | CHAOS_POLYMORPH_FIELD | 20 | 10 |  | +0.25 |  |  | A field of transformative magic | 1,2,3,4,5,6 | 200 |
| Circle of Vigour | REGENERATION_FIELD | 80 | 2 | heal -1.25 | +0.25 |  |  | A field of regenerative magic | 1,2,3,4 | 250 |
| Delayed Spellcast | DELAYED_SPELL | 20 |  |  | +0.17 |  |  | A static, magical phenomenon that casts 3 extra spells after a short while | 0,1,2,4,5,6 | 240 |
| Destruction | DESTRUCTION | 240 | 5 |  | +2.5 | +4.00 |  | Instantly decimates foes around you, at the cost of your HP *(Unlock: Drunk Moon achievement)* | 10 | 600 |
| Explosion | EXPLOSION | 80 |  | expl 68.75 | +0.05 |  |  | A powerful explosion! | 0,2,4,5 | 160 |
| Explosion of Brimstone | FIRE_BLAST | 10 |  | expl 7.5 | +0.05 |  |  | A fiery explosion! | 0,1,3,5 | 120 |
| Explosion of Poison | POISON_BLAST | 30 |  | expl 7.5 | +0.05 |  |  | An alchemical explosion! | 1,2,4,6 | 140 |
| Explosion of Spirits | ALCOHOL_BLAST | 30 |  | expl 7.5 | +0.05 |  |  | An inebriating explosion | 1,2,4,6 | 140 |
| Explosion of Thunder | THUNDER_BLAST | 110 |  | expl 45 | +0.25 |  | recoil +30 | An electric explosion | 1,3,5,6,10 | 180 |
| Explosive Detonator | BOMB_DETONATOR | 50 |  |  |  |  |  | All nearby explosive spells cast by you instantly detonate | 2,3,4,5,6 | 120 |
| Giga Black Hole | BLACK_HOLE_BIG | 240 | 6 |  | +1.33 |  |  | A growing orb of negative energy that destroys everything in its reach | 1,3,5,6,10 | 320 |
| Giga White Hole | WHITE_HOLE_BIG | 240 | 6 |  | +1.33 |  |  | A growing orb of positive energy that destroys everything in its reach | 1,3,5,6,10 | 320 |
| Glittering Field | PURPLE_EXPLOSION_FIELD | 90 | 20 |  | +0.17 |  | speed× -2.00 | Small explosions appear randomly over a large area | 0,1,2,4,5,6 | 160 |
| Horizontal Barrier | WALL_HORIZONTAL | 70 |  | proj 32.25, expl 125 | +0.08 |  |  | A thin, horizontal barrier that harms passing creatures, including you | 0,1,2,4,5 | 160 |
| Liquid Vacuum Field | VACUUM_LIQUID | 40 | 20 |  | +0.17 |  |  | Sucks liquid materials nearby and releases them upon expiring | 2,4,5,6 | 150 |
| Magical Explosion | EXPLOSION_LIGHT | 80 |  | expl 93.75 | +0.05 |  |  | A large explosion that doesn't damage the ground | 2,3,5,6 | 160 |
| Matosade | WORM_RAIN | 225 | 2 |  | +1.67 | +1.0 |  | "Alea iacta est" *(Unlock: Defeat Sauvojen tuntija)* | 6,10 | 300 |
| Meteorisade | METEOR_RAIN | 225 | 2 |  | +1.67 | +1.0 |  | "Alea iacta est" *(Unlock: Defeat Sauvojen tuntija)* | 6,10 | 300 |
| Muodonmuutos | MASS_POLYMORPH | 220 | 3 |  | +2.33 | +4.0 |  | Baa *(Unlock: Defeat Tapion vasalli)* | 10 | 600 |
| Oil Cloud | CLOUD_OIL | 20 | 15 |  | +0.25 |  |  | Creates a rain of oil | 0,1,2,3,4,5 | 100 |
| Omega Black Hole | BLACK_HOLE_GIGA | 500 | 6 | proj 0, expl 0 | +2.0 | +1.67 |  | Even light dies eventually... *(Unlock: Complete the Sun Quest, and find the spell in the world.)* | 10 | 600 |
| Omega White Hole | WHITE_HOLE_GIGA | 500 | 6 | proj 0, expl 0, holy 210/s | +2.0 | +1.67 |  | A massive orb of positive energy that destroys everything in its reach *(Unlock: Complete the Sun Quest.)* | 10 | 600 |
| Powder Vacuum Field | VACUUM_POWDER | 50 | 20 |  | +0.17 |  |  | Sucks powder-like materials nearby and releases them upon expiring | 2,3,5,6 | 150 |
| Projectile Gravity Field | PROJECTILE_GRAVITY_FIELD | 120 | 3 |  | +0.25 |  |  | Projectiles caught within the field are attracted towards its center | 2,5,6 | 250 |
| Projectile Thunder Field | PROJECTILE_THUNDER_FIELD | 140 | 3 |  | +0.25 |  |  | Projectiles caught within the field transform into blasts of lightning | 3,4,5,6 | 300 |
| Projectile Transmutation Field | PROJECTILE_TRANSMUTATION_FIELD | 120 | 6 |  | +0.25 |  |  | Projectiles caught within the field transform into harmless critters | 2,3,4,5,6 | 250 |
| Rain Cloud | CLOUD_WATER | 30 | 10 |  | +0.25 |  |  | Creates a watery weather phenomenon | 0,1,2,3,4,5 | 140 |
| Random Static Projectile Spell | RANDOM_STATIC_PROJECTILE | 20 |  |  |  |  |  | Casts one random static projectile spell *(Unlock: Defeat Kolmisilmän koipi)* | 3,5,6,10 | 160 |
| Square Barrier | WALL_SQUARE | 70 | 20 | proj 32.25, expl 125 | +0.33 |  |  | A thin, square-shaped barrier that harms passing creatures, including you | 0,1,2,4,5,6 | 160 |
| Summon Firebug Swarm | SWARM_FIREBUG | 70 |  | fire 3.75 | +1.00 | +0.33 | spread +12, bounces 10 | Summons four fire bugs to aid you in battle | 2,5,6 | 100 |
| Summon Fly Swarm | SWARM_FLY | 60 |  | melee 3.5 | +1.00 | +0.33 | spread +6, bounces 10 | Summons five flies to aid you in battle | 2,4,5 | 90 |
| Summon Friendly Fly | FRIEND_FLY | 120 |  | melee 10 | +1.33 | +0.67 | spread +24, bounces 10 | Summons a friendly fly that attacks your enemies! | 4,5,6 | 160 |
| Summon Wasp Swarm | SWARM_WASP | 80 |  | melee 7 | +1.00 | +0.33 | spread +24, bounces 10 | Summon six wasps to aid you in battle | 4,5,6 | 120 |
| Thundercloud | CLOUD_THUNDER | 90 | 5 | elec 25 | +0.50 |  |  | Creates a thundercloud *(Unlock: Collect its Orb)* | 0,1,2,3,4,5 | 190 |
| Vacuum Field | VACUUM_ENTITIES | 50 | 20 |  | +0.17 |  |  | Sucks nearby projectiles and creatures into the middle of the field instantaneously | 2,3,5,6 | 200 |
| Vertical Barrier | WALL_VERTICAL | 70 |  | proj 32.25, expl 125 | +0.08 |  |  | A thin, vertical barrier that harms passing creatures, including you | 0,1,2,4,5 | 160 |

## Projectile modifier (143)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Accelerating Shot | ACCELERATING_SHOT | 20 |  |  | +0.13 |  | speed× 0.32, recoil +10 | Causes a projectile to accelerate as it flies | 2,3,4 | 190 |
| Accelerative Homing | HOMING_ACCELERATING | 60 |  |  |  |  |  | A projectile homes towards enemies at an increasing pace | 1,2,3,4 | 180 |
| Acid Trail | ACID_TRAIL | 15 |  |  |  |  |  | Gives a projectile a trail of acid | 1,2,3,4,5 | 160 |
| Add Mana | MANA_REDUCE | -30 |  |  | +0.17 |  |  | Immediately adds 30 mana to the wand | 1,2,3,4,5,6 | 250 |
| Aiming Arc | HOMING_CURSOR | 30 |  |  |  |  |  | A projectile rotates towards the direction you're aiming | 2,3,4,5,6 | 175 |
| Anti Homing | ANTI_HOMING | 1 |  |  | -0.33 |  |  | Makes a projectile accelerate away from your foes | 1,2,3,4,5,6 | 110 |
| Anti-Gravity | GRAVITY_ANTI | 1 |  |  |  |  |  | Applies a lifting force to a projectile | 2,3,4,5,6 | 50 |
| Auto-Aim | AUTOAIM | 25 |  |  |  |  |  | Makes a projectile turns towards the nearest visible enemy | 2,3,4,5,6 | 150 |
| Avoiding Arc | AVOIDING_ARC | 0 |  |  | +0.17 |  |  | Makes a projectile shy away from obstacles | 2,4,6 | 30 |
| Blood To Acid | BLOOD_TO_ACID | 30 |  |  | +0.17 |  |  | Makes any blood within a projectile's range turns into acid | 2,3,4 | 80 |
| Bloodlust | BLOODLUST | 2 |  | proj 32.5 | +0.13 |  | spread +6, recoil +30 | A projectile gains a hefty damage boost, but is also able to hurt you | 1,3,4,5,6 | 160 |
| Blue Glimmer | COLOUR_BLUE | 0 |  |  | -0.13 |  |  | Gives a projectile a blue sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4 | 40 |
| Boomerang | HOMING_SHOOTER | 10 |  |  |  |  |  | Gives a projectile a path that curves towards you | 2,3,4,6 | 100 |
| Bounce | BOUNCE | 0 |  |  |  |  |  | Makes a projectile bounce on impact | 2,3,4,6 | 50 |
| Bubbly Bounce | BOUNCE_SPARK | 20 |  |  | +0.13 |  | recoil +5 | Makes a projectile shoot bubble sparks as it bounces | 1,2,3,4 | 120 |
| Burning Trail | BURN_TRAIL | 5 |  |  |  |  |  | Gives a projectile a tail of fire | 0,1,2 | 100 |
| Chain Spell | CHAIN_SHOT | 70 |  | proj -5 |  |  | spread +10, lifetime -30 | Causes a projectile to cast a copy of itself upon expiring, up to 5 times | 2,4,5 | 240 |
| Chaos Larpa | LARPA_CHAOS | 100 |  |  | +0.25 |  |  | Makes a projectile cast copies of itself in random directions | 2,3,4,5,10 | 260 |
| Chaos Magic | RANDOM_EXPLOSION | 120 | 30 |  | +0.67 |  |  | Makes a projectile launch a random spell (out of a limited selection) when it hits something | 3,5,6 | 240 |
| Chaotic Path | CHAOTIC_ARC | 0 |  |  |  |  | speed× 2.00 | Causes a projectile to chaotically fly wherever it wishes | 1,3,5 | 10 |
| Chaotic Transmutation | TRANSMUTATION | 80 | 8 |  | +0.33 |  |  | Transmutes various liquids and powdery substances within a projectile's range into something else | 2,3,4,5,6,10 | 180 |
| Charm On Toxic Sludge | HITFX_TOXIC_CHARM | 70 |  |  |  |  |  | Makes a projectile charm creatures covered in toxic sludge | 1,3,4,5 | 150 |
| Clusterbolt | CLUSTERMOD | 30 |  | expl +5 | 0.33 |  | recoil +10 | Makes a projectile release a cluster of explosive bolts upon hitting a wall | 1,2,3 | 160 |
| Concentrated Explosion | EXPLOSION_TINY | 40 |  | expl +20 | +0.25 |  |  | Limits the radius of a projectile's explosion heavily | 2,4,5,6 | 160 |
| Concentrated Light Bounce | BOUNCE_LASER | 30 |  |  | +0.20 |  | recoil +5 | Makes a projectile release a bundle of concentrated light as it bounces | 3,4,5 | 180 |
| Copy Trail | LARPA_CHAOS_2 | 150 |  |  | +0.33 |  |  | Makes a projectile leave a trail of copies of itself *(Unlock: Open the Dark chest)* | 3,5,10 | 300 |
| Critical On Bloody Enemies | HITFX_CRITICAL_BLOOD | 10 |  |  |  |  | crit% +100 | Makes a projectile always do a critical hit on bloody enemies | 1,3,4,5 | 70 |
| Critical On Burning | HITFX_BURNING_CRITICAL_HIT | 10 |  |  |  |  | crit% +100 | Makes a projectile always do a critical hit on burning enemies | 1,3,4,5 | 70 |
| Critical On Oiled Enemies | HITFX_CRITICAL_OIL | 10 |  |  |  |  | crit% +100 | Makes a projectile always do a critical hit on oiled enemies | 1,3,4,5 | 70 |
| Critical On Wet (Water) Enemies | HITFX_CRITICAL_WATER | 10 |  |  |  |  | crit% +100 | Makes a projectile always do a critical hit on wet (water) enemies | 1,3,4,5 | 70 |
| Critical Plus | CRITICAL_HIT | 5 |  |  |  |  | crit% +15 | Gives a projectile +15% chance of a critical hit | 1,2,3,4,5 | 140 |
| Damage Field | AREA_DAMAGE | 30 |  | proj 3.5 |  |  |  | Gives a projectile an energy field that constantly deals 3.5 damage to nearby creatures | 2,3,4,5,6 | 140 |
| Damage Plus | DAMAGE | 5 |  | proj +10 | +0.08 |  | recoil +10 | Increases the damage done by a projectile | 1,2,3,4,5 | 140 |
| Decelerating Shot | DECELERATING_SHOT | 10 |  |  | -0.13 |  | speed× 1.68, recoil -10 | Makes a projectile decelerate as it flies | 2,3,4 | 80 |
| Downwards Bolt Bundle | ROCKET_DOWNWARDS | 90 |  | proj 32.5, expl 35 | +0.42 |  |  | Makes a projectile separate into a bundle of 5 explosive bolts as soon as it moves downwards | 1,2,3,4 | 200 |
| Downwards Larpa | LARPA_DOWNWARDS | 120 |  |  | +0.25 |  |  | Makes a projectile cast copies of itself with a downwards trajectory | 2,3,4,5,10 | 290 |
| Drilling Shot | CLIPPING_SHOT | 160 |  |  | +0.83 | +0.67 |  | Gives a projectile the power to go through the ground | 2,3,4,5,6 | 200 |
| Earthquake Shot | CRUMBLING_EARTH_PROJECTILE | 45 | 15 |  |  |  |  | Makes a projectile crumble the earth it hits | 1,2,3,4,5 | 200 |
| Electric Arc | ARC_ELECTRIC | 15 |  |  |  |  |  | Creates arcs of lightning between projectiles (requires 2 projectile spells) | 2,3,4,5,6 | 170 |
| Electric Charge | ELECTRIC_CHARGE | 8 |  | elec +2.5 |  |  |  | Gives a projectile an electric charge, that it will release on impact | 1,2,4,5 | 150 |
| Essence to Power | ESSENCE_TO_POWER | 110 |  |  | +0.33 |  |  | Increases a projectile's damage based on the number of creatures nearby | 1,2,3,6,10 | 120 |
| Explosion On Drunk Enemies | HITFX_EXPLOSION_ALCOHOL | 20 |  |  |  |  |  | Makes a projectile explode upon collision with creatures covered in alcohol | 1,3,4,5 | 140 |
| Explosion On Slimy Enemies | HITFX_EXPLOSION_SLIME | 20 |  |  |  |  |  | Makes a projectile explode upon collision with creatures covered in slime | 1,3,4,5 | 140 |
| Explosive Bounce | BOUNCE_EXPLOSION | 20 |  | proj 0, expl 37.5 | +0.42 |  | recoil +20 | Makes a projectile explode as it bounces | 2,3,4,5 | 180 |
| Explosive Projectile | EXPLOSIVE_PROJECTILE | 30 |  | expl +5 | +0.67 |  | speed× 0.75, recoil +30 | Makes a projectile more destructive to the environment | 2,3,4 | 120 |
| Fire Arc | ARC_FIRE | 15 |  |  |  |  |  | Creates arcs of fire between projectiles (requires 2 projectile spells) | 1,2,3,4,5 | 160 |
| Fire Trail | FIRE_TRAIL | 10 |  |  |  |  |  | Gives a projectile a trail of fiery particles | 0,1,2,3,4 | 130 |
| Fireball Orbit | ORBIT_FIREBALLS | 40 |  | expl 20, fire 4 |  |  |  | Makes four fireballs rotate around a projectile *(Unlock: Defeat Suomuhauki)* | 0,1,2,4,5 | 140 |
| Fireball Thrower | FIREBALL_RAY | 110 | 16 |  |  |  |  | Makes a projectile cast fireballs in random directions | 1,2,4,5 | 150 |
| Firecrackers | UNSTABLE_GUNPOWDER | 15 |  |  |  |  |  | Makes a projectile release firecrackers when it disappears | 2,3,4 | 140 |
| Fizzle | FIZZLE | 0 |  | proj 4.5 | -0.17 |  | speed× 1.2, bounces 10 | Gives a spell a small probability of short-circuiting | 3,4,5 | 0 |
| Floating Arc | FLOATING_ARC | 0 |  |  | +0.17 |  |  | Makes a projectile float above the ground | 1,3,5 | 30 |
| Fly Downwards | FLY_DOWNWARDS | 0 |  |  | -0.13 |  | speed× 1.2 | Causes a projectile to aim straight downwards a short time after casting | 1,3,5 | 30 |
| Fly Upwards | FLY_UPWARDS | 0 |  |  | -0.13 |  | speed× 1.2 | Causes a projectile to aim straight upwards a short time after casting | 2,4,6 | 20 |
| Freeze Charge | FREEZE | 10 |  | ice +5 |  |  |  | Gives a projectile a frozen charge, that it will release on impact | 1,3,4,5 | 140 |
| Giant Explosion On Drunk Enemies | HITFX_EXPLOSION_ALCOHOL_GIGA | 200 | 20 |  |  |  |  | Makes a projectile explode powerfully upon collision with creatures covered in alcohol | 1,3,4,5 | 300 |
| Giant Explosion On Slimy Enemies | HITFX_EXPLOSION_SLIME_GIGA | 200 | 20 |  |  |  |  | Makes a projectile explode powerfully upon collision with creatures covered in slime | 1,3,4,5 | 300 |
| Gravity | GRAVITY | 1 |  |  |  |  |  | Increases the effect gravity has on a projectile | 2,3,4,5,6 | 50 |
| Green Glimmer | COLOUR_GREEN | 0 |  |  | -0.13 |  |  | Gives a projectile a green sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4 | 40 |
| Ground To Sand | STATIC_TO_SAND | 70 | 8 |  | +1.00 |  |  | Makes any hard, solid materials within a projectile's range turn into sand | 2,3,4,10 | 140 |
| Gunpowder Arc | ARC_GUNPOWDER | 15 |  |  |  |  |  | Creates arcs of gunpowder between projectiles (requires 2 projectile spells) | 1,2,3,4,5 | 160 |
| Gunpowder Trail | GUNPOWDER_TRAIL | 10 |  |  |  |  |  | Gives a projectile a trail of gunpowder | 2,3,4 | 160 |
| Heavy Shot | HEAVY_SHOT | 7 |  | proj +43.75 | +0.17 |  | speed× 0.30, recoil +50 | Greatly increases the damage done by a projectile, at the cost of its speed | 2,3,4 | 150 |
| Heavy Spread | HEAVY_SPREAD | 2 |  |  | -0.12 | -0.25 | spread +720 | Gives a projectile a much lower cast delay, but no respect to your aim | 0,1,2,4,5,6 | 100 |
| Homing | HOMING | 70 |  |  |  |  |  | Makes a projectile accelerate towards your foes | 1,2,3,4,5,6 | 220 |
| Horizontal Path | HORIZONTAL_ARC | 0 |  | proj +7.5 | -0.10 |  |  | Forces a projectile on a horizontal path, but increases its damage | 1,3,5 | 20 |
| Increase Lifetime | LIFETIME | 40 |  |  | +0.22 |  | lifetime +75 | Increases the lifetime of a spell | 3,4,5,6,10 | 250 |
| Invisible Spell | COLOUR_INVIS | 0 |  |  | -0.13 |  |  | Turns a projectile invisible *(Unlock: Find the Experimental Wand (paint))* | 2,3,4,10 | 40 |
| Knockback | KNOCKBACK | 5 |  |  |  |  |  | Gives a projectile the power to knock back the foes it hits | 3,5 | 100 |
| Larpa Bounce | BOUNCE_LARPA | 80 |  |  | +0.53 |  | recoil +10 | A projectile will launch a copy of itself when it bounces | 4,5,6 | 250 |
| Larpa Explosion | LARPA_DEATH | 90 | 30 |  | +0.25 |  |  | A projectile will shoot out 8 copies of itself when it expires or hits the ground | 2,3,4,5,10 | 150 |
| Lava To Blood | LAVA_TO_BLOOD | 30 |  |  | +0.17 |  |  | Makes any lava within a projectile's range turn into blood | 2,3,4 | 80 |
| Light | LIGHT | 1 |  |  |  |  |  | Makes a projectile illuminate its surroundings | 0,1,2,3,4 | 20 |
| Light Shot | LIGHT_SHOT | 5 |  | proj -25 | -0.05 |  | spread -6, speed× 7.50, recoil -10 | Makes a projectile move considerably faster, but deal less damage | 2,3,4 | 60 |
| Lightning Bounce | BOUNCE_LIGHTNING | 40 |  | expl 75, elec 20 | +0.42 |  | recoil +10 | Makes a projectile release powerful lightning as it bounces | 1,3,5 | 180 |
| Lightning Thrower | LIGHTNING_RAY | 110 | 16 |  |  |  |  | Makes a projectile cast lightning in random directions | 2,3,4,5 | 180 |
| Linear Arc | LINE_ARC | 0 |  | proj +5 | -0.07 |  |  | Makes a projectile fly only in cardinal or diagonal lines | 1,3,5 | 30 |
| Liquid Detonation | LIQUID_TO_EXPLOSION | 40 |  |  | +0.33 |  |  | Converts nearby nonmagical liquids into explosive gunpowder | 2,3,4 | 120 |
| Mana To Damage | DAMAGE_FOREVER | 0 | 20 |  | +0.25 | +0.17 | recoil +10 | If the wand has more than 50 mana, all mana over that is converted into additional damage | 2,3,4,5,6,10 | 240 |
| Matter Eater | MATTER_EATER | 120 | 10 |  |  |  |  | Makes a projectile eat the environment as it flies | 1,2,4,5,10 | 280 |
| Necromancy | NECROMANCY | 20 |  |  | +0.17 |  |  | Makes corpses of creatures killed by a projectile rise to your aid *(Unlock: Collect its Orb)* | 2,3,4,5 | 80 |
| Nolla | NOLLA | 1 |  |  | -0.25 |  |  | The duration of a projectile is set to zero *(Unlock: Defeat Kolmisilmän koipi)* | 2,4,5,6,10 | 50 |
| Nuke Orbit | ORBIT_NUKES | 250 | 3 |  |  |  |  | Makes four… nukes(?!) rotate around a projectile *(Unlock: Defeat Suomuhauki)* | 2,4,5,6,10 | 400 |
| Null Shot | ZERO_DAMAGE | 5 |  | proj =0, expl =0, slice =0, drill =0, fire =0, ice =0, elec =0, holy =0, heal =0 | -0.08 |  | lifetime +280, crit% =0, recoil -10 | Increases a projectile's duration dramatically but removes all damage and explosion from it | 3,4,5,10 | 50 |
| Octagonal Bolt Bundle | ROCKET_OCTAGON | 100 |  | proj 32.5, expl 35 | +0.33 |  |  | Makes a projectile launch 8 magical bolts if it moves slowly enough | 2,3,4 | 200 |
| Oil Trail | OIL_TRAIL | 10 |  |  |  |  |  | Gives a projectile a trail of oil | 2,3,4 | 160 |
| Orange Glimmer | COLOUR_ORANGE | 0 |  |  | -0.13 |  |  | Gives a projectile a orange sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4 | 40 |
| Orbit Larpa | ORBIT_LARPA | 90 |  |  |  |  |  | Makes four copies of a projectile rotate around it *(Unlock: Defeat Suomuhauki)* | 3,4,6,10 | 240 |
| Orbiting Arc | ORBIT_SHOT | 0 |  | proj +2.5 | -0.10 |  | lifetime +25 | A projectile orbits the point of its origin | 1,2,3,4 | 30 |
| Personal Fireball Thrower | FIREBALL_RAY_ENEMY | 90 | 20 |  |  |  |  | Makes a projectile turn the creatures it hits into living fireball throwers | 1,2,4,5 | 100 |
| Personal Gravity Field | GRAVITY_FIELD_ENEMY | 110 | 20 |  |  |  |  | Makes creatures hit by a projectile gain a temporary gravity well that draws projectiles in | 1,2,4,5 | 250 |
| Personal Lightning Caster | LIGHTNING_RAY_ENEMY | 90 | 20 |  |  |  |  | Makes a projectile turn the creatures it hits into living thunderstorms | 2,3,4,5 | 150 |
| Personal Tentacler | TENTACLE_RAY_ENEMY | 90 | 20 |  |  |  |  | Makes creatures hit by a projectile grow tentacles in a chaotic manner | 2,3,4,5 | 150 |
| Petrify | HITFX_PETRIFY | 10 |  |  |  |  |  | Turns a wounded enemy into stone | 2,3,5,6 | 140 |
| Phasing Arc | PHASING_ARC | 2 |  |  | -0.10 |  | speed× 0.33, lifetime +80 | Makes a projectile fly much slower, but teleport short distances over its flight | 2,3,4,5 | 170 |
| Piercing Shot | PIERCING_SHOT | 140 |  | proj -15 |  |  |  | Makes a projectile fly through enemies, but harmful to the caster | 2,3,4,5,6 | 190 |
| Ping-Pong Path | PINGPONG_PATH | 0 |  |  |  |  | lifetime +25 | Makes a projectile fly back and forth | 1,3,5 | 20 |
| Plasma Beam Bounce | BOUNCE_LASER_EMITTER | 40 |  |  | +0.20 |  | recoil +5 | A projectile launches a plasma beam upon bouncing | 3,4,5 | 180 |
| Plasma Beam Enhancer | LASER_EMITTER_WIDER | 10 |  |  |  |  |  | Makes plasma beam spell's beam wider | 2,3,4 | 40 |
| Plasma Beam Orbit | ORBIT_LASERS | 100 |  |  |  |  |  | Makes four plasma beams rotate around a projectile *(Unlock: Defeat Suomuhauki)* | 1,2,4,5,10 | 200 |
| Plasma Beam Thrower | LASER_EMITTER_RAY | 110 | 16 |  |  |  |  | A projectile fires beams of light in random directions | 2,3,4,5 | 150 |
| Poison Arc | ARC_POISON | 15 |  |  |  |  |  | Creates arcs of poison between projectiles (requires 2 projectile spells) | 1,2,3,4,5 | 160 |
| Poison Trail | POISON_TRAIL | 10 |  |  |  |  |  | Gives a projectile a trail of poison | 2,3,4 | 160 |
| Projectile Area Teleport | HOMING_AREA | 60 |  |  | +0.13 |  | speed× 0.75 | If a valid target appears somewhere in the proximity of a projectile, the projectile will teleport right on top of the target | 2,3,4,5,6 | 175 |
| Projectile Energy Shield | ENERGY_SHIELD_SHOT | 5 |  |  |  |  | speed× 0.40 | Gives a projectile a shield that deflects other projectiles | 2,3,4,5,6 | 180 |
| Purple Glimmer | COLOUR_PURPLE | 0 |  |  | -0.13 |  |  | Gives a projectile a purple sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4 | 40 |
| Quantum Split | QUANTUM_SPLIT | 10 |  |  | +0.08 |  |  | Makes a projectile split into three projectiles whose existences are entangled | 2,3,4,5,6 | 200 |
| Rainbow Glimmer | COLOUR_RAINBOW | 0 |  |  | -0.13 |  |  | Gives a projectile a randomly colored sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4,10 | 40 |
| Rainbow Trail | RAINBOW_TRAIL | 0 |  |  |  |  |  | Gives a projectile a trail of rainbow *(Unlock: Find the platform)* | 10 | 100 |
| Random Damage | DAMAGE_RANDOM | 15 |  |  | +0.08 |  |  | Randomly increases or lowers the damage done by projectiles *(Unlock: Defeat Kolmisilmän koipi)* | 3,4,5 | 200 |
| Random Modifier Spell | RANDOM_MODIFIER | 20 |  |  |  |  |  | Casts one random modifier spell *(Unlock: Defeat Kolmisilmän koipi)* | 4,5,6,10 | 120 |
| Recoil | RECOIL | 5 |  |  |  |  | recoil +200 | Increases the recoil when casting spells | 2,4 | 100 |
| Recoil Damper | RECOIL_DAMPER | 5 |  |  |  |  | recoil -200 | Reduces the recoil when casting spells | 3,6 | 100 |
| Red Glimmer | COLOUR_RED | 0 |  |  | -0.13 |  |  | Gives a projectile a red sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 1,2,3,4,5,6 | 40 |
| Reduce Lifetime | LIFETIME_DOWN | 10 |  |  | -0.25 |  | lifetime -42 | Reduces the lifetime of a spell | 3,4,5,6,10 | 90 |
| Reduce Recharge Time | RECHARGE | 12 |  |  | -0.17 | -0.33 |  | Reduces the time between spellcasts | 1,2,3,4,5,6 | 200 |
| Reduce Spread | SPREAD_REDUCE | 1 |  |  |  |  | spread -60 | Reduces the spread of a spell | 1,2,3,4,5,6 | 100 |
| Remove Bounce | REMOVE_BOUNCE | 0 |  |  |  |  |  | A normally bouncy projectile stops doing so | 2,3,4,5 | 50 |
| Remove Explosion | EXPLOSION_REMOVE | 0 |  | expl -20 | -0.25 |  |  | Makes a projectile no longer explode | 2,4,5,6 | 50 |
| Rotate Towards Foes | HOMING_ROTATE | 40 |  |  |  |  |  | Makes a projectile turn towards your foes | 2,3,4,5,6 | 175 |
| Sawblade Orbit | ORBIT_DISCS | 70 |  |  |  |  |  | Makes four sawblades rotate around a projectile *(Unlock: Defeat Suomuhauki)* | 1,2,4,5 | 200 |
| Short-range Homing | HOMING_SHORT | 40 |  |  |  |  |  | A projectile flies towards targets when near them | 1,2,3,4,5,6 | 160 |
| Slithering Path | SINEWAVE | 0 |  |  |  |  | speed× 2.00 | Makes a projectile move rapidly in a slithering manner, like a snake | 2,4,6 | 10 |
| Slow But Steady | SLOW_BUT_STEADY | 0 |  |  |  | =1.50 | recoil -80 | The reload time of the wand is set to exactly 1.5 seconds *(Unlock: Find the Experimental wand (math))* | 3,4,5,6,10 | 50 |
| Sparkly Bounce | BOUNCE_SMALL_EXPLOSION | 10 |  |  | +0.15 |  | recoil +10 | Makes a projectile release damaging sparks as it bounces | 0,1,2 | 100 |
| Speed Up | SPEED | 3 |  |  |  |  | speed× 2.50 | Increases the speed at which a projectile flies through the air | 1,2,3 | 100 |
| Spells To Power | SPELLS_TO_POWER | 110 |  |  | +0.33 |  |  | Converts any nearby projectiles cast by you into extra damage | 2,3,4,5,6,10 | 140 |
| Spiral Arc | SPIRALING_SHOT | 0 |  | proj +2.5 | -0.10 |  | lifetime +50 | A projectile flies in a spiralling pattern | 1,2,3,4 | 30 |
| Tentacler | TENTACLE_RAY | 110 | 16 |  |  |  |  | Makes a projectile cast tentacles in random directions | 1,3,4,5 | 150 |
| Toxic Sludge To Acid | TOXIC_TO_ACID | 50 |  |  | +0.17 |  |  | Makes any toxic sludge within a projectile's range turn into acid | 2,3,4 | 120 |
| True Orbit | TRUE_ORBIT | 2 |  | proj 2.5 | -0.33 |  | lifetime +80 | Makes a projectile rotate around the caster like an orbiting planet | 2,3,4 | 40 |
| Two-Way Fireball Thrower | FIREBALL_RAY_LINE | 130 | 20 |  |  |  |  | Makes a projectile fire small fireballs perpendicular to its trajectory | 2,3,4,5,6 | 120 |
| Upwards Larpa | LARPA_UPWARDS | 120 |  |  | +0.25 |  |  | Makes a projectile cast copies of itself with an upwards trajectory | 2,3,4,5,10 | 290 |
| Vacuum Bounce | BOUNCE_HOLE | 60 | 20 |  | +0.67 |  | recoil +10 | Makes a projectile remove earth as it bounces | 2,4,6,10 | 220 |
| Venomous Curse | CURSE | 30 |  |  |  |  |  | Imbues a projectile with a curse that makes the target hit by the projectile to waste away | 2,3,5,10 | 140 |
| Wand Homing | HOMING_WAND | 200 |  |  |  |  |  | Makes a projectile accelerate towards wands *(Unlock: Defeat Master of Masters by drowning it in Swamp)* | 1,2,4,5,6,10 | 500 |
| Water To Poison | WATER_TO_POISON | 30 |  |  | +0.17 |  |  | Makes any water within a projectile's range turns into poison | 2,3,4 | 80 |
| Water Trail | WATER_TRAIL | 10 |  |  |  |  |  | Gives a projectile a trail of water | 1,2,3,4 | 160 |
| Weakening Curse - Electricity | CURSE_WITHER_ELECTRICITY | 50 |  |  |  |  |  | Target hit by a projectile takes 25% extra electricity damage for a time | 1,4,5,6,10 | 100 |
| Weakening Curse - Explosives | CURSE_WITHER_EXPLOSION | 50 |  |  |  |  |  | Target hit by a projectile takes 25% extra explosion damage for a time | 2,3,4,5,10 | 100 |
| Weakening Curse - Melee | CURSE_WITHER_MELEE | 50 |  |  |  |  |  | Target hit by a projectile takes 25% extra melee damage for a time | 3,4,5,6,10 | 100 |
| Weakening Curse - Projectiles | CURSE_WITHER_PROJECTILE | 50 |  |  |  |  |  | Target hit by a projectile takes 25% extra projectile damage for a time | 3,4,5,6,10 | 100 |
| Yellow Glimmer | COLOUR_YELLOW | 0 |  |  | -0.13 |  |  | Gives a projectile a yellow sparkly trail *(Unlock: Find the Experimental Wand (paint))* | 2,3,4 |  |

## Multicast (14)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Double Scatter Spell | SCATTER_2 | 0 |  |  |  |  | spread +10 | Simultaneously casts 2 spells with low accuracy | 0,1,2 | 100 |
| Double Spell | BURST_2 | 0 |  |  |  |  |  | Simultaneously casts 2 spells | 0,1,2,3,4,5,6 | 140 |
| Formation - Above And Below | T_SHAPE | 3 |  |  |  |  | spread -8 | Casts 3 spells - ahead, above and below the caster | 1,2,3,4 | 30 |
| Formation - Behind Your Back | I_SHAPE | 0 |  |  |  |  | spread -5 | Casts two spells: one ahead of and one behind the caster | 1,2,3 | 30 |
| Formation - Bifurcated | Y_SHAPE | 2 |  |  |  |  | spread -8 | Casts 2 spells in a bifurcated pattern | 0,1,2,3 | 30 |
| Formation - Hexagon | CIRCLE_SHAPE | 6 |  |  |  |  | spread -15 | Casts 6 spells in a hexagonal pattern | 1,2,3,4,5,6 | 50 |
| Formation - Pentagon | PENTAGRAM_SHAPE | 5 |  |  |  |  | spread -12 | Casts 5 spells in a pentagonal pattern | 1,2,3,4,5 | 50 |
| Formation - Trifurcated | W_SHAPE | 3 |  |  |  |  | spread -5 | Casts 3 spells in a trifurcated pattern | 2,3,4,5,6 | 50 |
| Myriad Spell | BURST_X | 50 | 30 |  |  |  |  | Simultaneously casts as many spells as you have left uncast in your wand *(Unlock: Open the Coral Chest)* | 5,6,10 | 500 |
| Octuple Spell | BURST_8 | 30 |  |  |  |  |  | Simultaneously cast 8 spells *(Unlock: Open the Coral Chest)* | 5,6,10 | 300 |
| Quadruple Scatter Spell | SCATTER_4 | 2 |  |  |  |  | spread +40 | Simultaneously casts 4 spells with low accuracy | 1,2,3,4,5,6 | 140 |
| Quadruple Spell | BURST_4 | 5 |  |  |  |  |  | Simultaneously casts 4 spells | 2,3,4,5,6 | 180 |
| Triple Scatter Spell | SCATTER_3 | 1 |  |  |  |  | spread +20 | Simultaneously casts 3 spells with low accuracy | 0,1,2,3 | 120 |
| Triple Spell | BURST_3 | 2 |  |  |  |  |  | Simultaneously casts 3 spells | 1,2,3,4,5,6 | 160 |

## Material (26)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Acid | MATERIAL_ACID | 0 |  |  | -0.25 | -0.17 |  | Transmute drops of acid from nothing | 2,3,4,5,6 | 150 |
| Blood | MATERIAL_BLOOD | 0 | 250 |  | -0.25 | -0.17 |  | Blood blood blood | 1,2,3,4,5 | 130 |
| Cement | MATERIAL_CEMENT | 0 |  |  | -0.25 | -0.17 |  | Transmute drops of wet cement from nothing *(Unlock: Collect its Orb)* | 2,3,4,5,6 | 100 |
| Chunk Of Soil | SOILBALL | 5 |  |  |  |  |  | Don't soil yourself | 1,2,3,5 | 10 |
| Circle of Acid | CIRCLE_ACID | 40 | 4 |  | +0.33 |  |  | An expanding circle of dripping acid | 1,2,3,4 | 180 |
| Circle of Fire | CIRCLE_FIRE | 20 | 15 |  | +0.33 |  |  | An expanding circle of burning air | 1,2,3,4 | 170 |
| Circle of Oil | CIRCLE_OIL | 20 | 15 |  | +0.33 |  |  | An expanding circle of slick oil | 1,2,3,4 | 160 |
| Circle of water | CIRCLE_WATER | 20 | 15 |  | +0.33 |  |  | An expanding circle of water | 1,2,3,4 | 160 |
| Oil | MATERIAL_OIL | 0 |  |  | -0.25 | -0.17 |  | Transmute drops of oil from nothing | 1,2,3,4,5 | 140 |
| Sea Of Acid | SEA_ACID | 140 | 3 |  | +0.25 |  |  | Summons a large body of acid below the caster | 0,4,5,6 | 350 |
| Sea Of Alcohol | SEA_ALCOHOL | 140 | 3 |  | +0.25 |  |  | Summons a large body of tasty alcohol below the caster | 0,4,5,6 | 350 |
| Sea Of Flammable Gas | SEA_ACID_GAS | 140 | 3 |  | +0.25 |  |  | Summons a large body of flammable gas below the caster | 0,4,5,6 | 200 |
| Sea Of Lava | SEA_LAVA | 140 | 3 |  | +0.25 |  |  | Summons a large body of lava below the caster *(Unlock: Collect its Orb)* | 0,4,5,6 | 350 |
| Sea of Mimicium | SEA_MIMIC | 140 | 2 |  | +0.25 |  |  | Summons a large body of mimicium under the caster *(Unlock: Awaken 10 Potion Mimics)* | 0,4,5,6,10 | 350 |
| Sea Of Oil | SEA_OIL | 140 | 3 |  | +0.25 |  |  | Summons a large body of oil below the caster | 0,4,5,6 | 350 |
| Sea Of Water | SEA_WATER | 140 | 3 |  | +0.25 |  |  | Summons a large body of water below the caster | 0,4,5,6 | 350 |
| Summon Swamp | SEA_SWAMP | 140 | 3 |  | +0.25 |  |  | Summons a large swamp below the caster | 0 | 350 |
| Touch Of Blood | TOUCH_BLOOD | 270 | 3 |  |  |  |  | Transmutes everything in a short radius into blood, including walls, creatures... and you | 5,6,7,10 | 390 |
| Touch Of Gold | TOUCH_GOLD | 300 | 1 |  |  |  |  | Transmutes everything in a short radius into gold, including walls, creatures... and you | 5,6,7,10 | 480 |
| Touch of Gold? | TOUCH_PISS | 190 | 4 |  |  |  |  | Transmutes everything in a short radius into urine, including walls, creatures... and you *(Unlock: Destroying the Outhouse)* | 5,6,7,10 | 360 |
| Touch of Grass | TOUCH_GRASS | 190 | 4 |  |  |  |  | Transmutes everything in a short radius into Earth, including walls, creatures... and you. Unless… *(Unlock: Cast Sea of Mimicium at the right spot)* | 1,2,3,4,5,6,7,10 | 360 |
| Touch Of Oil | TOUCH_OIL | 260 | 5 |  |  |  |  | Transmutes everything in a short radius into oil, including walls, creatures... and you | 5,6,7,10 | 380 |
| Touch Of Smoke | TOUCH_SMOKE | 230 | 5 |  |  |  |  | Transmutes everything in a short radius into smoke, including walls, creatures... and you | 5,6,7,10 | 350 |
| Touch Of Spirits | TOUCH_ALCOHOL | 240 | 5 |  |  |  |  | Transmutes everything in a short radius into alcohol, including walls, creatures... and you | 5,6,7,10 | 360 |
| Touch Of Water | TOUCH_WATER | 280 | 5 |  |  |  |  | Transmutes everything in a short radius into water, including walls, creatures... and you | 5,6,7,10 | 420 |
| Water | MATERIAL_WATER | 0 |  |  | -0.25 | -0.17 |  | Transmute drops of water from nothing | 1,2,3,4,5 | 110 |

## Utility (25)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| All-Seeing Eye | X_RAY | 100 | 10 | drill 0.25 |  |  |  | See into the unexplored. But not everywhere... | 0,1,2,3,4,5,6 | 230 |
| Blood Magic | BLOOD_MAGIC | -100 |  |  | -0.33 | -0.33 |  | Reduces a spell's mana cost and recharge time greatly, at the costs of four health points | 5,6,10 | 150 |
| Blood To Power | BLOOD_TO_POWER | 20 |  |  |  |  |  | A projectile gains additional damage at the cost of 20% of your health | 2,5,6,10 | 150 |
| Gold To Power | MONEY_MAGIC | 30 |  |  |  |  |  | Spends 5% of your current gold and adds damage to a projectile proportional to the amount spent | 3,5,6,10 | 200 |
| Heplicate Spell | HEXA_SHOT | 130 | 20 |  |  |  |  | Casts 6 copies of a projectile in a hexagonal pattern, but the copies still cost mana | 3,4,5,6,10 | 280 |
| Inner Spell | CASTER_CAST | 10 |  |  |  |  |  | Causes a projectile to be cast from where the player is standing | 2,4,5,6,10 | 70 |
| Iplicate Spell | I_SHOT | 40 | 30 |  |  |  |  | Casts a copy of a projectile behind you, but the copy still cost mana | 1,2,3 | 130 |
| Long-Distance Cast | LONG_DISTANCE_CAST | 0 |  |  | -0.08 |  |  | Casts a spell some distance away from the caster | 0,1,2,4,5,6 | 90 |
| Peplicate Spell | PENTA_SHOT | 110 | 20 |  |  |  |  | Casts 5 copies of a projectile in a pentagonal pattern, but the copies still cost mana | 3,4,5,6,10 | 250 |
| Quplicate Spell | QUAD_SHOT | 90 | 20 |  |  |  |  | Casts copies of a projectile in a tetragonal pattern, but the copies still cost mana | 1,2,4 | 200 |
| Spells To Acid | ALL_ACID | 200 |  |  | +1.67 | +1.67 |  | Transforms every projectile currently in the air into a pool of acid *(Unlock: Open the Dark chest)* | 4,6,10 | 600 |
| Spells To Black Holes | ALL_BLACKHOLES | 200 | 10 |  | +1.67 | +1.67 |  | Transforms every projectile currently in the air into a black hole *(Unlock: Open the Dark chest)* | 3,6,10 | 500 |
| Spells To Death Crosses | ALL_DEATHCROSSES | 80 | 15 |  | +0.67 | +0.67 |  | Transforms every projectile currently in the air into a death cross *(Unlock: Open the Dark Chest)* | 2,6,10 | 350 |
| Spells To Giga Sawblades | ALL_DISCS | 100 |  |  | +0.83 | +0.83 |  | Transforms every projectile currently in the air into a giant sawblade *(Unlock: Open the Dark chest)* | 0,6,10 | 400 |
| Spells To Magic Missiles | ALL_ROCKETS | 100 | 10 |  | +0.83 | +0.83 |  | Transforms every projectile currently in the air into a magic missile *(Unlock: Open the Dark chest)* | 1,6,10 | 400 |
| Spells To Nukes | ALL_NUKES | 600 | 2 |  | +1.67 | +1.67 |  | Transforms every projectile currently in the air into a nuke, not a good idea *(Unlock: Open the Dark chest)* | 6,10 | 600 |
| Summon Platform | TEMPORARY_PLATFORM | 30 | 20 |  | +0.67 |  |  | Summons a shortlived bit of ground | 0,1,2,4,5 | 90 |
| Summon Taikasauva | SUMMON_WANDGHOST | 300 | 1 |  |  |  |  | Summons a possessed wand to aid you | 2,4,5,6,10 | 420 |
| Summon Wall | TEMPORARY_WALL | 40 | 20 |  | +0.67 |  |  | Summons a shortlived obstacle | 0,1,2,4,5 | 100 |
| Teleporting Cast | TELEPORT_CAST | 100 |  |  | +0.33 |  | spread +24 | Casts a spell from the closest enemy | 1,2,4,5,6 | 190 |
| Tiplicate Spell | T_SHOT | 60 | 25 |  |  |  |  | Casts copies of a projectile above and below you, but the copies still cost mana | 1,2,3 | 160 |
| Wand Refresh | RESET | 20 |  |  |  | -0.42 |  | Reloads the wand immediately *(Unlock: Defeat Mestarien mestari)* | 10 | 120 |
| Warp Cast | SUPER_TELEPORT_CAST | 20 |  | proj 0 | +0.17 |  | spread -6 | Makes a spell immediately jump a long distance, stopped by walls | 2,4,5,6 | 160 |
| Wuplicate Spell | W_SHOT | 70 | 20 |  |  |  |  | Casts copies of a projectile in a trifurcated pattern, but the copies still cost mana | 2,3,5,6 | 180 |
| Yplicate Spell | Y_SHOT | 40 | 30 |  |  |  |  | Casts a copy of a projectile in a bifurcated pattern, but the copy still cost mana | 1,2,3 | 135 |

## Passive (5)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Electric Torch | TORCH_ELECTRIC | 0 |  |  |  |  |  | Gives your wand a bright but very dangerous light! | 0,1,2 | 150 |
| Energy Shield | ENERGY_SHIELD | 10 |  |  |  |  |  | Deflects incoming projectiles | 1,2,3,4,5,6 | 220 |
| Energy Shield Sector | ENERGY_SHIELD_SECTOR | 10 |  |  |  |  |  | Deflects incoming projectiles | 0,1,2,3,4,5 | 160 |
| Summon Tiny Ghost | TINY_GHOST | 0 |  |  |  |  |  | Summons a tiny ethereal being to your help. It may cast stronger spells depending on how much damage you have suffered. | 1,2,3,4,5,6 | 160 |
| Torch | TORCH | 0 |  |  |  |  |  | Lights your wand right up! | 0,1,2 | 100 |

## Other (42)

| Spell | ID | Mana | Uses | Damage | Delay | Recharge | Mods | Description | Tier | Price |
|---|---|---|---|---|---|---|---|---|---|---|
| Add Expiration Trigger | ADD_DEATH_TRIGGER | 20 |  |  |  |  |  | Makes a projectile cast another spell upon expiring *(Unlock: Defeat Mestarien mestari)* | 3,4,5,10 | 150 |
| Add Timer | ADD_TIMER | 20 |  |  |  |  |  | Makes a projectile cast another spell after a short time *(Unlock: Defeat Mestarien mestari)* | 3,4,5,10 | 150 |
| Add Trigger | ADD_TRIGGER | 10 |  |  |  |  |  | Makes a projectile cast another spell upon collision *(Unlock: Defeat Mestarien mestari)* | 3,4,5,10 | 100 |
| Alpha | ALPHA | 40 |  |  | +0.25 |  |  | Casts a copy of the first spell in your wand *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 200 |
| Cessation | CESSATION | 0 | 25 |  | +10 | +10 |  | The caster enters the realm of no realm *(Unlock: Cast Touch of Grass at the sigil in the Barren Temple)* | 5,6,10 | 10 |
| Copy Random Spell | DRAW_RANDOM | 20 |  |  |  |  |  | Casts a random spell among the spells in your wand *(Unlock: Defeat Kolmisilmän koipi)* | 2,3,4,5,6,10 | 150 |
| Copy Random Spell Thrice | DRAW_RANDOM_X3 | 50 |  |  |  |  |  | Casts a random spell among the spells in your wand three times! *(Unlock: Defeat Kolmisilmän koipi)* | 3,4,5,6,10 | 250 |
| Copy Three Random Spells | DRAW_3_RANDOM | 40 |  |  |  |  |  | Casts three random spells among the spells in your wand *(Unlock: Defeat Kolmisilmän koipi)* | 2,3,5,6,10 | 200 |
| Divide By 10 | DIVIDE_10 | 200 | 5 | proj -37.5 | +1.33 | +0.33 |  | Casts the next spell 10 times, but with reduced damage *(Unlock: Avarice achievement)* | 10 | 400 |
| Divide By 2 | DIVIDE_2 | 35 |  | proj -5 | +0.33 |  |  | Casts the next spell 2 times, but with reduced damage *(Unlock: Open the Coral Chest)* | 3,5,6,10 | 200 |
| Divide By 3 | DIVIDE_3 | 50 |  | proj -10 | +0.58 |  |  | Casts the next spell 3 times, but with reduced damage *(Unlock: Open the Coral Chest)* | 4,5,6,10 | 250 |
| Divide By 4 | DIVIDE_4 | 70 |  | proj -15 | +0.83 |  |  | Casts the next spell 4 times, but with reduced damage *(Unlock: Open the Coral Chest)* | 5,6,10 | 300 |
| Gamma | GAMMA | 40 |  |  | +0.25 |  |  | Casts a copy of the last spell in your wand *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 200 |
| Kantele - Note A | KANTELE_A | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Kantele)* | 10 | 10 |
| Kantele - Note D | KANTELE_D | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Kantele)* | 10 | 10 |
| Kantele - Note D+ | KANTELE_DIS | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Kantele)* | 10 | 10 |
| Kantele - Note E | KANTELE_E | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Kantele)* | 10 | 10 |
| Kantele - Note G | KANTELE_G | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Kantele)* | 10 | 10 |
| Mu | MU | 120 |  |  | +0.83 |  |  | Every modifier-type spell in the current wand is applied to a projectile *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 500 |
| Ocarina - Note A | OCARINA_A | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note A2 | OCARINA_A2 | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note B | OCARINA_B | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note C | OCARINA_C | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note D | OCARINA_D | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note E | OCARINA_E | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note F | OCARINA_F | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Ocarina - Note G+ | OCARINA_GSHARP | 1 |  |  | +0.25 |  |  | Music for your ears! *(Unlock: Find the Huilu)* | 10 | 10 |
| Omega | OMEGA | 320 |  |  | +0.83 |  |  | Casts copies of every spell in your wand *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 600 |
| Phi | PHI | 120 |  |  | +0.83 |  |  | Casts a copy of every projectile-type spell in the current wand *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 500 |
| Random Spell | RANDOM_SPELL | 5 |  |  |  |  |  | Casts a spell, any spell, at random! *(Unlock: Defeat Kolmisilmän koipi)* | 3,4,5,6,10 | 100 |
| Requirement - Endpoint | IF_END | 0 |  |  |  |  |  | Any Requirement spells before this will skip all spells between them and this spell *(Unlock: Find the Experimental wand (math))* | 10 | 10 |
| Requirement - Enemies | IF_ENEMY | 0 |  |  |  |  |  | The next spell is skipped if there are less than 15 enemies nearby *(Unlock: Find the Experimental wand (math))* | 10 | 100 |
| Requirement - Every Other | IF_HALF | 0 |  |  |  |  |  | The next spell is skipped every other time this spell is cast *(Unlock: Find the Experimental wand (math))* | 10 | 100 |
| Requirement - Low Health | IF_HP | 0 |  |  |  |  |  | The next spell is skipped if you have more than 25% health left *(Unlock: Find the Experimental wand (math))* | 10 | 100 |
| Requirement - Otherwise | IF_ELSE | 0 |  |  |  |  |  | If a Requirement spell before this succeeds, the next spell is skipped *(Unlock: Find the Experimental wand (math))* | 10 | 10 |
| Requirement - Projectile Spells | IF_PROJECTILE | 0 |  |  |  |  |  | The next spell is skipped if there are less than 20 projectiles nearby *(Unlock: Find the Experimental wand (math))* | 10 | 100 |
| Sigma | SIGMA | 120 |  |  | +0.50 |  |  | Copies every static projectile -type spell in the wand when cast *(Unlock: Defeat Ylialkemisti)* | 4,5,10 | 500 |
| Spell Duplication | DUPLICATE | 250 |  |  | +0.33 | +0.33 |  | Duplicates every spell cast before it *(Unlock: Defeat Mestarien mestari)* | 5,6,10 | 250 |
| Summon Portal | SUMMON_PORTAL | 50 | 7 |  | +1.33 |  |  | Summons a strange portal | 10 | 100 |
| Tau | TAU | 90 |  |  | +0.58 |  |  | Copies the two following spells in the wand when cast *(Unlock: Defeat Ylialkemisti)* | 5,6,10 | 200 |
| The End Of Everything | ALL_SPELLS | 600 | 1 |  | +1.67 | +1.67 |  | You're heavily advised not to cast this spell. *(Unlock: Complete the The End of Everything Quest)* | 10 | 1000 |
| Zeta | ZETA | 10 |  |  |  |  |  | Copies a random spell in another wand you're holding *(Unlock: Defeat Ylialkemisti)* | 2,5,10 | 200 |
