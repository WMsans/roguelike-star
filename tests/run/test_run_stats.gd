extends ChTest

# Task 13: run-level stats through ChRun. The Bunker Frame carries +1 inventory slot, mounted or
# carried, and every shop action that changes what the run owns refreshes the capacity.


func _run() -> ChRun:
	return ChRun.start(7, ChCatalog.load_default())


func test_bunker_frame_adds_a_slot_mounted_or_carried() -> void:
	var run := _run()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY, "a run starts with five slots")
	assert_true(run.inventory.add(&"bunker_frame"), "the frame is carried")
	run.refresh_capacity()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY + 1, "a carried frame adds a slot")
	assert_true(run.inventory.take(&"bunker_frame"), "the frame is lifted")
	var body: ChBodyDef = run.catalog.body(run.layout.body_id)
	var mounted := false
	for slot in body.slots.size():
		if run.layout.place([slot], &"bunker_frame"):
			mounted = true
			break
	assert_true(mounted, "and mounted in a free slot")
	run.refresh_capacity()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY + 1, "a mounted frame adds the same one")
	assert_eq(run.run_stat(&"inventory_capacity", ChInventory.CAPACITY), ChInventory.CAPACITY + 1,
		"the run stat folds to six")
	_complete()


func test_capacity_refreshes_after_buy_take_and_sell() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	run.gold = 20
	var phase := ChShopPhase.new(run, catalog)
	phase.picked = {&"kind": &"shop"}
	phase.items = [{"id": &"bunker_frame", "is_body": false, "rarity": &"uncommon",
		"price": 6, "taken": false}]
	assert_true(phase.buy(0), "the frame is bought")
	assert_eq(run.inventory.capacity, 6, "and the slot arrives as it lands")
	var pack := ChShopPhase.new(run, catalog)
	pack.picked = {&"kind": &"pack"}
	pack.items = [{"id": &"bunker_frame", "is_body": false, "rarity": &"uncommon",
		"price": 6, "taken": false}]
	assert_true(pack.take(0), "a second frame is taken from a pack")
	assert_eq(run.inventory.capacity, 7, "and a second slot arrives")
	# Fill the seven slots, then sell one frame: the sold part leaves first, so the remaining six still
	# fit the five-base capacity plus the one frame still carried.
	var sell_phase := ChShopPhase.new(run, catalog)
	for i in run.inventory.free_slots():
		assert_true(run.inventory.add(&"roller"), "filler %d" % i)
	assert_eq(run.inventory.free_slots(), 0, "the inventory is full")
	assert_eq(sell_phase.sell(0), 3, "selling the carried uncommon frame pays 3")
	assert_eq(run.inventory.part_ids.size(), 6, "six parts stay carried")
	assert_eq(run.inventory.capacity, 6, "and the remaining frame's slot still fits them")
	_complete()
