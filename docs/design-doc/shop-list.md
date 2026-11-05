# RoguelikeStar: shop list

Everything a shop phase stage can offer: 15 theme options, 20 rule options with their own rules,
and 10 resource options. Relics and bodies are separate lists. This doc only says how their
options sell them.

Each rule option and resource option is one SCAMPER move (Substitute, Combine, Adapt, Modify, Put
to another use, Eliminate, Reverse) on something from the shop research.

Related docs: [core-mechanics.md](core-mechanics.md) §6 (shop phase rules),
[parts-list.md](parts-list.md) (what the shops stock), research in
[research/shops/](research/shops/README.md).

Markers follow `core-mechanics.md`: **Decided** was agreed in discussion, **Proposed** is a
starting point, **Open** is unsettled. All numbers are Proposed.

## 1. Rules for every option

- A rule option can change the standard numbers: how many items it shows, how many you pick,
  rerolls and their cost, entry cost.
- Options can have real downsides. HP only resets after a battle, so HP lost in the shop carries
  into the next battle.
- Selling works the same in every option. No option changes where or whether you can sell. An
  option or a relic may change sell value.
- Parts are always offered in their base state. No cursed parts, and no stickers or markers on a
  part.
- A relic sits outside the chariot, takes no slot, and changes a rule for the rest of the run.
- Some options are gated: they only appear after an elite or from a certain battle onward.

### 1.1 The standard frame

- **Shop:** 3 items at their normal price (2 / 6 / 12 gold). One reroll for 2 gold (flat, as in
  The Bazaar). A reroll replaces every item you haven't bought.
- **Pack:** 4 gold to enter. Shows 3 items and you take 1 free. You may leave without taking one.
  No reroll.
- A theme option rolls as a shop 60% of the time and as a pack 40%.

### 1.2 Acts and gates

The run has three acts, split by the elites (`core-mechanics.md` §2).

| Act | Shop phases after battle | Unlocks |
|---|---|---|
| 1 | 1, 2 | Options marked Act 1 |
| 2 | 3 (first elite), 4, 5 | + Act 2 options |
| 3 | 6 (second elite), 7, 8, 9 (third elite) | + Act 3 options |

- An option unlocked in an earlier act stays in the pool for the rest of the run.
- Some options carry an event gate on top of their act (for example, "right after an elite").
- Options that pay off in the next shop phase (O07, O08, O14, RS05) can't appear in the shop
  phase after battle 9, because the boss comes next and nothing follows it.

### 1.3 Rarity odds

For any option that rolls part rarity:

| Act | Common | Uncommon | Rare |
|---|---|---|---|
| 1 | 70% | 27% | 3% |
| 2 | 50% | 40% | 10% |
| 3 | 35% | 45% | 20% |

- Packs move 5 points from Common to Rare (Act 1: 65 / 27 / 8).
- An option that says "no commons" splits the Common share evenly across the other two.

### 1.4 Drawing options 1 and 2

**Decided** (`core-mechanics.md` §6.1)
- Options 1 and 2 are never resource options, never the same as each other, and never repeat an
  option from the previous stage.

**Proposed**
- The shop and pack forms of one theme count as the same option for the no-repeat rule.
- Weights: each theme option 4, Chariot body and Relics 2 each, each rule option 2. Options with
  an event gate (O19, O20) get weight 6 while they're eligible.
- At most one Relics option per shop phase.
- Option 3 is drawn from the resource options (§4) in the same way, uniformly among the ones
  unlocked.

## 2. Theme options (15)

The themes from `core-mechanics.md` §6.3, each in the standard frame (§1.1). They stock parts
whose tags match. Passive and Triggered read the part's effect, not a tag (`parts-list.md` §1.5).

| ID | Theme | Stocks | Gate | Notes |
|---|---|---|---|---|
| T01 | Weapon | Weapon tag | Act 1 | |
| T02 | Defence | Defence tag | Act 1 | |
| T03 | Tricky | Tricky tag | Act 1 | |
| T04 | Chariot body | Bodies | Act 1 | Shop: 2 bodies, no reroll. Pack: 3 gold, 1 of 2. Body prices and list are Open (§6). |
| T05 | Attack | Attack tag | Act 1 | |
| T06 | Fire | Fire tag | Act 1 | |
| T07 | Ice | Ice tag | Act 1 | |
| T08 | Wind | Wind tag | Act 1 | |
| T09 | Earth | Earth tag | Act 1 | |
| T10 | Electric | Electric tag | Act 1 | |
| T11 | Acid | Acid tag | Act 1 | Acid has the fewest commons (2). It is almost garrenteed to contain uncommon items. |
| T12 | Relics | Relics | Act 2 | Shop: 2 relics at 10 gold each (the Balatro voucher price), no reroll. Pack: 5 gold, 1 of 2. |
| T13 | Stats | Stats tag | Act 1 | |
| T14 | Passive | Parts with a passive effect and no trigger cost | Act 1 | Picks up Wheel and Negative parts, which have no theme of their own. |
| T15 | Triggered | Parts with a trigger effect | Act 1 | |

## 3. Rule options (20)

Each has its own frame. "Any theme" means the item pool is every part. "One theme" means the
option rolls one theme from T01–T15 (not T04 or T12) and shows it on the option button.

### 3.1 Act 1

| ID | Name | Form | Stock | Shown / pick | Cost | Rerolls | Downside | Rule | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| O01 | Scrapyard | Shop | Any theme, commons only | 6 / any | 1 gold each | None | Commons only | | A: Bazaar Curio (10 Bronze items) |
| O02 | Overstock | Shop | Any theme | 5 / any | Normal price | None | No reroll | | M: Balatro Overstock voucher (more slots) |
| O03 | Two-Theme Fair | Shop | Two themes, 2 items each | 4 / any | Normal price | 1 for 2 gold | | | C: two Bazaar merchants in one stall |
| O05 | Tire Yard | Shop | Wheel parts | 3 / any | Normal price | 3 free | | | A: Bazaar Aero (Vehicles merchant) |
| O06 | Dig Site | Pack | Any theme | 3 / 1 | Free entry | Unlimited: 1 gold, +1 each | Rerolls get expensive fast | Counts as opening a pack. | A: Bazaar Pearl's Dig Site |
| O07 | Rain Check | Coupon | Nothing now | — | Free | — | You get nothing this stage | The first item you buy in the next shop phase is free. A pack's entry counts as an item. | A: Balatro Coupon Tag (skip now, free later) |
| O08 | Mystery Crate | Pack | Any theme | 1 hidden / 1 | 2 gold | None | You can't see it first | Rare chance doubled. Counts as opening a pack. | E: Balatro pack choice (take away the choice, keep the pack) |
| O09 | Blood Bank | Shop | Any theme | 3 / any | HP: common 40, uncommon 120, rare 240 | 1 for 30 HP | Starts the next battle with less HP | You can't drop below 100 HP. | S: Bazaar and Balatro gold prices, paid in HP |
| O10 | Lucky Wheel | Game | — | — | 3 gold | None | 30% chance of nothing | Spin once: 30% +5 gold, 30% a random uncommon part, 10% a random rare part, 30% nothing. | A: Bazaar Haddy (prize wheel) |

### 3.2 Act 2

| ID | Name | Form | Stock | Shown / pick | Cost | Rerolls | Downside | Rule | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| O11 | Specialist | Shop | One theme, no commons | 2 / any | Normal price | 1 for 4 gold | Fewer items, pricier reroll | | M: Bazaar Silvia / Goldie (tier merchants) |
| O12 | Jumbo Pack | Pack | One theme | 5 / 1 | 5 gold | None | | | M: Balatro Jumbo pack |
| O13 | Dutch Auction | Shop | Any theme | 3 / any | Starts at 2× price | None | Items disappear while you wait | **Wait** drops every price by 25% of its starting price (minimum 1 gold), then a rival buys one random unbought item. | R: Balatro reroll cost that rises within a shop, turned into prices that fall |
| O14 | Layaway | Shop | Any theme, no commons | 3 / any | 25% off (uncommon 4, rare 9) | 1 for 2 gold | Parts miss the next battle | Bought parts arrive at the start of the next shop phase. They take inventory space then, not now. | A: Balatro Investment Tag (pay off later) |
| O15 | Loan Shark | Shop | Any theme | 3 / any | Normal price | 1 for 2 gold | Debt with interest | You may spend down to −10 gold. The next Stage 1 pays off the debt × 1.5 first. | R: Balatro interest (you pay the bank) + Credit Card |
| O16 | Black Market | Shop | Any theme, rares only | 3 / any | 9 gold each | None | Fire penalty | For each part bought here, your body starts the next battle with 5 Flame. | S: gold discount paid for with a next-battle penalty |
| O17 | Storage Locker | Shop | Negative parts | 2 / any | Normal price + 2 | None | Pricey | The only option aimed at inventory space. | A: Balatro Negative edition (+$5) |

### 3.3 Act 3

| ID | Name | Form | Stock | Shown / pick | Cost | Rerolls | Downside | Rule | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| O18 | Mega Pack | Pack | One theme | 5 / 2 | 8 gold | None | | | M: Balatro Mega pack |

### 3.4 Event-gated

| ID | Name | Form | Stock | Shown / pick | Cost | Rerolls | Gate | Rule | SCAMPER |
|---|---|---|---|---|---|---|---|---|---|
| O19 | Scout's Tent | Shop | Parts that counter the next fight's modifier | 3 / any | Normal price | 1 for 2 gold | Only in the shop phase right before an elite or the boss | Shows the coming modifier on the option button. | P: Balatro Boss Blind preview as a shop |
| O20 | Spoils | Pack | Parts from the elite you just beat (base state) | 3 / 1 | Free entry | None | Only in the shop phase right after an elite | Counts as opening a pack. | P: the enemy's layout (`core-mechanics.md` §8) as stock |

## 4. Resource options (10)

Option 3 of every stage. Non-combat rewards (`core-mechanics.md` §6.4). "Next battle" effects
last for that one fight.

| ID | Name | Gate | Effect | Downside | SCAMPER |
|---|---|---|---|---|---|
| RS01 | Payday | Act 1 | Gain 4 gold. | | A: Balatro Blind reward |
| RS02 | Revive Health | Act 1 | +80 max HP for the rest of the run. | | discussion example (`core-mechanics.md` §6.4) |
| RS03 | Interest | Act 1 | Gain 1 gold per 5 gold you hold. | | A: Balatro interest |
| RS04 | Investment | Act 1 and 2 only | +1 gold at every later Stage 1 for the rest of the run. | Pays off slowly | A: Bazaar Income stat |
| RS05 | Polish | Act 1 | Every part in your inventory gains +1 sell value permanently. | | A: Balatro Gift Card (one-off instead of each round) |
| RS06 | Field Repair | Act 1 | Heal all HP lost in this shop phase. | Only useful after HP costs | R: Blood Bank (O09), undone |
| RS07 | Reroll Token | Act 1 | Your next reroll in this shop phase is free. | | A: Balatro D6 Tag |
| RS08 | Scouting Report | Act 1 | See the next enemy's chariot layout before the next stage. | | P: Balatro Boss Blind preview |
| RS09 | Head Start | Act 2 | Your body starts the next battle with 50 Block. | | P: Steel Plate (C11) as a one-off |
| RS10 | Blood Money | Act 2 | Gain 10 gold. | Start the next battle with 150 less HP | S: Payday (RS01) paid for in HP |

## 5. Parts that interact with options

- **Trade-In Coupon (U67)**, "the first reroll in each shop phase is free": works on any reroll,
  including Dig Site (O06) and Blood Bank (O09, where it saves the 30 HP). Dutch Auction's Wait
  (O13) is not a reroll.
- **Pack triggers** ("you open a pack", `parts-list.md` §1.4): fire for theme packs, Dig Site
  (O06), Mystery Crate (O08), Jumbo Pack (O12), Mega Pack (O18) and Spoils (O20). Lucky Wheel
  (O10) and Rain Check (O07) are not packs.
- **Merchant build (U64–U68, R29–R30)**: selling stays the same everywhere, so these parts don't
  depend on which options show up. Polish (RS05) is the one resource that feeds them directly.
- **Negative parts (U28, U66, U68, R30)**: show up in Passive (T14) and Storage Locker (O17).
  Layaway parts (O14) arriving with a full inventory go back to the normal rule: sell something
  or decline them.

## 6. Open

- Whether Loan Shark (O15) debt can stack across stages in one shop phase.
- Whether Layaway parts (O14) can be declined for a refund.

## 7. Changes to make in `core-mechanics.md`

Not applied yet:

- §6.1–6.2: shop and pack numbers are the standard frame. Rule options can change them.
- §6.2: reroll cost is 2 gold. The pack/shop split is 40/60 for theme options.
- §6.3: Wheel and Negative parts have no theme. They reach the shop through Passive, Tire Yard
  and Storage Locker. Relics are Balatro-style vouchers.
- §6.4: the resource list is closed by §4 here. Options may cost HP, which carries into the next
  battle.
- §8: Act-based rarity odds (§1.3 here) are a starting point for the enemy rarity mix too.
