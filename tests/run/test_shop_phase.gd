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
	# A phase on an unpicked stage that shows a pack at a part theme: a body pack lands in the
	# inventory like any other card, and test_body_swap_overflow_sold covers the swap instead.
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
	# Every theme with at least MIN_MATCHING distinct items on disk. Tricky reaches 3 with Task 15's
	# Last Stand batch (the Adrenaline Injector, the Last Rites and the Death Wish).
	var expected: Array[StringName] = [&"acid", &"attack", &"body", &"defence", &"earth", &"electric",
		&"fire", &"ice", &"passive", &"stats", &"tricky", &"triggered", &"weapon", &"wind"]
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
		assert_true(run.inventory.has(first["id"]), "a bought body is carried, not swapped in")
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
	# The cards are built here rather than rolled: what is under test is the inventory rule, and a
	# rolled part costs 2 or 6, so a hand-built card keeps the gold arithmetic exact.
	phase.items = [
		{"id": &"chainsaw", "is_body": false, "rarity": &"common", "price": 2, "taken": false},
		{"id": &"dozer", "is_body": true, "rarity": &"uncommon", "price": 6, "taken": false},
	]
	run.gold = 20
	for i in ChInventory.CAPACITY:
		assert_true(run.inventory.add(&"roller"), "carry %d" % i)
	assert_eq(run.inventory.free_slots(), 0, "the inventory is full")
	assert_true(not phase.buy(0), "a part cannot be bought into a full inventory")
	assert_true(not phase.buy(1), "and neither can a body: it is carried like a part")
	assert_eq(run.gold, 20, "and nothing is charged")
	assert_eq(run.inventory.part_ids.size(), ChInventory.CAPACITY, "and nothing is added")
	# Selling makes room, which is the way out the spec pins.
	assert_eq(phase.sell(0), 1, "selling a carried common pays 1")
	assert_true(phase.buy(0), "and the same buy goes through with a free slot")
	assert_true(run.inventory.has(&"chainsaw"), "and the part lands in the freed slot")
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


func test_take_refused_on_shop_stage() -> void:
	# take is the pack's action. On a picked shop stage the three cards are bought, so a free take has
	# to refuse there; without that check a shop hands out its cards for nothing.
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var carried: Array[StringName] = run.inventory.part_ids.duplicate()
	var gold_before: int = run.gold
	assert_eq(phase.picked.get(&"kind"), &"shop", "the stage is a picked shop")
	assert_true(not phase.take(0), "a shop card cannot be taken for free")
	assert_true(not bool(phase.items[0]["taken"]), "and the card stays on the counter")
	assert_eq(run.inventory.part_ids, carried, "and nothing lands in the inventory")
	assert_eq(run.gold, gold_before, "and nothing is charged")
	_complete()


func test_reroll_refused_when_broke() -> void:
	# The 3 gold comes off before the reroll happens, so the gold check is the only thing keeping a
	# broke shop from rerolling its way into negative gold.
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var rolled: Array = []
	for item in phase.items:
		rolled.append(item["id"])
	run.gold = ChPrices.REROLL - 1
	assert_true(not phase.reroll(), "a reroll is refused one gold short of its 3")
	assert_eq(run.gold, ChPrices.REROLL - 1, "and gold never goes negative")
	assert_true(not phase.rerolled, "and the stage has not spent its reroll")
	var after: Array = []
	for item in phase.items:
		after.append(item["id"])
	assert_eq(after, rolled, "and the counter is untouched")
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


# A part def at this rarity, so a test can price a rarity no part on disk carries (Task 7 leaves every
# part common; the uncommons and rares land in Tasks 8-24).
func _def(id: StringName, rarity: StringName) -> ChPartDef:
	var def := ChPartDef.new()
	def.id = id
	def.display_name = "Fixture"
	def.rarity = rarity
	return def


func test_sell_half() -> void:
	var phase := _phase()
	var run: ChRun = phase.run
	var catalog: ChCatalog = phase.catalog
	var rare := _def(&"test_rare", &"rare")
	var uncommon := _def(&"test_uncommon", &"uncommon")
	catalog.parts[rare.id] = rare
	catalog.parts[uncommon.id] = uncommon
	assert_true(run.inventory.add(&"roller"), "a common goes first so the free-slot change shows")
	assert_true(run.inventory.add(rare.id), "and the rare part with it")
	var before := run.gold
	var slots_before := run.inventory.free_slots()
	assert_eq(phase.sell(1), 6, "selling a rare part adds 6")
	assert_eq(run.gold, before + 6, "and the gold is on the run")
	assert_eq(run.inventory.free_slots(), slots_before + 1, "and it frees a slot")
	assert_true(not run.inventory.has(rare.id), "and the part is gone")
	assert_eq(phase.sell(0), 1, "a common sells for 1")
	# Selling is not a shop-only action: it works with no stage picked, and on a done phase.
	assert_true(phase.picked.is_empty(), "with nothing picked at all")
	phase.next()
	phase.next()
	phase.next()
	assert_true(phase.done(), "the phase is over")
	assert_true(run.inventory.add(uncommon.id), "a carried part is still sellable")
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
	_mount_all_slots(run, &"roller")
	var mounted_before := _mounted_count(run.layout)
	assert_eq(mounted_before, 6, "the Dozer build fills all six top-level slots")
	# A body is carried like a part, so the buy takes the kit's one free slot and equip_body is what
	# swaps it in. Four carried parts leave that slot; the Cutter then fills the kit, so the swap has
	# nowhere to put the two subtrees it detaches.
	for i in ChInventory.CAPACITY - 1:
		assert_true(run.inventory.add(&"strut"), "and the inventory carries %d" % i)
	# The stage is a picked shop, so this is the counter; the card is the Cutter, common at 2 gold, the
	# cheapest way to reach a swap.
	phase.items = [{"id": &"cutter", "is_body": true, "rarity": &"common", "price": 2, "taken": false}]
	run.gold = 2
	var parts_before := mounted_before + 4  # four Struts are parts; the Cutter is a body
	var gold_before := run.gold
	assert_true(phase.buy(0), "a body is bought into a free slot")
	assert_eq(run.layout.body_id, &"dozer", "and buying it swaps nothing: it is carried")
	assert_eq(run.inventory.free_slots(), 0, "the card took the last slot")
	assert_true(phase.equip_body(run.inventory.part_ids.find(&"cutter")), "the carried body goes on")
	assert_eq(run.layout.body_id, &"cutter", "and it is swapped in")
	var sold: Array[StringName] = phase.auto_sold.duplicate()
	assert_eq(sold.size(), 2, "two subtrees found no seat")
	for id in sold:
		assert_true(catalog.part(id) != null, "%s is an id the catalog can price" % id)
	# The invariant the plan pins: nothing the build held disappears in the swap, and the body the
	# Cutter replaced comes home as a carried thing like any other.
	assert_eq(_mounted_count(run.layout) + _carried_part_count(run) + sold.size(), parts_before,
		"mounted + carried + sold equals the parts before the swap")
	assert_true(run.inventory.has(&"dozer"), "the Dozer the Cutter replaced is carried")
	assert_eq(run.inventory.free_slots(), 0, "and it took the slot the Cutter left")
	var gained := 0
	for id in sold:
		gained += ChPrices.sell_value(catalog.part(id).rarity)
	assert_eq(run.gold, gold_before - 2 + gained, "gold rose by the sum of the sell values (%d)" % gained)
	_complete()


func test_body_swap_overflow_fills_free_slots_first() -> void:
	# The other half of the overflow rule: what a swap detaches goes into the inventory until it is
	# full, and only the rest is sold. test_body_swap_overflow_sold ends with no free slot, so it
	# cannot see that order at all: always selling passes every assert there.
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var catalog: ChCatalog = phase.catalog
	run.layout.swap_body(catalog.body(&"dozer"), catalog)
	_mount_all_slots(run, &"roller")
	var mounted_before := _mounted_count(run.layout)
	assert_eq(mounted_before, 6, "the Dozer build fills all six top-level slots")
	# Three carried parts leave two free slots; the bought Cutter takes one, so the swap (Cutter out,
	# Dozer home) still has the one slot that holds exactly one of the two detached subtrees.
	for id in [&"strut", &"igniter", &"molotov"]:
		assert_true(run.inventory.add(id), "carry %s" % id)
	var carried_before := run.inventory.part_ids.size()
	assert_eq(run.inventory.free_slots(), 2, "two slots are free")
	phase.items = [{"id": &"cutter", "is_body": true, "rarity": &"common", "price": 2, "taken": false}]
	run.gold = 2
	var gold_before := run.gold
	assert_true(phase.buy(0), "the Cutter is bought")
	assert_eq(run.inventory.free_slots(), 1, "and carried, leaving one slot free")
	assert_true(phase.equip_body(run.inventory.part_ids.find(&"cutter")), "the Cutter goes on")
	assert_eq(run.layout.body_id, &"cutter", "and it is swapped in")
	var sold: Array[StringName] = phase.auto_sold.duplicate()
	assert_eq(sold.size(), 1, "only the overflow the inventory had no room for is sold")
	assert_eq(_carried_part_count(run), carried_before + 1, "the free slot filled from the overflow")
	assert_eq(run.inventory.free_slots(), 0, "and the inventory is full again")
	# The split is read as counts, not by asking has(): both overflow subtrees are Wheels here, so the
	# sold id is also a carried id, and ChInventory.has answers presence rather than count.
	for id in sold:
		assert_true(catalog.part(id) != null, "%s is an id the catalog can price" % id)
	var gained := 0
	for id in sold:
		gained += ChPrices.sell_value(catalog.part(id).rarity)
	assert_eq(run.gold, gold_before - 2 + gained, "gold rose by the sell value of what was sold")
	assert_eq(_mounted_count(run.layout) + _carried_part_count(run) + sold.size(),
		mounted_before + carried_before,
		"mounted + carried + sold equals the parts before the swap")
	_complete()


func test_auto_sold_keeps_every_swap_in_the_stage() -> void:
	# The Task 12 screen reads auto_sold after a body swap to beat the parts it sold, so the list has to
	# hold every swap the stage made, not just the last one, and start empty for the next stage. Two
	# swaps in one stage is legal: each body is bought into a free slot and then equipped.
	var phase := _shop_phase()
	var run: ChRun = phase.run
	var catalog: ChCatalog = phase.catalog
	# Corsair (7 slots) then Dozer (6) then Cutter (4): each swap detaches subtrees that find no seat,
	# so both swaps sell parts and both piles have to be readable.
	run.layout.swap_body(catalog.body(&"corsair"), catalog)
	_mount_all_slots(run, &"roller")
	var mounted_before := _mounted_count(run.layout)
	assert_eq(mounted_before, 7, "the Corsair build fills all seven top-level slots")
	# Four carried parts leave the one slot the first body takes; the Corsair it replaces fills the kit
	# again, which is why the second body needs a sale first.
	for i in ChInventory.CAPACITY - 1:
		assert_true(run.inventory.add(&"strut"), "carry %d" % i)
	phase.items = [
		{"id": &"dozer", "is_body": true, "rarity": &"uncommon", "price": 6, "taken": false},
		{"id": &"cutter", "is_body": true, "rarity": &"common", "price": 2, "taken": false},
	]
	var parts_before := mounted_before + ChInventory.CAPACITY - 1  # the Corsair's mount plus four Struts
	run.gold = 20
	var gold_before := run.gold
	assert_true(phase.buy(0), "the first body is bought")
	assert_true(phase.equip_body(run.inventory.part_ids.find(&"dozer")), "and swapped in")
	var first_sold: Array[StringName] = phase.auto_sold.duplicate()
	assert_eq(first_sold.size(), 1, "one Corsair subtree found no seat on the Dozer")
	assert_eq(phase.sell(0), 1, "a carried common sold frees a slot for the second body")
	assert_true(phase.buy(1), "a second body in the same stage is allowed")
	assert_true(phase.equip_body(run.inventory.part_ids.find(&"cutter")), "and swapped in too")
	var sold: Array[StringName] = phase.auto_sold.duplicate()
	assert_eq(sold.size(), 3, "both swaps' overflow is listed, 1 + 2")
	for id in first_sold:
		assert_true(sold.has(id), "the first swap's %s is still listed after the second swap" % id)
	var gained := 0
	for id in sold:
		gained += ChPrices.sell_value(catalog.part(id).rarity)
	assert_eq(run.gold, gold_before - 6 - 2 + 1 + gained, "gold rose by both sell values and the Strut")
	assert_eq(_mounted_count(run.layout) + _carried_part_count(run) + sold.size(),
		parts_before - 1, "nothing the build held disappeared; the sold Strut is the one part gone")
	assert_true(run.inventory.has(&"corsair") and run.inventory.has(&"dozer"),
		"both replaced bodies are carried")
	phase.next()
	assert_eq(phase.auto_sold.size(), 0, "Next empties the list for the next stage")
	_complete()


func _carried_part_count(run: ChRun) -> int:
	# The carried PART ids, so a carried body is not counted as a part: the overflow ledger and the
	# bodies the swaps hand back are different kinds of thing, and only parts were in the build.
	var total := 0
	for id in run.inventory.part_ids:
		if run.catalog.part(id) != null:
			total += 1
	return total


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
