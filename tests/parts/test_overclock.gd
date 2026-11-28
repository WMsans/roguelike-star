extends ChPartTest

# Task 21: the Overclock parts (U53-U58, R25-R26) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The two shooters (U55, U57) aim at the far rig, so their bolts need engine frames; the status
# passives stay synchronous. The stat hooks (U56, R26) need ctx.setup_all(), which caches the
# modifiers the context folds; duel() only calls each behaviour's setup.

# The unbroken part mounted at `slot` on `side`, or null. parts[] is in the builder's depth-first
# order (highest slot first), so tests name the slot rather than the array index.
func _at(ctx: ChBattleContext, side: int, slot: int) -> ChPartRuntime:
	for part in ctx.chariots[side].parts:
		if not part.broken and part.path == [slot]:
			return part
	return null


# U53: the part in front gains 2 Speedup; the one behind gains none.
func test_overclocker_gives_the_front_part_2_speedup() -> void:
	var ctx := await duel([[[4], &"reinforced_frame"], [[5], &"overclocker"],
		[[6], &"reinforced_frame"]])
	var gun := of(ctx, 0, &"overclocker")
	var front := _at(ctx, 0, 6)
	var back := _at(ctx, 0, 4)
	assert_true(gun != null and front != null and back != null, "the overclocker and both frames mounted")
	if gun == null or front == null or back == null:
		_complete()
		return
	gun.cooldown_left = 0.0
	await step(ctx, TICK, true)
	assert_eq(front.statuses.count(ChStatuses.SPEEDUP), 2, "the front part gained 2 Speedup")
	assert_eq(back.statuses.count(ChStatuses.SPEEDUP), 0, "and the one behind gained none")
	_complete()


# U54: the part behind this gaining Speedup gives the part in front 1; another part's gain does not.
func test_gear_linkage_passes_the_back_parts_speedup_forward() -> void:
	var ctx := await duel([[[3], &"reinforced_frame"], [[4], &"gear_linkage"],
		[[5], &"reinforced_frame"], [[6], &"reinforced_frame"]])
	var linkage := of(ctx, 0, &"gear_linkage")
	var back := _at(ctx, 0, 3)
	var front := _at(ctx, 0, 5)
	var far := _at(ctx, 0, 6)
	assert_true(linkage != null and back != null and front != null and far != null,
		"the linkage and three frames mounted")
	if linkage == null or back == null or front == null or far == null:
		_complete()
		return
	ctx.give_status(back, ChStatuses.SPEEDUP, 1)
	assert_eq(front.statuses.count(ChStatuses.SPEEDUP), 1, "the part in front gained 1")
	ctx.give_status(far, ChStatuses.SPEEDUP, 1)
	assert_eq(front.statuses.count(ChStatuses.SPEEDUP), 1, "a part that is not the back gained none")
	_complete()


# U55: 30 damage, and its own Speedup gain makes every later hit 10 more for the battle.
func test_momentum_hammer_30_damage_plus_10_for_its_speedup() -> void:
	var ctx := await duel([[[7], &"momentum_hammer"]], [[[0], &"reinforced_frame"]], 60.0)
	var hammer := of(ctx, 0, &"momentum_hammer")
	assert_true(hammer != null, "the hammer mounted")
	if hammer == null:
		_complete()
		return
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 0.6, false, false, 0.0, true)
	hammer.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the first bolt landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 30, "30 damage")
	ctx.give_status(hammer, ChStatuses.SPEEDUP, 1)
	assert_eq(hammer.bonus_damage, 10, "its Speedup gain is +10 damage for the battle")
	hammer.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if hits.size() >= 2:
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 2, "the second bolt landed")
	if hits.size() >= 2:
		assert_eq(int(hits[1].data["hp_damage"]), 40, "and it pays 30 + 10")
	_complete()


# U56: a neighbouring part loses 2 Slow a second; one outside the range loses 1.
func test_coolant_pump_makes_neighbours_lose_slow_twice_as_fast() -> void:
	var ctx := await duel([[[3], &"coolant_pump"], [[4], &"reinforced_frame"],
		[[7], &"reinforced_frame"]])
	var near := _at(ctx, 0, 4)
	var far := _at(ctx, 0, 7)
	assert_true(near != null and far != null, "both frames mounted")
	if near == null or far == null:
		_complete()
		return
	ctx.setup_all()
	ctx.give_status(near, ChStatuses.SLOW, 4)
	ctx.give_status(far, ChStatuses.SLOW, 4)
	await step(ctx, 1.1)
	assert_eq(near.statuses.count(ChStatuses.SLOW), 2, "the neighbour lost Slow twice as fast")
	assert_eq(far.statuses.count(ChStatuses.SLOW), 3, "one outside the range lost 1")
	_complete()


# U57: 20 damage, and every neighbour gains 1 Speedup when it fires.
func test_pulse_gun_20_damage_and_1_speedup_to_neighbours() -> void:
	var ctx := await duel([[[4], &"reinforced_frame"], [[5], &"pulse_gun"],
		[[6], &"reinforced_frame"]], [[[0], &"reinforced_frame"]], 60.0)
	var gun := of(ctx, 0, &"pulse_gun")
	var near := _at(ctx, 0, 4)
	var front := _at(ctx, 0, 6)
	assert_true(gun != null and near != null and front != null, "the gun and both frames mounted")
	if gun == null or near == null or front == null:
		_complete()
		return
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 0.6, false, false, 0.0, true)
	gun.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	for frame in [near, front]:
		assert_eq(frame.statuses.count(ChStatuses.SPEEDUP), 1, "a neighbour gained 1 Speedup")
	assert_eq(gun.statuses.count(ChStatuses.SPEEDUP), 0, "and the gun did not speed itself up")
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the bolt landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 20, "20 damage")
	_complete()


# U58: a neighbour's Speedup arms its next hit to throw sparks at the target, once. A part outside
# the range gaining Speedup arms nothing.
func test_static_gears_arms_a_neighbours_next_hit() -> void:
	var ctx := await duel([[[0], &"cannon"], [[6], &"static_gears"], [[7], &"cannon"]],
		[[[0], &"reinforced_frame"]], 60.0)
	var gears := of(ctx, 0, &"static_gears")
	var far := _at(ctx, 0, 0)  # 36 cells from the gears, out of their range
	var near := _at(ctx, 0, 7)  # next to the gears
	assert_true(gears != null and far != null and near != null, "the gears and both cannons mounted")
	if gears == null or far == null or near == null:
		_complete()
		return
	var foe: ChChariotRuntime = ctx.chariots[1]
	ctx.give_status(near, ChStatuses.SPEEDUP, 1)
	ctx.give_status(far, ChStatuses.SPEEDUP, 1)
	# The far part is no neighbour, so its hit throws nothing.
	ctx.deal_hit(far, foe.chassis, 5)
	assert_eq(foe.statuses.count(ChStatuses.SHOCK), 0, "a far part's hit throws no sparks")
	# The neighbour's next hit throws sparks at the target, which shock it.
	ctx.deal_hit(near, foe.chassis, 5)
	var shocked := foe.statuses.count(ChStatuses.SHOCK)
	assert_true(shocked > 0, "the armed neighbour's hit threw sparks at the target")
	# One hit only: the neighbour is disarmed.
	ctx.deal_hit(near, foe.chassis, 5)
	assert_eq(foe.statuses.count(ChStatuses.SHOCK), shocked, "its next hit throws nothing more")
	_complete()


# R25: its own Speedup gain (n) gives the part in front 2n.
func test_perpetual_gear_doubles_its_speedup_forward() -> void:
	var ctx := await duel([[[5], &"perpetual_gear"], [[6], &"reinforced_frame"]])
	var gear := of(ctx, 0, &"perpetual_gear")
	var front := of(ctx, 0, &"reinforced_frame")
	assert_true(gear != null and front != null, "the gear and the part in front mounted")
	if gear == null or front == null:
		_complete()
		return
	ctx.give_status(gear, ChStatuses.SPEEDUP, 2)
	assert_eq(gear.statuses.count(ChStatuses.SPEEDUP), 2, "the gear gained 2")
	assert_eq(front.statuses.count(ChStatuses.SPEEDUP), 4, "and the part in front gained double")
	_complete()


# Review Focus 4: two Perpetual Gears facing each other across a Gear Linkage, given 1 Speedup. The
# chain must end on its own and ten fight seconds must run rather than hang.
func test_perpetual_gear_and_linkage_loop_ends() -> void:
	var ctx := await duel([[[3], &"perpetual_gear"], [[4], &"gear_linkage"],
		[[5], &"perpetual_gear", true]])
	var left := _at(ctx, 0, 3)
	var right := _at(ctx, 0, 5)
	var linkage := of(ctx, 0, &"gear_linkage")
	assert_true(left != null and right != null and linkage != null, "the two gears and the linkage mounted")
	if left == null or right == null or linkage == null:
		_complete()
		return
	ctx.give_status(left, ChStatuses.SPEEDUP, 1)
	# Left gear 1 -> linkage 2 -> right gear 1 -> linkage 2 more. Nothing feeds back.
	assert_eq(left.statuses.count(ChStatuses.SPEEDUP), 1, "the left gear keeps its 1")
	assert_eq(right.statuses.count(ChStatuses.SPEEDUP), 1, "the linkage passed 1 to the right gear")
	assert_eq(linkage.statuses.count(ChStatuses.SPEEDUP), 4, "and the linkage gained 2 from each gear")
	await step(ctx, 10.0)
	assert_true(ctx.time >= 10.0, "the fight reached 10 s")
	_complete()


# R26: Speedup runs an own part's cooldown at 3x; no Speedup stays 1x, and an enemy part stays 2x.
func test_overdrive_runs_own_speedup_at_triple_speed() -> void:
	var ctx := await duel([[[5], &"overdrive"], [[6], &"reinforced_frame"], [[7], &"reinforced_frame"]],
		[[[0], &"reinforced_frame"]])
	var fast := _at(ctx, 0, 6)
	var slow := _at(ctx, 0, 7)
	var foe: ChPartRuntime = of(ctx, 1, &"reinforced_frame")
	assert_true(fast != null and slow != null and foe != null, "the frames mounted")
	if fast == null or slow == null or foe == null:
		_complete()
		return
	ctx.setup_all()
	ctx.give_status(fast, ChStatuses.SPEEDUP, 1)
	ctx.give_status(foe, ChStatuses.SPEEDUP, 1)
	assert_near(ctx.stat(fast, ChBattleContext.STAT_TICK_RATE, fast.tick_rate()), 3.0,
		0.001, "an own part's Speedup runs at triple speed")
	assert_near(ctx.stat(slow, ChBattleContext.STAT_TICK_RATE, slow.tick_rate()), 1.0,
		0.001, "an own part with no Speedup stays at normal speed")
	assert_near(ctx.stat(foe, ChBattleContext.STAT_TICK_RATE, foe.tick_rate()), 2.0,
		0.001, "an enemy part's Speedup stays at double")
	_complete()
