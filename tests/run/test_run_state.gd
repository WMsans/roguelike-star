extends ChTest

# Task 23: the run half of the Merchant. A part's instance state has to survive every move the
# garage, the bar, a body swap and the shop make, the run events have to reach every owned entry,
# and the two counters (parts_sold, rerolls_this_shop) have to be what the shop and the battle read.
# The battle tests that read inventory_count/parts_sold live in tests/parts/test_merchant.gd.

func _catalog() -> ChCatalog:
	return ChCatalog.load_default()


func _run() -> ChRun:
	return ChRun.start(7, _catalog())


func _path_of(layout: ChChariotLayout, id: StringName) -> Array[int]:
	# The mounted path of an id, as a typed path: all_paths hands back untyped indices.
	for path in layout.all_paths():
		var steps := _typed_path(path)
		if layout.get_node(steps).part_id == id:
			return steps
	return []


# A Scrap Cannon with 10 saved damage goes inventory -> slot -> inventory -> body swap -> inventory
# and still has 10: the state is a move, not a per-slot decoration.
func test_state_travels_inventory_slot_inventory() -> void:
	var catalog := _catalog()
	var run := ChRun.start(7, catalog)
	assert_true(run.inventory.add(&"scrap_cannon", {&"damage_bonus": 10}),
		"the cannon is carried with its state")
	var garage := ChGarage.new()
	garage.setup(run.inventory, run.layout, catalog)
	var path := _typed_path([3])
	assert_true(garage.drop_part(&"scrap_cannon", path), "it mounts from the inventory")
	assert_eq(int(run.layout.get_node(path).state.get(&"damage_bonus", 0)), 10,
		"the slot holds the state")
	assert_true(garage.lift(path), "and comes back off the hull")
	assert_eq(int(run.inventory.states[0].get(&"damage_bonus", 0)), 10,
		"the inventory entry has it again")
	assert_true(garage.mount_from_inventory(0, path), "the bar mounts it by index")
	assert_true(run.layout.swap_body(catalog.body(&"dozer"), catalog).is_empty(),
		"the body swap reseats every subtree")
	var moved := _path_of(run.layout, &"scrap_cannon")
	assert_true(not moved.is_empty(), "the cannon is mounted on the new body")
	assert_eq(int(run.layout.get_node(moved).state.get(&"damage_bonus", 0)), 10,
		"the state crossed the body change")
	assert_true(garage.lift(moved), "and the branch comes off the new body")
	assert_eq(int(run.inventory.states[0].get(&"damage_bonus", 0)), 10,
		"still 10 after the whole round trip")
	garage.free()
	_complete()


# subtree_entries carries each node's state, subtree_part_ids stays the id wrapper, and mirrored()
# deep-copies state so an enemy build cannot write back into the player's.
func test_subtree_entries_and_mirror_carry_state() -> void:
	var layout := ChChariotLayout.new()
	layout.body_id = &"cutter"
	assert_true(layout.place(_typed_path([1]), &"strut", {&"mark": 1}), "the strut mounts")
	assert_true(layout.place(_typed_path([1, 0]), &"roller", {&"mark": 2}), "with a wheel on it")
	var entries := layout.subtree_entries(layout.get_node(_typed_path([1])))
	assert_eq(entries.size(), 2, "parent before child")
	assert_eq(entries[0][&"id"], &"strut", "the parent first")
	assert_eq(entries[1][&"id"], &"roller", "then the child")
	assert_eq(int(entries[1][&"state"][&"mark"]), 2, "each entry carries its own state")
	assert_eq(layout.subtree_part_ids(layout.get_node(_typed_path([1]))), [&"strut", &"roller"],
		"the id wrapper answers the same walk")
	var copy := layout.mirrored()
	copy.get_node(_typed_path([1])).state[&"mark"] = 9
	assert_eq(int(layout.get_node(_typed_path([1])).state[&"mark"]), 1,
		"mirrored deep-copies state")
	_complete()


# Every owned entry hears a run event: mounted first, then carried, each with its own state.
func test_announce_reaches_mounted_and_carried() -> void:
	var run := _run()
	# The Cutter's start kit leaves slot 3 free; one Piggy Bank sits there and another is carried.
	assert_true(run.layout.place(_typed_path([3]), &"piggy_bank"), "one bank mounts")
	assert_true(run.inventory.add(&"piggy_bank"), "another is carried")
	run.announce(&"won", {&"kind": &"normal"})
	assert_eq(int(run.layout.get_node(_typed_path([3])).state.get(&"sell_bonus", 0)), 1,
		"the mounted bank hears the win")
	assert_eq(int(run.inventory.states[0].get(&"sell_bonus", 0)), 1,
		"so does the carried one")
	_complete()


# The shop's sell pays the state's sell_bonus and counts the part as sold.
func test_sell_pays_sell_bonus_and_counts_parts_sold() -> void:
	var catalog := _catalog()
	var run := ChRun.start(7, catalog)
	assert_true(run.inventory.add(&"roller", {&"sell_bonus": 2}), "a wheel with 2 extra value")
	var phase := ChShopPhase.new(run, catalog)
	var gold := run.gold
	assert_eq(phase.sell(0), ChPrices.sell_value(&"common") + 2,
		"the sale pays the common 1 plus the state's 2")
	assert_eq(run.gold, gold + ChPrices.sell_value(&"common") + 2, "and the gold lands")
	assert_eq(run.parts_sold, 1, "the sale is counted")
	_complete()


# A body swap's auto-sell counts too: the parts that found no slot are sold by the shop.
func test_auto_sold_counts_parts_sold() -> void:
	var catalog := _catalog()
	var run := ChRun.start(7, catalog)
	run.layout.swap_body(catalog.body(&"dozer"), catalog)
	for slot in catalog.body(&"dozer").slots.size():
		run.layout.place(_typed_path([slot]), &"roller")
	for i in ChInventory.CAPACITY:
		assert_true(run.inventory.add(&"strut"), "the inventory carries %d" % i)
	var phase := ChShopPhase.new(run, catalog)
	phase.picked = {&"kind": &"shop"}
	phase.items = [{"id": &"cutter", "is_body": true, "rarity": &"common",
		"price": 2, "taken": false}]
	run.gold = 2
	assert_true(phase.buy(0), "the Cutter is swapped in over a full Dozer build")
	assert_eq(phase.auto_sold.size(), 2, "two subtrees found no seat")
	assert_eq(run.parts_sold, phase.auto_sold.size(),
		"each auto-sold part is counted in parts_sold")
	_complete()


# rerolls_this_shop is the per-shop counter the Trade-In Coupon reads: the phase resets it.
func test_rerolls_counter_resets_each_shop() -> void:
	var catalog := _catalog()
	var run := ChRun.start(7, catalog)
	run.rerolls_this_shop = 4
	var phase := ChShopPhase.new(run, catalog)
	assert_eq(run.rerolls_this_shop, 0, "opening a shop resets the counter")
	phase.picked = {&"kind": &"shop", &"theme": &"weapon"}
	run.gold = ChPrices.REROLL
	assert_true(phase.reroll(), "the first reroll is allowed")
	assert_eq(run.rerolls_this_shop, 1, "and counted")
	assert_eq(run.gold, 0, "at the base price")
	_complete()
