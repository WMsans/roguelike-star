extends ChPartTest

# Task 5: the common defence parts (C11-C15) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# Block, Speedup and Slow are the three statuses a part may put on directly, so every assertion here
# reads ChPartRuntime.statuses / ChChariotRuntime.statuses.

# C11: 40 Block on itself at the start of the battle.
func test_steel_plate_40_block() -> void:
	var ctx := await duel([[[0], &"steel_plate"]])
	await step(ctx, TICK)
	var plate := of(ctx, 0, &"steel_plate")
	assert_true(plate != null, "the steel plate mounted")
	assert_eq(plate.statuses.count(ChStatuses.BLOCK), 40, "the plate starts the battle with 40 Block")
	_complete()


# C12: 30 Block on the body.
func test_shield_generator_30_block() -> void:
	var ctx := await duel([[[0], &"shield_generator"]])
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_eq(ctx.chariots[0].statuses.count(ChStatuses.BLOCK), 30, "the body gains 30 Block")
	_complete()


# C13: 5 Block when this part is hit.
func test_bumper_5_block() -> void:
	var ctx := await duel([[[0], &"bumper"]], [[[0], &"minigun"]], 60.0)
	var bumper := of(ctx, 0, &"bumper")
	var foe := of(ctx, 1, &"minigun")
	assert_true(bumper != null and foe != null, "both parts mounted")
	ctx.deal_hit(foe, bumper.body, 10)
	assert_eq(bumper.statuses.count(ChStatuses.BLOCK), 5, "the bumper gains 5 Block when it is hit")
	_complete()


# C14: 3 Block on the neighbour that fired.
func test_plating_rig_3_block() -> void:
	var ctx := await duel([[[0], &"plating_rig"], [[1], &"minigun"]])
	var gun := of(ctx, 0, &"minigun")
	assert_true(gun != null, "the minigun mounted next to the rig")
	await step(ctx, 0.6)
	await step(ctx, TICK, true)
	assert_eq(gun.statuses.count(ChStatuses.BLOCK), 3, "the neighbour gains 3 Block when it fires")
	_complete()


# C15: 120 HP back, once, the first time the body falls below half.
func test_first_aid_kit_heals_120() -> void:
	var ctx := await duel([[[0], &"first_aid_kit"]])
	var chariot: ChChariotRuntime = ctx.chariots[0]
	var lost := ctx.lose_hp(chariot, 500, &"test")
	assert_eq(lost, 500, "the hit costs 500 HP")
	assert_eq(chariot.hp, 420, "the kit heals 120 of it")
	assert_eq(chariot.energy.value, 16.0, "and pays 4 energy for it")
	_complete()