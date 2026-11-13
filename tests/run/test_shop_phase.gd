extends ChTest

# Task 7: ChShopPhase, the four stages as rules. Stage 1 is the reward credit and has no screen, stages
# 2..4 each show three option cards, and stage 5 is done. The pinned numbers are the plan's: reward 5
# normal / 10 elite, prices 2 / 6 / 12, sell floor(price / 2), pack 3, reroll 3, resource +4 gold or
# +100 max HP, and a theme only in play when at least 3 distinct items match it.

const SEED := 7


func _phase(run_seed: int = SEED) -> ChShopPhase:
	# One catalog for both: ChCatalog.load_default() builds a NEW catalog per call, so a shop handed a
	# second one would price and HP-read a different table than the run holds.
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(run_seed, catalog)
	return ChShopPhase.new(run, catalog)


func _shop_phase(run_seed: int = SEED) -> ChShopPhase:
	# A phase sitting on a picked shop stage with its three items rolled. Which card is a shop is
	# random, so this walks the stages, and then the seeds, until one offers it.
	for attempt in 20:
		var phase := _phase(run_seed + attempt)
		while not phase.done():
			for i in phase.options.size():
				if phase.options[i]["kind"] == &"shop" and phase.pick(i):
					return phase
			phase.next()
	return _phase(run_seed)  # only reachable if no seed offers a shop; the test's own asserts say so


func _pack_index(phase: ChShopPhase) -> int:
	for i in phase.options.size():
		if phase.options[i]["kind"] == &"pack":
			return i
	return -1


func _pack_phase(run_seed: int = SEED) -> ChShopPhase:
	# A phase on an unpicked stage that shows a pack at a part theme: a body pack swaps the hull instead
	# of filling the inventory, which test_body_swap_overflow_sold covers instead.
	for attempt in 20:
		var phase := _phase(run_seed + attempt)
		while not phase.done():
			var at := _pack_index(phase)
			if at >= 0 and phase.options[at]["theme"] != &"body":
				return phase
			phase.next()
	return _phase(run_seed)


func _mount_all_slots(run: ChRun, part_id: StringName) -> void:
	# Every top-level slot on the current body that is still free, in order. Top-level slots only never
	# overflow: a subtree always finds a seat when there are more body slots than subtrees
	# (test_layout.gd's cross-size swap proves that pairing), so an overflow test needs one part per
	# slot, including the slots the start kit already took.
	var body: ChBodyDef = run.catalog.body(run.layout.body_id)
	for slot in body.slots.size():
		run.layout.place([slot], part_id)


func test_stage1_credits_reward() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(SEED, catalog)
	run.fight_index = 2  # an elite: the pay table is 10 here, 5 on a normal fight
	var phase := ChShopPhase.new(run, catalog)
	assert_eq(phase.credited, 10, "an elite pays 10")
	assert_eq(run.gold, 30, "and it lands on the run's 20 at once")
	assert_eq(phase.stage, 2, "stage 1 is the credit, so the first screen is stage 2")
	assert_eq(phase.options.size(), 3, "with three option cards already rolled")
	assert_eq(phase.items.size(), 0, "and nothing on the counter until a card is picked")
	_complete()


func test_option_rules() -> void:
	# Every rule the plan pins for the three cards, over 50 run seeds and all three card stages.
	for run_seed in 50:
		var phase := _phase(run_seed)
		var previous: Array[StringName] = []
		for stage in [2, 3, 4]:
			assert_eq(phase.stage, stage, "seed %d is on stage %d" % [run_seed, stage])
			assert_eq(phase.options.size(), 3, "seed %d stage %d shows three cards" % [run_seed, stage])
			var themes: Array[StringName] = []
			for option in phase.options:
				var theme: StringName = option["theme"]
				themes.append(theme)
				if option["kind"] == &"resource":
					assert_true(option["resource"] in [&"gold", &"hp"], "a resource card says which resource")
				else:
					assert_true(theme in phase.available_themes(),
						"seed %d stage %d offers theme %s, which is in play" % [run_seed, stage, theme])
			assert_true(phase.options[0]["kind"] != &"resource", "card 1 is a shop or a pack")
			assert_true(phase.options[1]["kind"] != &"resource", "card 2 is a shop or a pack")
			assert_true(phase.options[0]["theme"] != phase.options[1]["theme"],
				"seed %d stage %d: cards 1 and 2 are different themes" % [run_seed, stage])
			for theme in [themes[0], themes[1]]:
				assert_true(not previous.has(theme),
					"seed %d stage %d does not offer last stage's %s again" % [run_seed, stage, theme])
			assert_eq(phase.options[2]["kind"], &"resource", "card 3 is a resource")
			previous = themes
			phase.next()
		assert_true(phase.done(), "seed %d is done after stage 4" % run_seed)
	_complete()


func test_themes_threshold() -> void:
	var phase := _phase()
	var themes: Array[StringName] = phase.available_themes()
	themes.sort()
	# The six the spec lands on with the 12 parts and 3 bodies on disk. Defence, Ice, Wind, Earth,
	# Electric, Acid, Relics, Stats and Attack stay out because too few items match them.
	var expected: Array[StringName] = [&"body", &"fire", &"passive", &"triggered", &"tricky", &"weapon"]
	expected.sort()
	assert_eq(themes, expected, "every theme with at least 3 matching items, and no other")
	_complete()


func test_buy_exact_gold() -> void:
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var first: Dictionary = phase.items[0]
	var price: int = int(first["price"])
	run.gold = price
	assert_true(phase.buy(0), "gold exactly equal to the price (%d) buys" % price)
	assert_eq(run.gold, 0, "and it lands on 0, never below")
	assert_true(bool(first["taken"]), "the bought card reads taken")
	if bool(first["is_body"]):
		assert_eq(run.layout.body_id, first["id"], "a bought body is swapped in at once")
	else:
		assert_true(run.inventory.has(first["id"]), "a bought part is carried")
	assert_true(not phase.buy(0), "and one card cannot be taken twice")
	var second: Dictionary = phase.items[1]
	var second_price: int = int(second["price"])
	run.gold = second_price - 1
	assert_true(not phase.buy(1), "one gold short of %d is refused" % second_price)
	assert_eq(run.gold, second_price - 1, "and the gold is untouched")
	assert_true(not bool(second["taken"]), "and the card stays on the counter")
	_complete()


func test_buy_refused_when_full() -> void:
	var phase := _shop_phase()
	var run: ChRun = phase.run
	# The card is built here rather than rolled: what is under test is the inventory rule, and a
	# rolled part costs 2 or 6, so a hand-built card keeps the gold arithmetic exact.
	phase.items = [{"id": &"cutter_chainsaw", "is_body": false, "rarity": &"common", "price": 2, "taken": false}]
	run.gold = 20
	for i in ChInventory.CAPACITY:
		assert_true(run.inventory.add(&"wheel"), "carry %d" % i)
	assert_eq(run.inventory.free_slots(), 0, "the inventory is full")
	assert_true(not phase.buy(0), "a part cannot be bought into a full inventory")
	assert_eq(run.gold, 20, "and nothing is charged")
	assert_eq(run.inventory.part_ids.size(), ChInventory.CAPACITY, "and nothing is added")
	# Selling makes room, which is the way out the spec pins.
	assert_eq(phase.sell(0), 1, "selling a carried common pays 1")
	assert_true(phase.buy(0), "and the same buy goes through with a free slot")
	assert_true(run.inventory.has(&"cutter_chainsaw"), "and the part lands in the freed slot")
	_complete()


func test_pack_skip() -> void:
	var phase := _pack_phase()
	var run: ChRun = phase.run
	var at := _pack_index(phase)
	assert_true(at >= 0, "the stage offers a pack")
	var carried: Array[StringName] = run.inventory.part_ids.duplicate()
	run.gold = ChPrices.PACK - 1
	assert_true(not phase.pick(at), "a pack is refused when gold is short of its 3")
	assert_eq(run.gold, ChPrices.PACK - 1, "and a refused pick charges nothing")
	assert_true(phase.picked.is_empty(), "and does not commit the stage")
	run.gold = ChPrices.PACK + 2
	assert_true(phase.pick(at), "the pack opens")
	assert_eq(run.gold, 2, "and the 3 gold is spent on pick, whether or not anything is taken")
	assert_eq(phase.items.size(), 3, "with three cards in the pack")
	assert_true(not phase.pick(at), "a second pick is refused: the stage is already committed")
	assert_eq(run.gold, 2, "and the 3 is not charged twice")
	phase.next()
	assert_true(not phase.take(0), "nothing is taken after Next")
	assert_eq(phase.items.size(), 0, "and Next clears the counter")
	assert_eq(run.inventory.part_ids, carried, "and the inventory is unchanged")
	assert_true(phase.picked.is_empty(), "the next stage starts uncommitted")
	_complete()


func test_pack_one_take() -> void:
	var phase := _pack_phase(SEED + 1)
	var run: ChRun = phase.run
	var at := _pack_index(phase)
	assert_true(at >= 0, "the stage offers a pack")
	run.gold = 10
	assert_true(phase.pick(at), "the pack opens for its 3 gold")
	assert_eq(run.gold, 7, "and take costs nothing")
	var took: StringName = phase.items[0]["id"]
	assert_true(phase.take(0), "one card is free")
	assert_true(run.inventory.has(took), "and it is carried")
	assert_eq(run.gold, 7, "taking is free")
	assert_true(not phase.take(0), "the same card cannot be taken twice")
	assert_true(not phase.take(1), "nor can a second card: a pack grants one")
	run.gold = 20
	assert_true(not phase.buy(1), "a pack card is not bought: buy is the shop's action")
	assert_true(not phase.reroll(), "a pack has no reroll")
	assert_eq(run.inventory.part_ids.size(), 1, "and nothing else landed")
	_complete()


func test_reroll_once() -> void:
	# The first reroll is 3 gold, there is only ever one, and the items actually change somewhere in
	# ten seeds. A fixed seed could land on the same three cards by chance, so the change is checked
	# across seeds rather than pinned to one.
	var changed := 0
	for run_seed in 10:
		var phase := _shop_phase(run_seed)
		var run: ChRun = phase.run
		var gold_after_pick := run.gold
		var rolled: Array = []
		for item in phase.items:
			rolled.append(item["id"])
		run.gold = gold_after_pick + ChPrices.REROLL
		assert_true(phase.reroll(), "seed %d: the first reroll is allowed" % run_seed)
		assert_eq(run.gold, gold_after_pick, "and costs 3")
		assert_true(phase.rerolled, "and the stage records that it happened")
		assert_eq(phase.items.size(), 3, "with three fresh cards")
		assert_true(not phase.reroll(), "and a second reroll is refused")
		assert_eq(run.gold, gold_after_pick, "which charges nothing")
		var again: Array = []
		for item in phase.items:
			again.append(item["id"])
		if again != rolled:
			changed += 1
	assert_true(changed >= 1, "the items change for at least one seed out of ten, got %d" % changed)
	_complete()


func test_sell_half() -> void:
	var phase := _phase()
	var run: ChRun = phase.run
	# ring_of_fire is the rare part on disk (12 gold), so its sell value is the plan's 6.
	assert_true(run.inventory.add(&"wheel"), "a common goes first so the free-slot change shows")
	assert_true(run.inventory.add(&"ring_of_fire"), "and the rare part with it")
	var before := run.gold
	var slots_before := run.inventory.free_slots()
	assert_eq(phase.sell(1), 6, "selling a rare part adds 6")
	assert_eq(run.gold, before + 6, "and the gold is on the run")
	assert_eq(run.inventory.free_slots(), slots_before + 1, "and it frees a slot")
	assert_true(not run.inventory.has(&"ring_of_fire"), "and the part is gone")
	assert_eq(phase.sell(0), 1, "a common sells for 1")
	# Selling is not a shop-only action: it works with no stage picked, and on a done phase.
	assert_true(phase.picked.is_empty(), "with nothing picked at all")
	phase.next()
	phase.next()
	phase.next()
	assert_true(phase.done(), "the phase is over")
	assert_true(run.inventory.add(&"hearth"), "a carried part is still sellable")
	assert_eq(phase.sell(run.inventory.part_ids.size() - 1), 3, "an uncommon still sells for 3")
	assert_eq(phase.sell(99), 0, "and an index with nothing in it gains nothing")
	_complete()


func test_body_swap_overflow_sold() -> void:
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var catalog: ChCatalog = phase.catalog
	# Dozer is the slice's 6-slot hull and Cutter the 4-slot one, so a full Dozer build moving to the
	# Cutter has exactly two top-level subtrees with no seat. The setup swaps bodies directly and the
	# card is written here rather than rolled: what is under test is what the shop does with the
	# overflow a swap hands back, not how the swap itself works (test_layout.gd pins that).
	run.layout.swap_body(catalog.body(&"dozer"), catalog)
	_mount_all_slots(run, &"wheel")
	var mounted_before := _mounted_count(run.layout)
	assert_eq(mounted_before, 6, "the Dozer build fills all six top-level slots")
	for i in ChInventory.CAPACITY:
		assert_true(run.inventory.add(&"strut"), "and the inventory carries %d" % i)
	# The stage is a picked shop, so this is the counter; the card is the Cutter, common at 2 gold, the
	# cheapest way to reach a swap.
	phase.items = [{"id": &"cutter", "is_body": true, "rarity": &"common", "price": 2, "taken": false}]
	run.gold = 2
	var carried_before := run.inventory.part_ids.size()
	var gold_before := run.gold
	assert_true(phase.buy(0), "a body is bought with no free slot, because a body needs none")
	assert_eq(run.layout.body_id, &"cutter", "and it is swapped in")
	var sold: Array[StringName] = phase.auto_sold.duplicate()
	assert_eq(sold.size(), 2, "two subtrees found no seat")
	for id in sold:
		assert_true(catalog.part(id) != null, "%s is an id the catalog can price" % id)
	# The invariant the plan pins: nothing the build held disappears in the swap.
	assert_eq(_mounted_count(run.layout) + run.inventory.part_ids.size() + sold.size(),
		mounted_before + carried_before,
		"mounted + carried + sold equals the parts before the buy")
	var gained := 0
	for id in sold:
		gained += ChPrices.sell_value(catalog.part(id).rarity)
	assert_eq(run.gold, gold_before - 2 + gained, "gold rose by the sum of the sell values (%d)" % gained)
	assert_eq(run.inventory.part_ids.size(), carried_before, "a full inventory carries nothing new")
	_complete()


func _mounted_count(layout: ChChariotLayout) -> int:
	# Every part the build holds, parents and children: all_paths lists the nested paths too, so the
	# count walks the top-level subtrees and lets subtree_part_ids count inside each one.
	var total := 0
	for path in layout.all_paths():
		if path.size() == 1:
			total += layout.subtree_part_ids(layout.get_node(_typed_path(path))).size()
	return total


func test_resource_hp() -> void:
	# Which resource a stage offers is drawn, so this walks the stages and seeds until one offers the
	# +100 max HP card, then takes it.
	var phase: ChShopPhase = null
	for run_seed in 20:
		var try_phase := _phase(SEED + run_seed)
		while not try_phase.done():
			if try_phase.options[2]["resource"] == &"hp":
				phase = try_phase
				break
			try_phase.next()
		if phase != null:
			break
	assert_true(phase != null, "some seed within 20 offers the max HP card")
	var run: ChRun = phase.run
	var body: ChBodyDef = phase.catalog.body(run.layout.body_id)
	assert_true(phase.pick(2), "and it can be picked")
	assert_eq(run.hp_bonus, 100, "it adds 100 to the run's max HP bonus")
	assert_eq(run.player_layout().max_hp, body.hp + 100, "and the fight sees it on top of the body's HP")
	assert_true(not phase.pick(2), "once, since it commits the stage")
	_complete()
