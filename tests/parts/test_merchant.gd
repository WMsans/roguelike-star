extends ChPartTest

# Task 23: the Merchant parts (U64-U68, R29-R30) on the Task 1 RIG and on a real run's layout,
# one test per part, each asserting the number its row in docs/design-doc/parts-list.md gives.
# The run-level half of the task (instance state, sell counters) is tests/run/test_run_state.gd.
# The weapons fire a projectile, so those tests step engine frames; the passives are pure clock.
# A battle built here goes through ChRun.player_layout() and the chariot builder, so the bench and
# the two counts (inventory_count, parts_sold) are read down the same path the main loop uses.

# A run on the slice's catalog, with the Cutter's one spare top slot for the part under test.
func _run() -> ChRun:
	return ChRun.start(7, ChCatalog.load_default())


# A rock floor and a battle context: the run's own player layout on side 0, and an optional enemy
# layout on side 1. setup_all is the single place behaviours and the bench are set up.
func _context(run: ChRun, world: PixelWorld, enemy: ChChariotLayout = null) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = run.catalog
	var rigs: Array[ChChariotRuntime] = []
	var player := ChChariotBuilder.build(world, _parent(), run.player_layout(), run.catalog,
		0, Vector2(160, 140), false)
	assert_true(player != null, "the player's chariot builds")
	rigs.append(player)
	if enemy != null:
		var foe := ChChariotBuilder.build(world, _parent(), enemy, run.catalog, 1,
			Vector2(400, 140), true)
		assert_true(foe != null, "the enemy's chariot builds")
		rigs.append(foe)
	ctx.chariots = rigs
	ctx.setup_all()
	return ctx


func _floor() -> PixelWorld:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	return world


# An enemy Cutter with wheels on the same low slots as the player's: both hulls settle at the same
# height, so a straight shot along the player's spare top slot meets the frame on the same slot.
func _wheeled_enemy() -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = &"cutter"
	layout.place(_typed_path([0]), WHEEL_ID)
	layout.place(_typed_path([1]), WHEEL_ID)
	layout.place(_typed_path([2]), &"reinforced_frame")
	return layout


# U64: when you win a battle, this gains +1 sell value.
func test_piggy_bank_1_sell_value_per_win() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	assert_true(run.inventory.add(&"piggy_bank"), "the bank is carried")
	var at := run.inventory.part_ids.find(&"piggy_bank")
	run.announce(&"won", {&"kind": &"normal"})
	assert_eq(int(run.inventory.states[at].get(&"sell_bonus", 0)), 1,
		"a normal win gives +1 sell value")
	run.announce(&"won", {&"kind": &"elite"})
	assert_eq(int(run.inventory.states[at].get(&"sell_bonus", 0)), 2,
		"an elite win gives another")
	var phase := ChShopPhase.new(run, catalog)
	var gold := run.gold
	assert_eq(phase.sell(at), ChPrices.sell_value(&"uncommon") + 2,
		"selling pays the uncommon 3 plus the banked 2")
	assert_eq(run.gold, gold + ChPrices.sell_value(&"uncommon") + 2,
		"and the state's 2 is paid with it")
	_complete()


# U65: 30 damage, +10 saved from a sale, and each sale of another part gives +5 permanently.
func test_scrap_cannon_30_damage_plus_5_per_sale() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	assert_true(run.layout.place(_typed_path([3]), &"scrap_cannon", {&"damage_bonus": 10}),
		"the cannon mounts with 10 saved damage")
	var world := await _floor()
	var ctx := _context(run, world, _wheeled_enemy())
	var cannon := of(ctx, 0, &"scrap_cannon")
	assert_true(cannon != null, "the cannon is in the fight")
	assert_eq(cannon.def.damage, 30, "the row's 30 damage")
	assert_eq(cannon.bonus_damage, 10, "the saved +10 reaches the battle at setup")
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 5.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 3.0, false, false, 0.0, true)
	assert_eq(before - foe.hp, 40, "30 damage plus the saved 10")
	_free_tracked()

	# The sale half: a sale of another part is what the run announces to the cannon.
	var sale_run := _run()
	assert_true(sale_run.layout.place(_typed_path([3]), &"scrap_cannon"), "the cannon mounts")
	assert_true(sale_run.inventory.add(&"strut"), "something to sell is carried")
	var phase := ChShopPhase.new(sale_run, sale_run.catalog)
	assert_eq(phase.sell(0), ChPrices.sell_value(&"common"), "the strut sells for 1")
	var node: ChSlotNode = sale_run.layout.get_node(_typed_path([3]))
	assert_eq(int(node.state.get(&"damage_bonus", 0)), 5, "the sale gives +5 damage")
	assert_true(sale_run.inventory.add(&"strut"), "a second part is carried")
	phase.sell(0)
	assert_eq(int(node.state.get(&"damage_bonus", 0)), 10, "and a second sale another 5")
	_complete()


# U66: +1 inventory slot, and 3 gold when it is sold.
func test_safe_1_slot_and_3_gold_on_sale() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	assert_true(run.inventory.add(&"safe"), "the safe is carried")
	run.refresh_capacity()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY + 1, "the safe adds a slot")
	assert_eq(run.run_stat(ChRun.STAT_INVENTORY_CAPACITY, ChInventory.CAPACITY),
		ChInventory.CAPACITY + 1, "folded through the run stat")
	var phase := ChShopPhase.new(run, catalog)
	var gold := run.gold
	assert_eq(phase.sell(0), ChPrices.sell_value(&"uncommon"),
		"the safe sells for the uncommon 3")
	assert_eq(run.gold, gold + ChPrices.sell_value(&"uncommon") + 3,
		"and its own sale adds the row's 3 gold")
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY, "the slot leaves with it")
	_complete()


# U67: the first reroll in each shop phase is free.
func test_trade_in_coupon_free_first_reroll() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	assert_true(run.inventory.add(&"trade_in_coupon"), "the coupon is carried")
	assert_eq(run.run_stat(ChRun.STAT_REROLL_PRICE, ChPrices.REROLL), 0,
		"the first reroll prices at 0")
	var phase := ChShopPhase.new(run, catalog)
	phase.picked = {&"kind": &"shop", &"theme": &"weapon"}
	run.gold = 0
	assert_true(phase.reroll(), "a free reroll needs no gold")
	assert_eq(run.gold, 0, "and charges nothing")
	assert_eq(run.rerolls_this_shop, 1, "the shop counts it")
	phase.next()
	phase.picked = {&"kind": &"shop", &"theme": &"weapon"}
	run.gold = ChPrices.REROLL
	assert_eq(run.run_stat(ChRun.STAT_REROLL_PRICE, ChPrices.REROLL), ChPrices.REROLL,
		"the second reroll of the shop prices at 3")
	assert_true(phase.reroll(), "and it is allowed at 3 gold")
	assert_eq(run.gold, 0, "the 3 is charged")
	_complete()


# U68: +1 inventory slot, and 10 Block for each part carried when the battle opens.
func test_collectors_shelf_10_block_per_carried_part() -> void:
	var run := _run()
	assert_true(run.layout.place(_typed_path([3]), &"collectors_shelf"), "the shelf mounts")
	assert_true(run.inventory.add(&"strut"), "one part is carried")
	assert_true(run.inventory.add(&"roller"), "and another")
	run.refresh_capacity()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY + 1, "the shelf adds a slot")
	var world := await _floor()
	var ctx := _context(run, world)
	assert_eq(ctx.chariots[0].inventory_count, 2, "the count reaches the battle")
	await step(ctx, TICK)
	assert_eq(ctx.chariots[0].statuses.count(ChStatuses.BLOCK), 20,
		"10 Block for each of the two carried parts")
	_complete()


# R29: 20 damage, +10 for every part sold this run.
func test_golden_gear_20_plus_10_per_part_sold() -> void:
	var run := _run()
	assert_true(run.layout.place(_typed_path([3]), &"golden_gear"), "the gear mounts")
	run.parts_sold = 3
	var world := await _floor()
	var ctx := _context(run, world, _wheeled_enemy())
	var gear := of(ctx, 0, &"golden_gear")
	assert_true(gear != null, "the gear is in the fight")
	assert_eq(gear.def.damage, 20, "the row's 20 damage")
	assert_eq(ctx.chariots[0].parts_sold, 3, "the run's 3 sales reach the battle")
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 5.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 3.0, false, false, 0.0, true)
	assert_eq(before - foe.hp, 50, "20 damage plus 10 for each of the 3 parts sold")
	_complete()


# R30: +1 inventory slot, and the passives carried in the inventory work in battle.
func test_bench_warmer_spare_cell_counts() -> void:
	var run := _run()
	assert_true(run.inventory.add(&"bench_warmer"), "the warmer is carried")
	run.refresh_capacity()
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY + 1, "the warmer adds a slot")
	assert_true(run.inventory.add(&"spare_cell"), "a spare cell is carried too")
	var world := await _floor()
	var ctx := _context(run, world)
	var chariot: ChChariotRuntime = ctx.chariots[0]
	assert_eq(chariot.bench.size(), 2, "both carried passives are benched")
	assert_eq(chariot.energy.cap, 18 + 5, "the benched spare cell's 5 capacity lands")
	_complete()


# Review Focus 4: the bench cannot open a loop the bus has to cap, and ten fight seconds run.
func test_bench_warmer_loop_ends() -> void:
	var run := _run()
	assert_true(run.layout.place(_typed_path([3]), &"bench_warmer"), "the warmer mounts")
	for id in [&"shield_battery", &"shield_battery", &"plating_rig", &"plating_rig"]:
		assert_true(run.inventory.add(id), "%s is carried" % id)
	var world := await _floor()
	var ctx := _context(run, world)
	var chariot: ChChariotRuntime = ctx.chariots[0]
	assert_eq(chariot.bench.size(), 4, "the four carried passives are benched")
	# A Block gain on a benched part would be a neighbour's gain if the bench were near: the two
	# batteries must not answer it, so it stays at 10 rather than climbing.
	ctx.give_status(chariot.bench[0], ChStatuses.BLOCK, 10)
	await step(ctx, 10.0)
	assert_near(ctx.time, 10.0, 0.05, "ten seconds of fight ran")
	assert_eq(chariot.bench[0].statuses.count(ChStatuses.BLOCK), 10,
		"the benched batteries add nothing to a benched neighbour")
	assert_true(not ctx.bus.capped, "no bench loop reaches the bus cap")
	_complete()
