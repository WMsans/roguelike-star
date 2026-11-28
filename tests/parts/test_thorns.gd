extends ChPartTest

# Task 14: the Thorns parts (U82-U85, R35-R36) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# Every part here is passive and reacts to an event, so the tests deal the trigger hit directly with
# ctx.deal_hit rather than waiting for a volley. The two Retribution chariots are the named Review
# Focus 4 loop test: ten fight seconds must run and the ping-pong must not hang.

# The HIT events `source` dealt, in delivery order.
func _paid(hits: Array, source: Object) -> Array:
	var out: Array = []
	for hit in hits:
		if hit.source == source:
			out.append(hit)
	return out


# U82: a hit on this part deals 15 back to the attacking part.
func test_spiked_armour_deals_15_back() -> void:
	var ctx := await duel([[[0], &"spiked_armour"]], [[[0], &"reinforced_frame"]], 20.0)
	var armour := of(ctx, 0, &"spiked_armour")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(armour != null and foe != null, "both parts mounted")
	var hits := sink(ctx, ChEvent.HIT)
	ctx.deal_hit(foe, armour.body, 10)
	var paid := _paid(hits, armour)
	assert_eq(paid.size(), 1, "the armour pays the hit back once")
	assert_eq(int(paid[0].data["hp_damage"]), 15, "it deals 15 to the attacking part")
	assert_true(paid[0].data["target_part"] == foe, "and it lands on that part")
	_complete()


# U83: when Block on this part absorbs a hit, neighbouring weapons gain 1 Speedup.
func test_reactive_plate_speeds_up_neighbouring_weapons() -> void:
	var ctx := await duel([[[0], &"reactive_plate"], [[1], &"minigun"]],
		[[[0], &"reinforced_frame"]], 20.0)
	var plate := of(ctx, 0, &"reactive_plate")
	var gun := of(ctx, 0, &"minigun")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(plate != null and gun != null and foe != null, "the plate, its neighbour and a foe")
	ctx.give_status(plate, ChStatuses.BLOCK, 10)
	ctx.deal_hit(foe, plate.body, 4)
	assert_eq(plate.statuses.count(ChStatuses.BLOCK), 6, "the plate's Block absorbed the 4")
	assert_eq(gun.statuses.count(ChStatuses.SPEEDUP), 1, "the neighbouring weapon gains 1 Speedup")
	_complete()


# U84: a hit on this part throws sparks at the attacking part.
func test_shock_plate_throws_sparks_at_the_attacker() -> void:
	var ctx := await duel([[[0], &"shock_plate"]], [[[0], &"reinforced_frame"]], 20.0)
	var plate := of(ctx, 0, &"shock_plate")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(plate != null and foe != null, "both parts mounted")
	ctx.deal_hit(foe, plate.body, 10)
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "the sparks shocked the attacking part")
	_complete()


# U85: when Block on a neighbour reaches 0, deal 30 damage to the attacking part.
func test_mirror_plating_deals_30_when_a_neighbours_block_reaches_0() -> void:
	var ctx := await duel([[[0], &"mirror_plating"], [[1], &"reinforced_frame"]],
		[[[0], &"reinforced_frame"]], 20.0)
	var mirror := of(ctx, 0, &"mirror_plating")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(mirror != null and neighbour != null and foe != null, "the parts mounted")
	ctx.give_status(neighbour, ChStatuses.BLOCK, 5)
	var hits := sink(ctx, ChEvent.HIT)
	ctx.deal_hit(foe, neighbour.body, 5)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 0, "the neighbour's Block reaches 0")
	var paid := _paid(hits, mirror)
	assert_eq(paid.size(), 1, "the mirror pays the break once")
	assert_eq(int(paid[0].data["hp_damage"]), 30, "it deals 30 to the attacking part")
	assert_true(paid[0].data["target_part"] == foe, "and it lands on that part")
	_complete()


# R35: Block that absorbs damage on any of your parts pays that much back to the attacker.
func test_retribution_deals_the_block_it_absorbed() -> void:
	var ctx := await duel([[[0], &"retribution"], [[1], &"reinforced_frame"]],
		[[[0], &"reinforced_frame"]], 20.0)
	var retribution := of(ctx, 0, &"retribution")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(retribution != null and neighbour != null and foe != null, "the parts mounted")
	var hits := sink(ctx, ChEvent.HIT)
	ctx.give_status(neighbour, ChStatuses.BLOCK, 10)
	ctx.deal_hit(foe, neighbour.body, 4)
	var paid := _paid(hits, retribution)
	assert_eq(paid.size(), 1, "the 4 Block absorbed on the neighbour pays once")
	assert_eq(int(paid[0].data["hp_damage"]), 4, "it deals the 4 it absorbed")
	assert_true(paid[0].data["target_part"] == foe, "to the attacking part")
	# The body's own Block is a holder's too, so it pays the same way.
	ctx.give_status(ctx.chariots[0], ChStatuses.BLOCK, 10)
	ctx.deal_hit(foe, ctx.chariots[0].chassis, 6)
	paid = _paid(hits, retribution)
	assert_eq(paid.size(), 2, "the 6 Block absorbed on the body pays too")
	assert_eq(int(paid[1].data["hp_damage"]), 6, "it deals the 6 it absorbed")
	_complete()


# R36: a hit on a neighbour is taken by this part instead, and it gains Block equal to half.
func test_guardian_core_takes_a_neighbours_hit_and_gains_half_block() -> void:
	var ctx := await duel([[[6], &"guardian_core"], [[7], &"reinforced_frame"]],
		[[[0], &"reinforced_frame"]], 20.0)
	var core := of(ctx, 0, &"guardian_core")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(core != null and neighbour != null and foe != null, "the parts mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var neighbour_integrity := neighbour.integrity
	var core_integrity := core.integrity
	ctx.deal_hit(foe, neighbour.body, 20)
	assert_eq(neighbour.integrity, neighbour_integrity, "the neighbour takes no wear")
	assert_eq(core.integrity, core_integrity - 10, "the core takes the hit instead")
	assert_eq(hits.size(), 1, "one hit landed")
	assert_true(hits[0].data["target_part"] == core, "redirected onto the guardian core")
	assert_eq(core.statuses.count(ChStatuses.BLOCK), 10, "and it gains half the 20 as Block")
	_complete()


# Review Focus 4: two Retribution chariots, every part with 50 Block, shooting each other for 10 s.
# Each paid-back hit is itself absorbed, so the two chariots answer each other until the Block runs
# out; the fight must reach 10 s rather than hang. The two Miniguns are only the attackers here: a
# straight shot at the far rig hits its hull, so the hits that start the loop are dealt directly.
func test_retribution_ping_pong_ends() -> void:
	var ctx := await duel([[[0], &"retribution"], [[1], &"minigun"]],
		[[[0], &"retribution"], [[1], &"minigun"]], 40.0)
	var mine := of(ctx, 0, &"retribution")
	var theirs := of(ctx, 1, &"retribution")
	var my_gun := of(ctx, 0, &"minigun")
	var foe_gun := of(ctx, 1, &"minigun")
	assert_true(mine != null and theirs != null and my_gun != null and foe_gun != null,
		"both chariots carry a Retribution and a Minigun")
	for chariot in ctx.chariots:
		for other in chariot.parts:
			ctx.give_status(other, ChStatuses.BLOCK, 50)
	var hits := sink(ctx, ChEvent.HIT)
	ctx.deal_hit(my_gun, theirs.body, 6)
	ctx.deal_hit(foe_gun, mine.body, 6)
	await step(ctx, 10.0)
	assert_true(ctx.time >= 10.0, "the fight reached 10 s")
	var paid := 0
	for hit in hits:
		if hit.source == mine or hit.source == theirs:
			paid += 1
	assert_true(paid > 0, "the two Retributions paid each other back")
	_complete()
