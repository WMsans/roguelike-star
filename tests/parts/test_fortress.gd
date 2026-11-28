extends ChPartTest

# Task 13: the Fortress parts (U25-U30, R12-R14) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# Block, Speedup and Slow are the three statuses a part may put on directly, so every assertion here
# reads ChPartRuntime.statuses / ChChariotRuntime.statuses. The Bunker Frame's run-level slot and the
# Shield Battery's own and two-battery loops are the named review tests.

# U25: deal damage equal to the body's Block.
func test_spiked_shield_damage_equals_body_block() -> void:
	var ctx := await duel([[[7], &"spiked_shield"]], [], 20.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	ctx.give_status(ctx.chariots[0], ChStatuses.BLOCK, 25)
	var before := foe.hp
	await step(ctx, 6.1)
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 25, "the shield deals its body's 25 Block")
	_complete()


# U26: a neighbour that gains Block gains 3 more.
func test_shield_battery_3_more_block_on_a_neighbour() -> void:
	var ctx := await duel([[[6], &"shield_battery"], [[7], &"reinforced_frame"]])
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(neighbour != null, "the neighbour mounted")
	ctx.give_status(neighbour, ChStatuses.BLOCK, 10)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 13, "the neighbour's 10 Block gains 3 more")
	_complete()


# Review Focus 4: the battery's own top-up is not a gain it answers, so a gain of 10 ends at 13 and
# the loop stops. Ten fight seconds must also run rather than hang.
func test_shield_battery_does_not_feed_itself() -> void:
	var ctx := await duel([[[6], &"shield_battery"], [[7], &"reinforced_frame"]])
	var neighbour := of(ctx, 0, &"reinforced_frame")
	ctx.give_status(neighbour, ChStatuses.BLOCK, 10)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 13, "a gain of 10 ends at 13")
	await step(ctx, 10.0)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 13, "and the extra 3 never feeds back")
	assert_near(ctx.time, 10.0, 0.05, "ten seconds of fight ran")
	_complete()


# Review Focus 4, two batteries: duplicates are sellable and both sit in range of one neighbour, so
# each top-up must be a gain the other Battery does not answer. A gain of 10 takes 3 from each of the
# two and stops there; a chain left open runs to the bus's 256-delivery cap (about +380).
func test_two_shield_batteries_do_not_feed_each_other() -> void:
	var ctx := await duel([[[5], &"shield_battery"], [[6], &"reinforced_frame"],
		[[7], &"shield_battery"]])
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(neighbour != null, "the neighbour mounted")
	ctx.give_status(neighbour, ChStatuses.BLOCK, 10)
	assert_true(not ctx.bus.capped, "the two batteries do not open a chain the bus has to cap")
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 16,
		"the 10 gains 3 from each battery and the chain stops")
	await step(ctx, 10.0)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 16, "and the two top-ups never feed back")
	_complete()


# U27: this part and every neighbour gain 15 Block.
func test_rampart_15_block_to_itself_and_neighbours() -> void:
	var ctx := await duel([[[6], &"rampart"], [[7], &"reinforced_frame"]])
	var rampart := of(ctx, 0, &"rampart")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(rampart != null and neighbour != null, "the rampart and its neighbour mounted")
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_eq(rampart.statuses.count(ChStatuses.BLOCK), 15, "the rampart gains 15")
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 15, "and the neighbour gains 15")
	_complete()


# U28: 30 Block on the body as the battle opens. Its +1 inventory slot lives in test_run_stats.
func test_bunker_frame_30_block_at_start() -> void:
	var ctx := await duel([[[6], &"bunker_frame"]])
	await step(ctx, TICK)
	assert_eq(ctx.chariots[0].statuses.count(ChStatuses.BLOCK), 30, "the body gains 30 Block")
	_complete()


# U29: every 5 seconds the body gains 10% of its Block, at least 5.
func test_compound_plating_10_percent_with_a_5_floor() -> void:
	var ctx := await duel([[[6], &"compound_plating"]])
	var body: ChChariotRuntime = ctx.chariots[0]
	ctx.give_status(body, ChStatuses.BLOCK, 100)
	await step(ctx, 5.1)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), 110, "100 Block gains 10 more")
	var low := await duel([[[6], &"compound_plating"]])
	var low_body: ChChariotRuntime = low.chariots[0]
	low.give_status(low_body, ChStatuses.BLOCK, 40)
	await step(low, 5.1)
	assert_eq(low_body.statuses.count(ChStatuses.BLOCK), 45, "40 Block gains the 5 minimum")
	_complete()


# U30: when this part gains Block, each neighbouring weapon spawns 1 more fire cell per hit.
func test_thermal_plating_fire_cells_per_hit() -> void:
	var ctx := await duel([[[6], &"thermal_plating"], [[7], &"minigun"]],
		[[[6], &"reinforced_frame"]], 20.0)
	var plating := of(ctx, 0, &"thermal_plating")
	var gun := of(ctx, 0, &"minigun")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(plating != null and gun != null and foe != null, "both parts and the target mounted")
	ctx.give_status(plating, ChStatuses.BLOCK, 5)
	assert_eq(gun.fire_cells_per_hit, 1, "the neighbouring weapon adds 1 fire cell per hit")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	ctx.deal_hit(gun, foe.body, 10)
	var fire: Array = []
	for event in spawns:
		if event.data.get("material") == &"fire":
			fire.append(event)
	assert_eq(fire.size(), 1, "the hit spawns fire")
	assert_eq(int(fire[0].data["count"]), 1, "one fire cell")
	assert_true(Vector2(fire[0].data["at"]).distance_to(foe.anchor_world()) < 1.0,
		"at the part hit")
	_complete()


# R12: your body gains Block equal to its current HP.
func test_aegis_mirror_block_equals_hp() -> void:
	var ctx := await duel([[[6], &"aegis_mirror"]])
	var body: ChChariotRuntime = ctx.chariots[0]
	await step(ctx, 20.1)
	var hp := body.hp
	await step(ctx, TICK, true)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), hp, "the body gains Block equal to its HP")
	_complete()


# R13: every 10 seconds, if the body's Block is greater than its HP, every own part gains 10 Speedup.
func test_iron_will_10_speedup_when_block_beats_hp() -> void:
	var ctx := await duel([[[6], &"iron_will"], [[7], &"spare_cell"]])
	var body: ChChariotRuntime = ctx.chariots[0]
	ctx.give_status(body, ChStatuses.BLOCK, body.hp + 1)
	await step(ctx, 10.1)
	assert_eq(of(ctx, 0, &"iron_will").statuses.count(ChStatuses.SPEEDUP), 10,
		"the Iron Will gains 10 Speedup")
	assert_eq(of(ctx, 0, &"spare_cell").statuses.count(ChStatuses.SPEEDUP), 10,
		"so does every own part")
	assert_eq(of(ctx, 0, WHEEL_ID).statuses.count(ChStatuses.SPEEDUP), 10, "the wheels too")
	_complete()


# R14: damage to any own part spends the body's Block first.
func test_citadel_soaks_with_the_body_block() -> void:
	var ctx := await duel([[[6], &"citadel"], [[7], &"reinforced_frame"]])
	var body: ChChariotRuntime = ctx.chariots[0]
	var frame := of(ctx, 0, &"reinforced_frame")
	assert_true(frame != null, "the frame mounted")
	ctx.give_status(body, ChStatuses.BLOCK, 100)
	var integrity := frame.integrity
	ctx.deal_hit(of(ctx, 1, WHEEL_ID), frame.body, 30)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), 70, "the 30 spends the body's Block")
	assert_eq(frame.integrity, integrity, "and the part takes no wear behind it")
	_complete()
