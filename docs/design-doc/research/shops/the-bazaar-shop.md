# The Bazaar: Shop and Merchant Mechanics

How shopping works in The Bazaar: run structure, merchants, prices, rerolls, selling and upgrades. Collected on 2026-11-04.

Sources:
- https://thebazaar.wiki.gg (merchant infoboxes, Day, Enchantment, Pearl's Dig Site, patch notes 0.1.3 and 0.1.4)
- Prices are tallied from the wiki's item table (see [../parts/the-bazaar-items.md](../parts/the-bazaar-items.md))
- Beginner guides: gaming.news (May 2025), bazaar-builds.net, thegamer.com (Aug 2025)

The Bazaar is patched often, and guides disagree on some numbers (starting gold, reroll cost per tier). Those are flagged below. Treat numbers as a snapshot.

## Run structure

- A run is a series of **Days**. Each Day has 6 **Hours**.
- In most Hours you pick one of three encounters: usually a **merchant**, an **event**, and a **free bonus**.
- One Hour per Day is a **PvE monster fight**. You choose an easy, medium or hard monster. It gives gold, XP and loot.
- The last Hour is a **PvP fight** against a snapshot ("ghost") of another player's build.
- You start with 20 **Prestige**. Losing a PvP fight costs Prestige equal to the day number. The run ends at 0 Prestige. Losing to a monster costs no Prestige, but you get no reward.
- So shopping is one of three encounter choices in each Hour, not a fixed screen between fights. Picking a merchant means not taking the event or free bonus that Hour.

## Economy

| Thing | Value |
|---|---|
| Starting gold / Income | 8 gold, 5 Income (one guide says 15 gold, 7 Income, probably counting the economy start bonus) |
| Start-of-run choice | Economy (+12 gold, +2 Income), an enchanted Bronze small item + 6 gold, or a skill |
| Daily income | At the end of each Day you get gold equal to your **Income** stat |
| Other gold | Monster rewards, events, and economy items (Pygmalien's Property/Value items, Golden enchantment) |

Income is a stat that items and skills can raise, so investing in economy early pays out every day after that.

## Item prices

Price = **2 gold × size (1/2/3 slots) × 2 per tier above Bronze**. Legendary items cost a flat 100.

| Size | Bronze | Silver | Gold | Diamond | Legendary |
|---|---|---|---|---|---|
| Small (1 slot) | 2 | 4 | 8 | 16 | 100 |
| Medium (2 slots) | 4 | 8 | 16 | 32 | 100 |
| Large (3 slots) | 6 | 12 | 24 | 48 | 100 |

- An item's starting tier is fixed per item. A Silver-start Small item costs 4/8/16 for Silver/Gold/Diamond.
- A few items don't follow the formula (for example some small Bronze items at 2/4/6/8).
- Each item has a **Value**, normally half its price (Jewelry: cost 2/4/8/16, value 1/2/4/8). Some items gain Value over the run, and Value can be part of their effect.

## Selling

- You can sell items **any time**, not only at a merchant.
- Selling gives the item's Value (about 50% of price).
- Some merchants pay more for certain items:

| Merchant | Buys |
|---|---|
| Barkun | Your Small items at +1 Value |
| Midsworth | Your Medium items at +2 Value |
| Quixel | Your Large items at +3 Value |
| Valpak | Your Bronze items at +1 gold |

- Some skills and items trigger on selling (e.g. *Arms Dealer*: when you sell a Weapon, gain Max Health). So selling can be a build choice, not only a way to get gold.

## Upgrading

- Every item has a tier: Bronze → Silver → Gold → Diamond (→ Legendary for a few items).
- **Two copies of the same item at the same tier merge into one item a tier higher.** Buying a duplicate at a merchant is the main way to upgrade.
- Merchants that sell higher tiers (Silvia, Goldie, Luxe) let you skip tiers, but they cost more.
- Level-ups, events and some merchants also offer upgrades.
- Skills upgrade by duplicates too. Grandmaster always offers two upgrades for skills you already own.

## Board and stash

- 10 board slots. Small items take 1, Medium 2, Large 3.
- Extra items go to the **stash**. Stashed items don't act in combat. A few effects still work from the stash.
- You can buy now and arrange later. The stash lets you hold an item until you find its duplicate or the item it combos with.

## Merchants

Each merchant has a **theme** (a tag, size or tier filter), a **starting tier**, and a **day range** when it can appear. Only items for your hero (and neutral items) show up.

### Rerolls

- Since patch 0.1.4 every merchant can be rerolled. The cost depends on the merchant's tier: **2 / 4 / 6 / 8 gold** for Bronze / Silver / Gold / Diamond. (A later source lists Bronze 2, Silver 4, Gold 6, with some exceptions such as Gaseo at 4.)
- The cost is flat per reroll. It doesn't go up within a visit. Rerolls are often limited, and some specialised merchants had rerolls removed in 0.1.3, so this may change again.
- Some items lower reroll costs (Stelle's Cloche Hat: −1 gold per reroll for each one you own).
- Events can use other rules. **Pearl's Dig Site** has unlimited rerolls starting at 1 gold, +1 gold each. You get one item free.
- **Curio** sells only Bronze unenchanted items and shows up to 10 items per reroll.

### Item merchants

| Merchant | Sells | Start tier | Days |
|---|---|---|---|
| JayJay | Anything | Bronze | 1+ |
| Ande | Small items | Bronze | 1+ |
| Mittel | Medium items | Bronze | 2+ |
| Pol | Large items | Bronze | 5+ |
| Aila | Weapons | Bronze | 1+ |
| Kina | Non-weapons | Bronze | 1+ |
| Barkun | Medium and Large; buys Small at +1 | Silver | 1+ |
| Midsworth | Small and Large; buys Medium at +2 | Silver | 1+ |
| Quixel | Small and Medium; buys Large at +3 | Silver | 2+ |
| Valpak | Anything; buys Bronze at +1 gold | Silver | ? |
| Curio | Bronze unenchanted / Junk items, up to 10 shown | Silver | 1+ |
| Silvia | Silver-tier items | Silver | 1+ (not Day 1 since 0.1.4) |
| Goldie | Gold-tier items | Gold | 5+ |
| Luxe | Diamond-tier items | Diamond | 8+ |
| Colt | Ammo items | Silver | 1+ |
| Eli | Potions (Mak) | Silver | 1+ |
| Orion | Tools | Silver | 4+ |
| Herma | Heal and Regen | Silver | 6+ |
| Kev's Armory | Health and Shield | Silver | 6+ |
| Nautica | Aquatic (Vanessa) | Silver | 6+ |
| Prospero | Economy (Pygmalien) | Silver | 6+ |
| Tinker | Friends (Dooley) | Silver | 6+ |
| Tok's Clocks | Haste, Slow, Cooldown | Silver | 6+ |
| Aero | Vehicles (Stelle) | Gold | 6+ |
| Gaseo | Apparel from any hero | Gold | ? |
| Tatiana | Toys from any hero | Gold | ? |
| Mr. Morland | Property (Pygmalien) | Gold | 6+ |
| Chronos | Haste | Diamond | 6+ |
| Cobweb | Slow | Diamond | 6+ |
| Hef | Burn | Diamond | 6+ |
| Knightshade | Poison | Diamond | 6+ |
| Flex | Max Health (Pygmalien) | Diamond | 6+ |
| Serafina | Enchanted items; multiple buys allowed | Diamond | 6+ |
| Freiya | Freeze | Legendary | 6+ |

### Skill merchants

Since 0.1.4, most skills come from level-ups. Most skill trainers were taken out of the normal encounter pool and now give a free skill when they do appear. Only three still show up as normal encounters:

| Merchant | Sells | Notes |
|---|---|---|
| Nufu | Skills (Silver) | Day 1+ |
| Grandmaster | Upgrades for skills you own | 2 choices, no reroll. Gives gold if you have no skills |
| Zurphin's Safari | Monster skills (Diamond) | |

Other trainers (appear on level-up): Pip (Bronze skills), Argenta (Silver), Orlin (Gold), Adira (Diamond); themed ones such as Ryukon (Weapon), Fortis (Shield), Malafang (Burn), Professor Riggle (Poison), Vermir (Crit), Zara (Haste/Charge), Bjorn (Freeze), C4 (Ammo), Slohmor Lumbra (Slow), Regenald (Heal/Regen); and hero-only ones: Cymon (Dooley), Old Zane (Vanessa), Mr. Tuskari (Pygmalien), Zosima (Mak).

- Trainers show 3 skills.
- When a skill isn't free it costs 5 / 10 / 20 / 40 gold by tier.

## Enchantments

- One enchantment per item. A new one replaces the old one.
- An enchantment adds or boosts one effect: Heavy (Slow), Icy (Freeze), Turbo (Haste), Shielded, Restorative (Heal), Toxic (Poison), Fiery (Burn), Shiny (Multicast), Deadly (Crit), Obsidian (Damage), Golden (Value), Radiant (can't be Frozen, Slowed or Destroyed).
- Ways to get them: start of run, Serafina and other merchants (more often on later days), level-ups, themed events (e.g. Burning Caldera → Fiery, Frozen Tomb → Icy), monster drops.

## Free-item events that work like shops

- **Pearl's Dig Site**: a merchant-style screen with any-hero and monster items. One item is free and rerolls cost more each time.
- **Monster Ranch**: one free Gold-tier Monster Loot item from 5 choices.
- **Haddy**: spin a wheel for a prize.
- The third choice each Hour is often a small free bonus. Guides note that you can get many items free by picking these well.

## Key design points

- **Shops are an encounter you choose.** A merchant competes with an event and a free bonus each Hour, so visiting a shop has a cost.
- **Merchants are themed.** Each one has a narrow filter (tag, size or tier). Players pick the merchant that fits their build, which makes the merchant choice part of drafting.
- **Day gating sets the pace.** Bronze merchants come early, Diamond and Legendary merchants come on Day 6–8+. This controls power growth without hard level caps.
- **One price formula.** Price = size × tier, and sell value is half. Players can learn it once and work out any price.
- **Duplicates are upgrades.** Buying a copy you already own is the main upgrade path, so you want to see the same item again. This works well with themed merchants and rerolls.
- **Flat reroll cost per merchant tier**, unlike Balatro's cost that goes up within a shop.
- **Selling works anywhere, and some merchants pay more** for certain sizes or tiers. That makes selling a part of planning, not only clean-up.
- **Income is a stat that pays out each day**, unlike Balatro's interest on saved money.
