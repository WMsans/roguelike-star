extends ChTest

# Task 4: ChPrices, the run's price table. Every number here is pinned by the spec
# (docs/superpowers/specs/2026-11-12-run-shop-and-card-feel-design.md): prices 2 / 6 / 12 by
# rarity, sell value floor(price / 2), pack 3, reroll 3, rarity weights 60 / 30 / 10.


func test_prices() -> void:
	assert_eq(ChPrices.price(&"common"), 2, "common costs 2")
	assert_eq(ChPrices.price(&"uncommon"), 6, "uncommon costs 6")
	assert_eq(ChPrices.price(&"rare"), 12, "rare costs 12")
	# Sell is half the price, rounded down: 2/2 and 12/2 land on 1 and 6.
	assert_eq(ChPrices.sell_value(&"common"), 1, "a common sells for 1")
	assert_eq(ChPrices.sell_value(&"uncommon"), 3, "an uncommon sells for 3")
	assert_eq(ChPrices.sell_value(&"rare"), 6, "a rare sells for 6")
	assert_eq(ChPrices.PACK, 3, "a card pack costs 3")
	assert_eq(ChPrices.REROLL, 3, "a reroll costs 3")
	assert_eq(ChPrices.WEIGHTS, {&"common": 60, &"uncommon": 30, &"rare": 10}, "weights 60/30/10")
	_complete()


func test_roll_weights() -> void:
	# Every draw in a run comes from the run's own rng, so roll_rarity takes one; seeding it makes
	# this count reproducible. The bands are the 60/30/10 weights with room for a 10 000-roll spread.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {&"common": 0, &"uncommon": 0, &"rare": 0}
	for i in 10000:
		var rarity: StringName = ChPrices.roll_rarity(rng)
		assert_true(seen.has(rarity), "%s is a rarity the table prices" % rarity)
		if seen.has(rarity):
			seen[rarity] += 1
	assert_near(float(seen[&"common"]) / 10000.0, 0.6, 0.03, "common lands in 0.57..0.63")
	assert_near(float(seen[&"rare"]) / 10000.0, 0.1, 0.02, "rare lands in 0.08..0.12")
	_complete()
