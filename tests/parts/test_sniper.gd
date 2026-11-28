extends ChPartTest

# Task 18: the Sniper parts (U37-U41, R18-R19) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# The RIG's top slots sit on the hull's top edge, so the tests that want a straight shot to land give
# the enemy a part on its own top slot to meet (the common-weapon tests' rule). The two Railguns are
# the only weapons here; the other five are passives that read the hit a neighbour deals.

# The hp_damage of every hit `source` dealt, in delivery order.
func _paid(hits: Array, source: Object) -> Array:
	var out: Array = []
	for hit in hits:
		if hit.source == source:
			out.append(int(hit.data["hp_damage"]))
	return out


# The STATUS_GAINED events for `status`, in delivery order.
func _gains(gains: Array, status: StringName) -> Array:
	var out: Array = []
	for gain in gains:
		if gain.data.get("status") == status:
			out.append(gain)
	return out


# U37: 220 on the body it meets, from one fast shot.
func test_railgun_220_damage() -> void:
	var ctx := await duel([[[7], &"railgun"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var gun := of(ctx, 0, &"railgun")
	assert_true(gun != null, "the railgun mounted")
	gun.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 10 s
	var before := foe.hp
	# The rigs settle onto their wheels in the first second; fire after that, so the shot's line is
	# the line the enemy part straddles.
	await step(ctx, 1.0, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.0, false, false, 0.0, true)
	assert_eq(before - foe.hp, 220, "the shot pays 220 on the body it meets")
	_complete()


# U38: a beam neighbour's hits get +30 in its first second after switching on, then the base 12.
func test_focus_lens_30_in_the_beam_first_second() -> void:
	var ctx := await duel([[[6], &"focus_lens"], [[7], &"laser"]], [], 60.0)
	var laser := of(ctx, 0, &"laser")
	var lens := of(ctx, 0, &"focus_lens")
	assert_true(laser != null and lens != null, "the lens and its beam neighbour mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 2.3, false, true)
	var paid := _paid(hits, laser)
	assert_true(paid.size() >= 3, "%d beam ticks landed" % paid.size())
	if paid.size() >= 3:
		assert_eq(paid[0], 42, "the switch-on tick is 12 + 30")
		assert_eq(paid[paid.size() - 1], 12, "past the first second it is 12 again")
	_complete()


# U39: a weapon neighbour's hit gets +1 for every 10 cells between the chariots; this gap is 40.
func test_rangefinder_1_a_hit_per_10_cells() -> void:
	var ctx := await duel([[[6], &"rangefinder"], [[7], &"stinger"]], [], 40.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var stinger := of(ctx, 0, &"stinger")
	assert_true(stinger != null, "the weapon neighbour mounted")
	stinger.cooldown_left = 0.0  # a fresh part starts on its full cooldown
	var before := foe.hp
	await step(ctx, TICK, true, false)
	assert_eq(before - foe.hp, 29, "the stab's 25 plus 4 for the 40 cells")
	_complete()


# U40: while standing still, every weapon neighbour gains 1 Speedup every 3 seconds.
func test_stabiliser_speedup_every_3_seconds_while_not_driving() -> void:
	var ctx := await duel([[[6], &"stabiliser"], [[7], &"stinger"]], [], 60.0)
	var stinger := of(ctx, 0, &"stinger")
	assert_true(stinger != null and of(ctx, 0, &"stabiliser") != null,
		"the stabiliser and its weapon neighbour mounted")
	var gains := sink(ctx, ChEvent.STATUS_GAINED)
	await step(ctx, 3.1, false, false, 1.0)  # driving for the whole first period
	assert_eq(_gains(gains, ChStatuses.SPEEDUP).size(), 0, "driving gains nothing")
	await step(ctx, 0.1)  # standing still past the 3 s mark
	var speedups := _gains(gains, ChStatuses.SPEEDUP)
	assert_eq(speedups.size(), 1, "standing still gains once")
	if speedups.size() == 1:
		assert_eq(int(speedups[0].data["amount"]), 1, "1 Speedup")
		assert_true(speedups[0].source == stinger, "to the weapon neighbour")
	_complete()


# U41: the weapon in front deals +50 a hit and takes 3 s longer to reload.
func test_long_barrel_50_more_and_3_more_seconds() -> void:
	var ctx := await duel([[[6], &"long_barrel"], [[7], &"stinger"]], [], 60.0)
	ctx.setup_all()  # the cooldown stat comes from the modifiers setup_all caches
	var stinger := of(ctx, 0, &"stinger")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(stinger != null and of(ctx, 0, &"long_barrel") != null,
		"the barrel and the weapon in front mounted")
	stinger.cooldown_left = 0.0  # a fresh part starts on its full cooldown
	var before := foe.hp
	await step(ctx, TICK, true, false)
	assert_eq(before - foe.hp, 75, "the stab's 25 plus 50")
	assert_near(stinger.cooldown, 5.0, 0.001, "and 2 s + 3 s to reload")
	_complete()


# R18: an own beam's hit gets +1 for every 5 cells between the chariots; this gap is 40.
func test_distance_lens_1_a_hit_per_5_cells() -> void:
	var ctx := await duel([[[0], &"distance_lens"], [[7], &"laser"]], [], 40.0)
	var laser := of(ctx, 0, &"laser")
	assert_true(laser != null and of(ctx, 0, &"distance_lens") != null,
		"the lens and the beam mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, false, true)
	var paid := _paid(hits, laser)
	assert_eq(paid, [20], "the beam's 12 plus 8 for the 40 cells")
	_complete()


# R19: 500 split evenly across every enemy part the line crosses; here, two.
func test_piercing_railgun_500_split_between_two_parts() -> void:
	var ctx := await duel([[[7], &"piercing_railgun"]],
		[[[4], &"reinforced_frame"], [[3], &"reinforced_frame"]], 60.0)
	var gun := of(ctx, 0, &"piercing_railgun")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(gun != null, "the railgun mounted")
	gun.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 12 s
	var before := foe.hp
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, true, false)
	assert_eq(before - foe.hp, 500, "500 across the two parts")
	assert_eq(_paid(hits, gun), [250, 250], "250 each")
	_complete()


# R19: a line that crosses no part pays the hull the whole 500.
func test_piercing_railgun_500_on_the_hull_with_nothing_on_the_line() -> void:
	var ctx := await duel([[[7], &"piercing_railgun"]], [], 60.0)
	var gun := of(ctx, 0, &"piercing_railgun")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(gun != null, "the railgun mounted")
	gun.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 12 s
	var before := foe.hp
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, true, false)
	assert_eq(before - foe.hp, 500, "the hull takes the whole 500")
	assert_eq(_paid(hits, gun), [500], "once")
	if hits.size() == 1:
		assert_true(hits[0].data["target_part"] == null, "on the hull, not a part")
	_complete()
