# Balatro: Shop Mechanics

How Balatro's shop works: slots, odds, prices, rerolls, packs, vouchers and money. Collected from the Balatro wiki on 2026-11-04.

Source: https://balatrowiki.org (pages: The Shop, Booster Packs, Vouchers, Money, Editions, Stickers, Tags). Numbers are for the base game. The wiki notes a few unclear values; those are flagged below.

## When the shop appears

- A run has Antes. Each Ante has three Blinds: Small, Big, and Boss.
- After you beat a Blind you cash out, and the shop opens. So there is one shop visit per Blind beaten, up to three per Ante.
- You can skip a Small or Big Blind. Skipping gives a Tag and no shop for that Blind.

## Layout

Each shop has three sections:

| Section | Slots | Restocks when |
|---|---|---|
| Random cards | 2 (3 with Overstock, 4 with Overstock Plus) | Every reroll and every new shop |
| Booster Packs | 2 | Every new shop only. Rerolls do not change them |
| Voucher | 1 | After you beat the Boss Blind (once per Ante). A Voucher Tag adds one more |

- The first shop of a run always includes a normal Buffoon Pack (Jokers).
- An item you buy leaves an empty slot until the next reroll or shop. Overstock Plus refills empty slots when you buy.

## Random card slot odds

Each slot rolls a card type by weight:

| Type | Weight | Chance (default) | Notes |
|---|---|---|---|
| Joker | 20 | 71.4% | The main build piece |
| Tarot | 4 | 14.3% | Card modifiers and utility |
| Planet | 4 | 14.3% | Levels up a poker hand |
| Playing card | 4 | — | Only after buying the Magic Trick voucher |
| Spectral | 2 | — | Only with the Ghost Deck |

- Joker rarity in the shop: Common 70%, Uncommon 25%, Rare 5%. Legendary Jokers never appear in the shop. They only come from the Soul spectral card.
- Tarot Merchant / Tycoon make Tarots 2× / 4× as common. Planet Merchant / Tycoon do the same for Planets. (The wiki's stated weights for these don't fully match the multipliers.)
- With Illusion, shop playing cards have a 40% chance to be enhanced and 20% to have an edition.
- The same Joker won't show up twice unless you own Showman.

## Base prices

| Item | Cost |
|---|---|
| Common Joker | $1–6 (set per Joker) |
| Uncommon Joker | $4–8 |
| Rare Joker | $7–10 |
| Legendary Joker | $20 (not sold in the shop) |
| Playing card | $1 |
| Tarot | $3 |
| Planet | $3 |
| Spectral | $4 |
| Booster Pack | Normal $4, Jumbo $6, Mega $8 |
| Voucher | $10 (upgraded Vouchers were $20 before patch 1.0.0h, now $10) |

### Editions (add to price)

| Edition | Effect | Joker | Playing card | Consumable |
|---|---|---|---|---|
| Foil | +50 Chips | +$2 | +$2 | — |
| Holographic | +10 Mult | +$3 | +$3 | — |
| Polychrome | ×1.5 Mult | +$5 | +$5 | — |
| Negative | +1 Joker slot (or +1 consumable slot) | +$5 | — | +$5 |

Edition chance on a shop Joker by default: Foil 2%, Holographic 1.4%, Polychrome 0.3%, Negative 0.3%. Hone and Glow Up raise these (Hone 2×, Glow Up 4× for Foil, Holo and Polychrome). The wiki's table of exact boosted values is not labelled clearly.

### Stickers (higher stakes)

Each sticker has a 30% chance to appear on a shop Joker once its stake is reached:

| Sticker | Effect |
|---|---|
| Eternal | Can't be sold or destroyed |
| Perishable | Debuffed after 5 rounds |
| Rental | Buy price is $1, but costs $3 at the end of each round |

Eternal and Perishable can't be on the same Joker. Some Jokers are not allowed to have one or the other.

### Buy price formula

1. Base cost + edition cost + Inflation (challenge only: +$1 per purchase made).
2. × discount (Clearance Sale 0.75, Liquidation 0.5).
3. Round half down.
4. Minimum $1.
5. Special cases override: Astronomer (Planets and Celestial Packs $0), Rental ($1), Coupon Tag ($0).

### Sell value

- Sell value = current buy price ÷ 2, rounded down, minimum $1.
- You can sell Jokers and consumables at any time, not only in the shop.
- Egg gains +$3 sell value each round. Gift Card gives every Joker and consumable +$1 sell value each round.
- Discounts lower buy price, so they also lower sell value.

## Rerolls

- The first reroll in each shop costs $5. Each reroll after that costs $1 more. The price goes back to $5 in the next shop.
- A reroll only replaces the random card slots. Packs and the Voucher stay.
- Discounts: Reroll Surplus −$2 (starts at $3), Reroll Glut −$4 total (starts at $1).
- Chaos the Clown: one free reroll per shop. D6 Tag: rerolls in the next shop start at $0.
- Flash Card (Joker) gains +2 Mult per reroll, which rewards rerolling more.

## Booster Packs

When you open a pack, you see some cards and choose one or two. You can skip at any time. Tarot and Spectral packs deal you a hand of playing cards so you can use the card right away.

| Pack | Contents | Normal (show / pick) | Jumbo | Mega | Total chance |
|---|---|---|---|---|---|
| Arcana | Tarot cards, used right away | 3 / 1 | 5 / 1 | 5 / 2 | 28.99% |
| Celestial | Planet cards, used right away | 3 / 1 | 5 / 1 | 5 / 2 | 28.99% |
| Standard | Playing cards, added to deck (often enhanced, sealed or with an edition) | 3 / 1 | 5 / 1 | 5 / 2 | 28.99% |
| Buffoon | Jokers | 2 / 1 | 4 / 1 | 4 / 2 | 8.7% |
| Spectral | Spectral cards, used right away | 2 / 1 | 4 / 1 | 4 / 2 | 4.33% |

Size weights within each type: Normal 4, Jumbo 2, Mega 0.5 (Buffoon 1.2/0.6/0.15, Spectral 0.6/0.3/0.07).

- Packs always show the full number of cards. Duplicates can appear.
- Pack contents follow a fixed order per seed, so the order you open packs in doesn't change what you get.
- Telescope makes Celestial Packs always include the Planet for your most-played hand. Omen Globe gives each Arcana card a 20% chance to be a Spectral.
- Red Card (Joker) gains +3 Mult each time you skip a pack.

## Vouchers

Vouchers are permanent run upgrades. Each costs $10. Every base Voucher has an upgraded version, which only appears after you own the base one (and after it's unlocked on your profile).

| Base | Effect | Upgrade | Effect |
|---|---|---|---|
| Overstock | +1 card slot | Overstock Plus | +1 more slot; refills slots when you buy |
| Clearance Sale | 25% off cards and packs | Liquidation | 50% off |
| Hone | Editions 2× as common | Glow Up | 4× as common |
| Reroll Surplus | Rerolls −$2 | Reroll Glut | Another −$2 |
| Crystal Ball | +1 consumable slot | Omen Globe | Spectrals can show up in Arcana Packs |
| Telescope | Celestial Packs always have your top hand's Planet | Observatory | Held Planets give ×1.5 Mult for their hand |
| Grabber | +1 hand per round | Nacho Tong | +1 more |
| Wasteful | +1 discard per round | Recyclomancy | +1 more |
| Tarot Merchant | Tarots 2× as common | Tarot Tycoon | 4× |
| Planet Merchant | Planets 2× as common | Planet Tycoon | 4× |
| Seed Money | Interest cap $10 | Money Tree | Interest cap $20 |
| Blank | Nothing | Antimatter | +1 Joker slot |
| Magic Trick | Playing cards in shop | Illusion | Shop playing cards can be enhanced / have editions |
| Hieroglyph | −1 Ante, −1 hand per round | Petroglyph | −1 Ante, −1 discard per round |
| Director's Cut | Reroll the Boss once per Ante for $10 | Retcon | Unlimited Boss rerolls at $10 |
| Paint Brush | +1 hand size | Palette | +1 more |

- Every eligible Voucher has the same chance to appear. A Voucher you don't buy can show up again.
- When every unlocked Voucher has been bought, only Blank can appear.
- Many Vouchers change the shop itself (slots, prices, odds, rerolls), so buying one changes every shop after it.

## Money

### Income

| Source | Amount |
|---|---|
| Starting money | $4 (Yellow Deck $14) |
| Small / Big / Boss Blind reward | $3 / $4 / $5 (Showdown Boss $8). No Small Blind reward on Red Stake and above |
| Each unused hand | $1 |
| Interest | $1 per $5 held at cash out, max $5 (Seed Money max $10, Money Tree max $20) |

- Interest gives a reason to save money instead of spending all of it. Holding $25 earns the full $5 each round, which means you trade shop power now for money later.
- Money Jokers (Golden Joker, Rocket, Egg, To Do List, etc.) and Gold cards/seals add more income.
- Credit Card allows debt down to −$20.

### Tags (from skipping Blinds)

Skipping a Blind gives a Tag. Several Tags change the next shop:

| Tag | Effect |
|---|---|
| Uncommon / Rare | Next shop has a free Uncommon / Rare Joker |
| Foil / Holographic / Polychrome / Negative | Next base Joker in the shop is free and gets that edition |
| Coupon | Cards and packs in the next shop are free |
| D6 | Rerolls in the next shop start at $0 |
| Voucher | Adds one Voucher to the next shop |
| Standard / Charm / Meteor / Buffoon / Ethereal | Free Mega pack of that type (Ethereal: normal Spectral) |
| Economy | Doubles your money (max +$40) |
| Investment | +$25 after the next Boss |

Tags stack and trigger oldest first. Some Tags can't appear in Ante 1.

## Key design points

- **Few slots, fast loop.** Only 2 random cards plus 2 packs per shop, with a shop after almost every Blind. Each shop is quick and there are many of them.
- **Rerolls get more expensive within one shop** ($5, $6, $7…) but reset next shop. Rerolling a lot in one shop costs more and more, while one reroll per shop stays cheap.
- **Packs are a second shop.** They have their own weights, they don't change on reroll, and they offer a choice of 1 from several.
- **Vouchers change the shop itself.** One per Ante, permanent, and many of them change prices, slots or odds.
- **Interest makes saving a real option.** Money you don't spend earns more money, up to a cap.
- **Selling is always open.** Half price back, so trying a Joker costs about half its price.
- **Skipping a Blind trades a shop for a Tag.** Many Tags are shop coupons for later.
