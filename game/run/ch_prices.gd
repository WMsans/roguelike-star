class_name ChPrices extends RefCounted

# The whole price table for a run: rarity is what a part or body costs, and nothing else does, so no
# def carries a price of its own. Every number here is pinned by the spec
# (docs/superpowers/specs/2026-11-12-run-shop-and-card-feel-design.md).
# shortcut: an unknown rarity raises on the dict key rather than answering a price; the catalog test
# keeps every def on one of the three values below, so a def off the table fails there.

const PRICES := {&"common": 2, &"uncommon": 6, &"rare": 12}
# Rarity weights for a shop roll: 60 / 30 / 10. Duplicates are allowed, so a roll never removes
# anything from the pool.
const WEIGHTS := {&"common": 60, &"uncommon": 30, &"rare": 10}
const PACK := 3  # a card pack at the shop counter
const REROLL := 3  # one more offer set


static func price(rarity: StringName) -> int:
	return PRICES[rarity]


static func sell_value(rarity: StringName) -> int:
	# Half the price, rounded down: int division, so a common is 1 and a rare is 6.
	return price(rarity) / 2


static func roll_rarity(rng: RandomNumberGenerator) -> StringName:
	# One cumulative draw over WEIGHTS (60/30/10), off the rng the caller hands in: every draw in a
	# run comes from run.rng, so nothing here may read the global randf().
	# A Dictionary keeps insertion order, so the buckets run common, uncommon, rare.
	var total := 0
	for weight in WEIGHTS.values():
		total += weight
	var roll := rng.randi_range(0, total - 1)
	for rarity in WEIGHTS:
		if roll < WEIGHTS[rarity]:
			return rarity
		roll -= WEIGHTS[rarity]
	return &"common"  # shortcut: only reachable with an empty WEIGHTS, which the const above is not
