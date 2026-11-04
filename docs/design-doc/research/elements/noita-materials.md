# Noita: Materials and Elements

The materials in Noita's falling-sand world, collected from the Noita wiki on 2026-11-03.

Source: https://noita.wiki.gg/wiki/Materials (material list, IDs, durability) and
https://noita.wiki.gg/wiki/Alchemy (fixed reactions). The wiki lists about 450 material IDs.
Many of them are the same material reused for different art or spawn rules (for example 16 IDs
called "Wood" and 15 called "Rock"). This doc merges those into one entry and names the most
common ID. The **Variants** column says what was merged.

Behaviour and status-effect notes that are not on the Materials page come from general game
knowledge. Check the material's own wiki page before relying on an exact number.

## How materials work (summary)

- Every pixel of the world is a material cell. Cells come in five kinds:
  - **Solid (static):** fixed terrain. It doesn't move until something destroys or converts it.
  - **Solid (physics/box2d):** rigid bodies that fall and tumble as a whole, such as loose
    rocks, crates, ice chunks and gems.
  - **Powder:** falls and piles up at a slope, like sand, snow or gunpowder.
  - **Liquid:** flows, pools and layers by **density**. Heavier liquids sink, so oil floats on
    water.
  - **Gas:** rises, has no collision and pools on cave ceilings.
  - Fire and sparks are short-lived "particle" materials.
- **Durability** decides which spells can dig a material. A projectile breaks a material only if
  its dig power meets the material's durability. **Hardness** is a second resistance that
  explosions use up as they pass through.
- **Burnable** materials catch fire and turn into other materials as they burn (wood becomes
  nothing, coal burns for a long time, oil burns fast).
- **Conductive** materials (metals, water) carry electricity from sparks and electric spells.
- **Stains:** liquids and gases coat creatures that touch them and apply a status effect while the
  stain lasts (Wet, Oiled, Bloody, Drunk, Toxic and so on). Some stains cancel others: being Wet
  puts out Burning.
- **Ingestion:** drinking a material from a flask applies its effect more strongly and for longer.
  Eating too much makes you overfull.
- **Reactions:** when two touching cells match a reaction rule, one or both convert. Examples are
  water and lava becoming rock, and fire and water becoming steam. Reactions happen in the open
  world, in flasks and in powder pouches. Two recipes (Lively Concoction and Alchemic Precursor)
  are randomised per world seed.
- **Phase changes:** heat melts metals, ice, wax and glass into their molten or liquid forms, and
  cold freezes liquids. Water becomes steam and steam rains back down.

## Durability table

| Durability | Example materials | Can be dug by (examples) |
|---|---|---|
| none | — | Bouncing Burst, Spitter Bolt (no digging) |
| 4 | Sand | |
| 5 | Cheese | |
| 8 | Coal, Concrete | Spark Bolt, Energy Sphere, Magic Arrow |
| 9 | Static meat | Spark Bolt With Double Trigger |
| 10 | Dense Rock, Soil, static Rusted Metal | Digging Bolt, Magic Missile, Fireball, Firebolt, Chainsaw, Death Cross |
| 11 | Rusted Steel | Dynamite, Giga Death Cross, Plasma Beam |
| 12 | Extremely Dense Rock, Steel | Nuke, Holy Bomb |
| 13 | Dense Steel | |
| 14 | Brickwork, Cursed Rock | Giga Nuke, Luminous Drill, Plasma Cutter |

## Counts (after merging variants)

| Group | Entries in this doc | Wiki IDs covered |
|---|---|---|
| Solids: terrain | 20 | ~110 |
| Solids: metals | 6 | ~30 |
| Solids: frozen | 2 | 15 |
| Solids: physics objects | 14 | ~60 |
| Solids: organic | 7 | ~35 |
| Liquids: standard | 25 | ~50 |
| Liquids: molten | 6 | 25 |
| Liquids: magical | 25 | ~30 |
| Gases | 13 | 26 |
| Powders | 25 | ~40 |
| Ground and soil | 9 | 22 |
| Plants | 6 | 25 |
| Fire and sparks | 4 | 20 |

## Solids: terrain

| Material | Main ID | Durability | Behaviour / effect | Variants merged |
|---|---|---|---|---|
| Rock | `rock_static` | ~10 | The default cave wall. Inert and doesn't burn. Forms when water meets lava | Grey Rock, Damp Rock, purple/intro/secret rocks, `waterrock`, loose and box2d rock |
| Dense Rock | `rock_hard` | 10 | Tougher wall that needs stronger digging. Forms from Freezing Liquid and lava | `rock_box2d_nohit_hard` |
| Extremely Dense Rock | `rock_hard_border` | 12 | Biome borders. Only nukes and drills get through | — |
| Brickwork | `templebrick_static` | 14 | Holy Mountain and temple walls. Very hard to dig | ~15 temple brick/slab IDs, Mossy, Diamond and Odd Brickwork, Brick Wall, Ruined Brick Wall |
| Fool's Gold | `templebrick_golden_static` | 14 | Gold-coloured brick. Decorative and gives no gold | — |
| Volcanic Rock | `lavarock_static` | ~10 | Forms from blood and lava. Found near lava | — |
| Frozen Rock | `snowrock_static` | ~10 | Snowy-depths wall | — |
| Toxic Rock | `rock_static_radioactive` | ~10 | Damages on contact (Toxic). Forms from Toxic Sludge and lava | — |
| Poisonous Rock | `rock_static_poison` | ~10 | Damages on contact. Forms from Poison and lava | — |
| Cursed Rock | `rock_static_cursed` | 14 | Hurts on touch. Extremely hard | Greed-Cursed Rock (`rock_static_cursed_green`) |
| Corrupted Rock | `corruption_static` | — | Late-game corrupted terrain | — |
| Eroding Rock | `rock_eroding` | — | Rock that crumbles away over time | — |
| Hell Rock | `skullrock` | — | Rock from hell/end areas | `the_end` |
| Vault Rock | `rock_vault` | — | Wall material of The Vault biome | — |
| Ground | `sand_static` | ~10 | Packed static dirt walls in the early biomes | Granite Ground, Lush Ground, Rusty Ground |
| Fungal Soil (static) | `rock_static_fungal` | — | Fungal Caverns walls | — |
| Concrete | `concrete_static` | 8 | Man-made wall. Forms when Cement sets. Low durability but resists some effects | Collapsed Concrete (falling chunks) |
| Glass | `glass_static` | — | Transparent. Acid can't dissolve it. Melts into Molten Glass | Brittle Glass, Tempered Glass, box2d glass |
| Glowing Stone | `glowstone` | — | Light-emitting rock | Glowing Matter (`rock_static_glow`, from Brine and lava), altar/potion variants |
| Magic Wall / Gate | `rock_magic_bottom` | — | Indestructible scripted barriers | `rock_magic_gate` |

## Solids: metals (conductive)

| Material | Main ID | Durability | Behaviour / effect | Variants merged |
|---|---|---|---|---|
| Steel | `steel_static` | 12 | Conducts electricity. Melts in lava. Concentrated Mana eats it into steam | `steel`, Mossy Steel, Smoking Steel, Metal Pipe, Frozen Steel |
| Dense Steel | `steel_static_strong` | 13 | Harder steel. The "Hardened Steel" version doesn't melt | `steel_grey_static`, `steel_static_unmeltable` |
| Rusted Steel | `steel_rust` | 11 | Weaker, rusted steel | `steel_rusted_no_holes`, `steelmoss_static` |
| Metal | `metal` | ~10 | Generic metal props (chains, wires, barrels). Conductive, melts | `metal_hard`, `metal_prop*`, Rusted Metal |
| Aluminium | `aluminium` | — | Robot and prop metal. Melts | `aluminium_robot`, `aluminium_oxide` |
| Gold (solid) | `gold_static` | — | Gold vein. Mining it drops Gold powder, which gives money when picked up | Vibrant Gold Vein, Toxic Gold vein, gold box2d nuggets, Ruby |

## Solids: frozen

| Material | Main ID | Behaviour / effect | Variants merged |
|---|---|---|---|
| Ice | `ice_static` | Frozen water. Melts back to water near heat or fire. Forms from Water and Freezing Liquid | `ice_glass`, cold ice, meteor ice, ceiling ice, box2d ice, Packed Snow |
| Frozen [liquid] | `ice_acid_static` and others | A frozen liquid that keeps its liquid's danger and melts back into it. Kinds: Acid, Blood, Poison, Slime, Toxic (Toxic Ice) | `_static` and `_glass` versions of each |

## Solids: physics objects (box2d / free solids)

| Material | Main ID | Behaviour / effect | Variants merged |
|---|---|---|---|
| Wood | `wood_static` | Burns readily and leaves nothing. Main fuel in early biomes | ~16 IDs: wall, tree, prop, loose, player-built, vertical, Tough Wood, Damp Wood (wet, harder to light), Pressurized Wood (releases gas), Wood That Burns Forever |
| TNT | `tnt` | Explodes when ignited or hit | `tnt_static`, `fuse_tnt` |
| Bomb fuse | `fuse` | Explosive object material | `fuse_bright`, Holy Matter (`fuse_holy`) |
| Crystal | `crystal` | Hard decorative crystal | Purple Crystal, Magical Crystal (green/blue) |
| Gem | `gem_box2d` | Gemstones dropped as items | Pink, green, red, orange, Turquoise Gemstone, Sun gems |
| Meteorite | `meteorite` | Heavy falling rock | crackable, green, static |
| Bone | `bone_box2d` | Skeleton chunks | Bone Wall (`bone_static`) |
| Plastic | `plastic` | Melts into Molten Plastic | `plastic_prop` |
| Wax | `wax_b2` | Candles. Melts into Molten Wax and burns | — |
| Cloth | `cloth_box2d` | Banners and flags. Burnable | — |
| Neon Tube | `tube_physics` | Light-emitting tubes. Glass-like | colour variants, `tubematerial` |
| Cactus | `cactus` | Desert plant body | — |
| Nest / Cocoon | `nest_box2d` | Creature nests that spawn enemies | firebug nest, Cocoon, static nest |
| Snow chunk | `snow_b2` | Falling snow clumps | — |

## Solids: organic

| Material | Main ID | Behaviour / effect | Variants merged |
|---|---|---|---|
| Meat | `meat` | Creature bodies. Cooks under fire through Lightly-Cooked, Cooked, Fully-Cooked and Burned Meat. Edible | ~24 IDs. Special meats give status effects when eaten: Frog (an ingredient for Berserkium), Worm, Fruit Flesh, Ethereal (teleports), Unstable (polymorphs), Stinky (polymorph protection), Wobbly (fast), Weird (trippy), Ambiguous (confusion), Cursed, Meat of an Innocent Creature (karma penalty) |
| Slimy Meat | `meat_slime` | Slime-creature meat. Slimy stain | orange, green, cursed versions |
| Cheese | `cheese_static` | Durability 5. Edible | — |
| Slime (solid) | `slime_static` | Static slime walls | — |
| Hell Slime | `endslime` | End-area slime solid | `endslime_static` |
| Vine | `vine` | Hanging vines and roots. Burnable | `root`, `root_growth` |
| Blue Fungus | `bluefungi_static` | Fungal growth walls | `spore_pod_stalk` |

## Liquids: standard

| Material | Main ID | Stain / effect | Notes and reactions | Variants merged |
|---|---|---|---|---|
| Water | `water` | Wet: puts out Burning, blocks fire for a while, conducts electricity | Fire turns it to Steam. Lava turns it to Rock. Freezing Liquid turns it to Ice. Concentrated Mana converts it into more mana. Purifying Powder turns impure liquids into water | `water_static`, `water_fading`, `water_temp` |
| Chilly Water | `water_ice` | Wet | Near-freezing water in the snow biomes | — |
| Brine | `water_salt` | Wet | Salt water. Brine and lava make Glowing Matter | — |
| Swamp | `swamp` | Wet | Murky swamp water | `water_swamp` |
| Slush | `slush` | Wet | Half-frozen water | — |
| Oil | `oil` | Oiled: fire damage taken goes up, and Burning lasts | Very flammable and burns fast. Lighter than water, so it floats on top | — |
| Acid | `acid` | Damages creatures | Dissolves most terrain and creatures. Can't dissolve glass, so it is carried in glass flasks | Frozen Acid |
| Lava | `lava` | Sets on fire, heavy damage | Heavy. Melts metals and ice. Makes Rock with water, Volcanic Rock with blood, Ground with mud, Toxic Rock with sludge, Poisonous Rock with poison, Dense Rock with Freezing Liquid. Absorbs steel | — |
| Toxic Sludge | `radioactive_liquid` | Toxic: damage over time | Glowing green. Purifying Powder neutralises it into water. Lava makes Toxic Rock | fading and yellow versions |
| Poison | `poison` | Poisoned: damage over time | Lava makes Poisonous Rock | Frozen Poison |
| Blood | `blood` | Bloody stain. Heals with vampire perks | Lava makes Volcanic Rock. An ingredient for Diamond, Unstable Polymorphine and Purifying Powder | thick, fading versions |
| Worm Blood | `blood_worm` | Bloody | Used to make Purifying Powder | — |
| Fungus Blood | `blood_fungi` | Bloody | Fungus-creature blood | — |
| Freezing Liquid | `blood_cold` | Freezing stain, damages | Freezes water into Ice. Lava makes Dense Rock. Evaporates into Freezing Vapour | — |
| Slime | `slime` | Slimy: slows movement | With Acceleratium, Levitatium or Hastium it turns into live gunpowder. An ingredient for Teleportatium | green, yellow |
| Mud | `mud` | Muddy | Lava makes Ground | — |
| Cement | `cement` | Sticks | Sets into Concrete | — |
| Whiskey | `alcohol` | Drunk: shaky aim, blurry screen | Flammable. With Frog Meat it makes Berserkium. Gives off Whiskey Fumes | — |
| Beer / Sima / Juhannussima | `beer` | Drunk | Finnish drinks. Mostly flavour | `sima`, `juhannussima` |
| Liquid Fire | `liquid_fire` | Burning | Flowing fire | `liquid_fire_weak` |
| Vomit | `vomit` | Gross stain | Vomit and Bone make Diminution | — |
| Urine | `urine` | Stain | Flavour liquid | — |
| Food liquids | `porridge` | Edible | Hearty Porridge, Pea Soup, Milk, Honey | `pea_soup`, `milk` |
| Void Liquid | `void_liquid` | — | Rare, very dark liquid from the end areas | — |
| Creepy Liquid | `creepy_liquid` | — | Comes from hidden emitters. Flavour or secret liquid | — |

## Liquids: molten

Heat melts each solid into its molten form, and the molten form cools back into the solid.

| Material | Main ID | From | Variants merged |
|---|---|---|---|
| Molten Metal | `metal_molten` | Metal, Rusted Metal, Metal Dust | ~6 IDs |
| Molten Steel | `steel_static_molten` | Steel, Rusted, Mossy and Smoking Steel | ~5 IDs |
| Molten Glass | `glass_molten` | Glass, broken glass | `glass_broken_molten` |
| Molten Gold / Silver / Copper / Brass | `gold_molten` | Those metal powders | `silver_molten`, `copper_molten`, `brass_molten` |
| Molten Aluminium | `aluminium_molten` | Aluminium | robot, oxide versions |
| Molten Plastic / Wax | `plastic_molten` | Plastic, Wax | `plastic_red/grey/prop_molten`, `wax_molten` |

## Liquids: magical

Most are found in flasks on pedestals or are made by alchemy. The effect applies as a stain, and
more strongly when drunk.

| Material | Main ID | Effect | How it's made |
|---|---|---|---|
| Acceleratium | `magic_liquid_movement_faster` | Faster movement | Found |
| Levitatium | `magic_liquid_faster_levitation` | Faster levitation | Found |
| Hastium | `magic_liquid_faster_levitation_and_movement` | Faster movement and levitation | Acceleratium + Levitatium |
| Ambrosia | `magic_liquid_protection_all` | Protection from all damage while stained | Diamond + Honey (also makes Poison) |
| Berserkium | `magic_liquid_berserk` | Berserk: more damage dealt | Whiskey + Frog Meat |
| Concentrated Mana | `magic_liquid_mana_regeneration` | Much faster wand mana regeneration | Found. Turns water into more mana and eats steel |
| Healthium | `magic_liquid_hp_regeneration` | Heals over time | Found |
| Lively Concoction | `magic_liquid_hp_regeneration_unstable` | Strong healing | Random 3-ingredient recipe per seed |
| Invisiblium | `magic_liquid_invisibility` | Invisible to enemies | Found |
| Teleportatium | `magic_liquid_teleportation` | Random short teleports | Unstable Teleportatium + Slime |
| Unstable Teleportatium | `magic_liquid_unstable_teleportation` | Erratic teleports | Found. With fire it becomes Freezing Vapour; with mana it becomes Fire |
| Polymorphine | `magic_liquid_polymorph` | Polymorph into a random creature (usually a sheep) | Found |
| Chaotic Polymorphine | `magic_liquid_random_polymorph` | Polymorph into any creature | Found. Turns gold or diamond into Silver |
| Unstable Polymorphine | `magic_liquid_unstable_polymorph` | Polymorphs on and off | Blood + Oil + Flummoxium |
| Flummoxium | `material_confusion` | Confused: controls reversed | Found |
| Diminution | `magic_liquid_weakness` | Weakened: less damage dealt | Vomit + Bone |
| Pheromone | `magic_liquid_charm` | Charmed: enemies become allies | Berserkium + Flummoxium |
| Worm Pheromone | `magic_liquid_worm_attractor` | Attracts worms | Found |
| Ominous Liquid | `material_darkness` | Darkness | Found |
| Rainbow | `material_rainbow` | Cosmetic colour | Found |
| Gate-Opener | `magic_liquid` | Story / puzzle liquid | Found |
| Alchemic Precursor / Draught of Midas | `midas_precursor` / `midas` | Midas turns what it touches into gold | Precursor is a random recipe per seed. Precursor + Meat = Midas; Precursor + Lava = Gas of Midas |
| Instant Deathium | `just_death` | Kills | Secret |
| Mimicium | `mimic_liquid` | Secret magical liquid | Secret |
| Pus | `pus` | Stain | Found |

## Gases

| Material | Main ID | Effect / behaviour | Variants merged |
|---|---|---|---|
| Smoke | `smoke` | Harmless. Comes from fires and explosions. Blocks vision | static, magic, explosion, rocket-trail smoke |
| Steam | `steam` | Harmless. Comes from water and fire. Condenses and rains back as water | `steam_trailer` |
| Cloud | `cloud` | Rains water | `cloud_lighter`. Mists: Blood Mist, Slime Mist, Toxic Mist (liquid clouds that rain their liquid) |
| Flammable Gas | `acid_gas` | Explodes in a flash when ignited | `acid_gas_static` (gas pockets). Pressurized Wood releases it |
| Toxic Gas | `radioactive_gas` | Toxic: damage over time | `radioactive_gas_static` |
| Poison Gas | `poison_gas` | Poisoned | — |
| Freezing Vapour | `blood_cold_vapour` | Freezing stain, damages | From Freezing Liquid, and Teleportatium + fire |
| Nauseating Gas | `poo_gas` | Damages, from excrement | — |
| Whiskey Fumes | `alcohol_gas` | Drunk | — |
| Fungal Gas | `fungal_gas` | Trippy / fungal effect | Funky Cloud, Funky Vapour |
| Healium | `magic_gas_hp_regeneration` | Heals over time | — |
| Magic gases | `magic_gas_polymorph` and others | Same effect as the matching liquid: Polymorphine, Teleportatium and Diminution clouds, Gas of Midas, Worm Gas | — |
| Unicorn Farts | `rainbow_gas` | Cosmetic rainbow gas | — |

## Powders

| Material | Main ID | Effect / behaviour | Variants merged |
|---|---|---|---|
| Sand | `sand` | Basic powder. Durability 4, falls and piles | `sand_surface`, `sand_petrify`, Blue Sand, Volcanic Sand, Sandstone (static) |
| Snow | `snow` | Light powder in the cold biomes. Melts into water | `snow_sticky` |
| Coal | `coal` | Burns slowly for a long time | Coal Vein (static) |
| Gunpowder | `gunpowder` | Explodes when ignited. Chain explosions | TNT, unstable, explosive versions. Slime + speed potions makes it |
| Sulphur | `sulphur` | Flammable powder | `sulphur_box2d` |
| Burning Powder | `burning_powder` | Burns as it falls | — |
| Shock Powder | `shock_powder` | Electric. Shocks what it touches | Fire + Brass |
| Sodium | `sodium` | Reacts explosively with water | Wet Sodium (`sodium_unstable`) |
| Salt | `salt` | Inert powder | — |
| Gold (powder) | `gold` | Gives money when picked up | Toxic Gold (damaging) |
| Silver | `silver` | Alchemy ingredient | Copper + Brass + Water. Chaotic Polymorphine + Gold or Diamond |
| Copper | `copper` | Alchemy ingredient | — |
| Brass | `brass` | Alchemy ingredient. With fire it makes Shock Powder | — |
| Diamond | `diamond` | Alchemy ingredient (Ambrosia, Purifying Powder) | Silver + Copper + Blood |
| Purifying Powder | `purifying_powder` | Turns impure liquids into Water. Used up very slowly | Brass + Diamond. Diamond + Silver + Worm Blood |
| Metal Dust | `metal_sand` | Metallic powder. Melts | Steel powder (`steel_sand`) |
| Broken Glass | `glass_broken` | Glass shards | — |
| Concrete powder | `concrete_sand` | Loose concrete | — |
| Glue | `glue` | Sticky powder that binds | — |
| Honey | `honey` | Edible. With Diamond it makes Ambrosia | — |
| Excrement | `poo` | Gives off Nauseating Gas | `poop_box2d_hard` |
| Wax / Plastic powder | `wax` | Meltable powder | `plastic_grey`, `plastic_red` |
| Bone Dust | `bone` | Bone powder. With Vomit it makes Diminution | — |
| Fungal Soil (powder) | `fungus_powder` | Fungal growth powder | `fungus_powder_bad`, `fungisoil` |
| Special powders | `orb_powder` | Guiding Powder, Ratty Powder, Monstrous Powder, Mämmi (food) | `rat_powder`, `monster_powder_test`, `mammi` |

## Ground and soil

| Material | Main ID | Effect / behaviour | Variants merged |
|---|---|---|---|
| Soil | `soil` | Diggable dirt (durability 10). Plants grow on it | `soil_lush`, `soil_lush_dark` |
| Barren Soil | `soil_dead` | Soil that plants don't grow on | `soil_dark` |
| Dirt | `explosion_dirt` | Loose dirt thrown by explosions | — |
| Surface | `sandstone_surface` | Surface-biome topsoil | Sandstone |
| Mud (solid ground) | `mud` | Wet ground | — |
| Ice (powder) | `ice` | Loose ice chunks | `grass_ice` |
| Rotten Meat | `rotten_meat` | Decayed meat ground. Edible | Toxic Meat (`rotten_meat_radioactive`), slimy sand meat |
| Snow / Packed Snow | `snow` | See Powders | `snow_static` |
| Volcanic Sand | `lavasand` | See Sand | — |

## Plants

| Material | Main ID | Effect / behaviour | Variants merged |
|---|---|---|---|
| Grass | `grass` | Surface plant layer. Burns fast | dry, dark, darker, Divine Ground (`grass_holy`) |
| Moss | `moss` | Grows on walls. Burnable | Rusty Moss |
| Plant Material | `plant_material` | Plant body that seeds grow into. Burnable | dark, red |
| Seed | `plant_seed` | Grows into plants or bushes when it lands | Evergreen Seed, ceiling seed, spore |
| Fungus | `fungi` | Weird Fungus, which gives a trippy effect when eaten | yellow, green, Mystery Fungus (creeping), Fungal Matter |
| Fungal Spore | `mushroom` | Grows into mushrooms | giant red/blue, Glowing Fungal Spore |

## Fire and sparks

| Material | Main ID | Effect / behaviour | Variants merged |
|---|---|---|---|
| Fire | `fire` | Burning: damage over time, and it spreads to burnable materials. Water puts it out | `flame`, Blue Fire (`fire_blue`) |
| Liquid Fire | `liquid_fire` | Fire that flows like a liquid | `liquid_fire_weak` |
| Spark | `spark` | Short-lived glowing particle from spells. Some ignite things | ~13 colour versions |
| Electric Spark | `spark_electric` | Electricity. Travels through conductive metals and water | — |

## Status effects from materials (quick reference)

| Status | Caused by | Effect |
|---|---|---|
| Wet | Water and its variants | Puts out and prevents Burning. Conducts electricity |
| Oiled | Oil | Burning lasts longer and hurts more |
| Burning | Fire, lava, liquid fire | Damage over time. Spreads to burnables |
| Bloody | Blood | Cosmetic, or healing with vampire perks |
| Slimy | Slime | Slower movement |
| Drunk | Whiskey, beer, fumes | Shaky aim, distorted view |
| Toxic | Toxic Sludge and Toxic Gas | Damage over time |
| Poisoned | Poison and Poison Gas | Damage over time |
| Frozen / Freezing | Freezing Liquid and Freezing Vapour | Damage. Freezes water |
| Electrified | Electric spark, Shock Powder | Shock damage, travels through conductors |
| Magic statuses | Magical liquids and gases | See Liquids: magical |

## Fixed reactions

Two-material reactions from the Alchemy page. "Random" recipes (Lively Concoction, Alchemic
Precursor) change per seed.

| Inputs | Result | Kind |
|---|---|---|
| Water + Fire | Steam | Physical |
| Water + Lava | Rock | Physical |
| Water + Freezing Liquid | Ice | Physical |
| Lava + Freezing Liquid | Dense Rock | Physical |
| Lava + Blood | Volcanic Rock | Physical |
| Lava + Mud | Ground | Physical |
| Lava + Toxic Sludge | Toxic Rock | Physical |
| Lava + Poison | Poisonous Rock | Physical |
| Lava + Brine | Glowing Matter | Physical |
| Lava + Steel | Lava (steel absorbed) | Physical |
| Fire + Brass | Shock Powder | Physical |
| Concentrated Mana + Water | Concentrated Mana | Duplication |
| Concentrated Mana + Steel | Concentrated Mana + Steam | Corrosion |
| Diamond + Honey | Ambrosia + Poison | Alchemy |
| Whiskey + Frog Meat | Berserkium | Alchemy |
| Vomit + Bone | Diminution | Alchemy |
| Acceleratium + Levitatium | Hastium | Alchemy |
| Slime + Acceleratium / Levitatium / Hastium | Live gunpowder (explodes) | Alchemy |
| Berserkium + Flummoxium | Pheromone | Alchemy |
| Silver + Copper + Blood | Diamond | Alchemy |
| Copper + Brass + Water | Silver | Alchemy |
| Gold or Diamond + Chaotic Polymorphine | Silver | Alchemy |
| Brass + Diamond | Purifying Powder | Alchemy |
| Diamond + Silver + Worm Blood | Purifying Powder + Smoke | Alchemy |
| Impure liquid + Purifying Powder | Water | Purification |
| Unstable Teleportatium + Slime | Teleportatium | Alchemy |
| (Unstable) Teleportatium + Fire | Freezing Vapour | Alchemy |
| (Unstable) Teleportatium + Concentrated Mana | Fire | Alchemy |
| Blood + Oil + Flummoxium | Unstable Polymorphine (converts the blood only) | Alchemy |
| Alchemic Precursor + Meat | Draught of Midas | Alchemy |
| Alchemic Precursor + Draught of Midas | Draught of Midas | Duplication |
| Alchemic Precursor + Lava | Gas of Midas | Alchemy |

Notes: liquid-to-liquid conversions spread gradually, and some only work from the top down.
Purifying Powder is used up very slowly, so a little treats a lot of liquid.

## Mapping to roguelike-star's named materials

The materials named in `core-mechanics.md` §7 and their closest Noita entries:

| Ours | Noita entry |
|---|---|
| sand | Sand |
| wood | Wood |
| water | Water |
| oil | Oil |
| rock | Rock |
| lava | Lava |
| fire | Fire |
| smoke | Smoke |
| steam | Steam |
| frost | Freezing Liquid / Freezing Vapour (no "frost" material exists) |
| ice | Ice |
| concrete | Concrete (+ Cement) |
| acid | Acid |
| gas | Flammable Gas |
| acid gas | Noita's internal ID for Flammable Gas is `acid_gas`. Its Toxic Gas is the closer match for a harmful gas |
| coal | Coal |
| dirt | Soil / Dirt |
| obsidian | No direct match. Closest are Dense Rock (lava + freezing) and Volcanic Rock |
| steel | Steel |
