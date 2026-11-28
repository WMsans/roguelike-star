extends ChPartTest

# Task 15: the Last Stand parts (U78-U81, R34) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives. Emergency Plating gets a second test:
# its would-die hook must fire on a death that comes from a material blast, through lose_hp.

# The hand-made material blast test_hp_energy.gd feeds ChHazards.apply, one TNT crate at its centre.
func _blast(at: Vector2, radius: int) -> Dictionary:
	return {"position": Vector2i(at), "radius": radius, "power": 1.0, "material": &"tnt", "dig": 6}


# U78: the first fall below half gives every own part 5 Speedup, and only the first one.
func test_adrenaline_injector_speeds_up_all_parts_once() -> void:
	var ctx := await duel([[[0], &"adrenaline_injector"], [[1], &"steel_plate"]])
	var injector := of(ctx, 0, &"adrenaline_injector")
	var neighbour := of(ctx, 0, &"steel_plate")
	var player := ctx.chariots[0]
	assert_true(injector != null and neighbour != null, "the injector and its neighbour mounted")
	assert_eq(ctx.lose_hp(player, 100, &"hit"), 100, "the first 100 HP lands")
	assert_eq(player.hp, 700, "still above half")
	assert_eq(injector.statuses.count(ChStatuses.SPEEDUP), 0, "no Speedup while above half")
	assert_eq(ctx.lose_hp(player, 301, &"hit"), 301, "the loss that crosses half lands")
	assert_eq(player.hp, 399, "below half")
	assert_eq(injector.statuses.count(ChStatuses.SPEEDUP), 5, "the injector itself gains 5")
	assert_eq(neighbour.statuses.count(ChStatuses.SPEEDUP), 5, "and its neighbour gains 5")
	ctx.lose_hp(player, 10, &"hit")
	assert_eq(injector.statuses.count(ChStatuses.SPEEDUP), 5, "the first fall below half is the only one")
	_complete()


# U79: the first killing blow leaves 1 HP and gives the body 50 Block, once a battle.
func test_emergency_plating_survives_once_with_50_block() -> void:
	var ctx := await duel([[[0], &"emergency_plating"]])
	var plating := of(ctx, 0, &"emergency_plating")
	var player := ctx.chariots[0]
	assert_true(plating != null, "the plating mounted")
	var heard := sink(ctx, ChEvent.HP_LOST)
	ctx.lose_hp(player, 800, &"hit")
	assert_eq(player.hp, 1, "the killing blow leaves 1 HP")
	assert_eq(player.statuses.count(ChStatuses.BLOCK), 50, "and the body gains 50 Block")
	assert_eq(heard.size(), 1, "one HP_LOST")
	if heard.size() == 1:
		assert_eq(int(heard[0].data["after"]), 1, "the event reports the 1 HP left")
	ctx.lose_hp(player, 800, &"hit")
	assert_eq(player.hp, 0, "the second killing blow kills")
	assert_eq(player.statuses.count(ChStatuses.BLOCK), 50, "with no second save")
	_complete()


# U79: the same save when the fatal damage comes from a material blast, through lose_hp.
func test_emergency_plating_survives_a_blast() -> void:
	var ctx := await duel([[[0], &"emergency_plating"]])
	var plating := of(ctx, 0, &"emergency_plating")
	var player := ctx.chariots[0]
	assert_true(plating != null, "the plating mounted")
	player.hp = 100
	ctx.hazards.apply(ctx, [_blast(player.chassis.global_position, 12)])
	assert_eq(player.hp, 1, "the blast that would kill leaves 1 HP")
	assert_eq(player.statuses.count(ChStatuses.BLOCK), 50, "and the body gains 50 Block")
	_complete()


# U79: the same save when a weapon's hit on the hull is the fatal blow, through deal_hit.
func test_emergency_plating_survives_a_hit() -> void:
	var ctx := await duel([[[0], &"emergency_plating"]], [[[0], &"cannon"]], 20.0)
	var plating := of(ctx, 0, &"emergency_plating")
	var gun := of(ctx, 1, &"cannon")
	var player := ctx.chariots[0]
	assert_true(plating != null and gun != null, "the plating and a weapon mounted")
	player.hp = 100
	ctx.deal_hit(gun, player.chassis, 200)
	assert_eq(player.hp, 1, "the hit that would kill leaves 1 HP")
	assert_eq(player.statuses.count(ChStatuses.BLOCK), 50, "and the body gains 50 Block")
	_complete()


# U80: an own weapon adds 1 damage a hit per 2% of HP missing: 30% off 800 HP is +15.
func test_berserker_chip_adds_1_per_2_percent_missing() -> void:
	var ctx := await duel([[[0], &"berserker_chip"], [[1], &"minigun"]],
		[[[0], &"reinforced_frame"]], 20.0)
	var chip := of(ctx, 0, &"berserker_chip")
	var gun := of(ctx, 0, &"minigun")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(chip != null and gun != null and foe != null, "the chip, a weapon and a foe")
	ctx.chariots[0].hp = 560  # 240 of 800 missing = 30%
	var hits := sink(ctx, ChEvent.HIT)
	ctx.deal_hit(gun, foe.body, 10)
	assert_eq(hits.size(), 1, "the weapon's hit landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 25, "10 + 15 for the 30% missing")
	ctx.deal_hit(chip, foe.body, 10)
	assert_eq(int(hits[1].data["hp_damage"]), 10, "a non-weapon source gets no bonus")
	_complete()


# U81: an own part breaking explodes (medium) where it falls, and its own break counts too.
func test_last_rites_explodes_when_a_part_breaks() -> void:
	var ctx := await duel([[[0], &"last_rites"], [[1], &"reinforced_frame"]])
	var rites := of(ctx, 0, &"last_rites")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(rites != null and neighbour != null, "the rites and its neighbour mounted")
	var booms := sink(ctx, ChEvent.EXPLOSION)
	var at := neighbour.anchor_world()
	ctx.chariots[0].break_part(neighbour, ctx)
	assert_eq(booms.size(), 1, "the neighbour's break explodes once")
	if booms.size() == 1:
		assert_eq(booms[0].data["size"], &"medium", "a medium blast")
		assert_eq(booms[0].data["source"], rites, "sourced by the Last Rites")
		assert_eq(booms[0].position, Vector2(Vector2i(roundi(at.x), roundi(at.y))), "where it falls")
	# break_part takes the behaviour off the bus before its own PART_BROKEN, so this one is teardown's.
	at = rites.anchor_world()
	ctx.chariots[0].break_part(rites, ctx)
	assert_eq(booms.size(), 2, "its own break explodes as well")
	if booms.size() == 2:
		assert_eq(booms[1].data["source"], rites, "sourced by itself")
		assert_eq(booms[1].position, Vector2(Vector2i(roundi(at.x), roundi(at.y))), "where it falls")
	_complete()


# R34: while HP is below half, every own part gains 1 Speedup a second; above half it stops.
func test_death_wish_speeds_up_every_second_below_half() -> void:
	var ctx := await duel([[[0], &"death_wish"], [[1], &"reinforced_frame"]])
	var wish := of(ctx, 0, &"death_wish")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(wish != null and neighbour != null, "the wish and its neighbour mounted")
	ctx.chariots[0].hp = 399
	await step(ctx, 2.5)
	assert_eq(wish.statuses.count(ChStatuses.SPEEDUP), 1, "the wish keeps 1 Speedup on itself")
	assert_eq(neighbour.statuses.count(ChStatuses.SPEEDUP), 1, "and on its neighbour")
	ctx.chariots[0].hp = 800
	await step(ctx, 2.5)
	assert_eq(wish.statuses.count(ChStatuses.SPEEDUP), 0, "above half the Speedup fades")
	assert_eq(neighbour.statuses.count(ChStatuses.SPEEDUP), 0, "and it stops")
	_complete()
