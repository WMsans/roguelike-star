extends ChPartTest

# Task 22: the Reactor parts (U59-U63, R27-R28) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# Two of them are the volley hooks: U60's `volley_priority` reorders the press and R28's `blood_pay`
# pays a refused part's shortfall in HP. The stat hooks need ctx.setup_all(), which caches the
# modifiers the context folds; duel() only calls each behaviour's setup.

# The unbroken part mounted at `slot` on `side`, or null. parts[] is in the builder's depth-first
# order (highest slot first), so tests name the slot rather than the array index.
func _at(ctx: ChBattleContext, side: int, slot: int) -> ChPartRuntime:
	for part in ctx.chariots[side].parts:
		if not part.broken and part.path == [slot]:
			return part
	return null


# What a sink's ENERGY_GAINED events add up to.
func _gained(events: Array) -> float:
	var total := 0.0
	for event in events:
		total += float(event.data["amount"])
	return total


# U59: every second the pool is at cap, the body gains 3 Block. A pool that is not full gains none.
func test_overflow_valve_gives_the_body_3_block_each_second_at_full_energy() -> void:
	var ctx := await duel([[[3], &"overflow_valve"]])
	var valve := of(ctx, 0, &"overflow_valve")
	var body := ctx.chariots[0]
	assert_true(valve != null, "the valve mounted")
	if valve == null:
		_complete()
		return
	await step(ctx, 1.1)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), 3, "one second at full energy gives 3 Block")
	body.energy.value = 1.0
	await step(ctx, 1.0)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), 3, "a pool that is not full gives none")
	body.energy.value = body.energy.cap
	await step(ctx, 1.0)
	assert_eq(body.statuses.count(ChStatuses.BLOCK), 6, "full again, another 3")
	_complete()


# U60: the neighbour is paid before a dearer part that is out of the relay's range.
func test_priority_relay_makes_a_neighbour_go_first_in_a_volley() -> void:
	var ctx := await duel([[[0], &"pulse_gun"], [[4], &"priority_relay"], [[5], &"igniter"]])
	var relay := of(ctx, 0, &"priority_relay")
	var dear := _at(ctx, 0, 0)
	var near := _at(ctx, 0, 5)
	assert_true(relay != null and dear != null and near != null, "the relay and both guns mounted")
	if relay == null or dear == null or near == null:
		_complete()
		return
	ctx.setup_all()
	assert_near(ctx.stat(near, ChBattleContext.STAT_VOLLEY_PRIORITY, 0.0), 1.0, 0.001,
		"a neighbour's priority is 1")
	assert_near(ctx.stat(dear, ChBattleContext.STAT_VOLLEY_PRIORITY, 0.0), 0.0, 0.001,
		"a part out of range is 0")
	var player := ctx.chariots[0]
	player.energy.regen = 0.0
	player.energy.value = 3.0
	dear.cooldown_left = 0.0
	near.cooldown_left = 0.0
	var skipped := sink(ctx, ChEvent.PART_SKIPPED)
	await step(ctx, TICK, true)
	assert_true(near.cooldown_left > 0.0, "the 2-energy neighbour fired first")
	assert_eq(skipped.size(), 1, "the 3-energy gun was refused")
	if skipped.size() == 1:
		assert_true(skipped[0].source == dear, "the gun that lost its turn is the one announced")
	_complete()


# U61: a wheel that gains 2 energy a second of its own while the chariot drives.
func test_dynamo_wheel_gains_2_energy_a_second_while_driving() -> void:
	var ctx := await duel([[[7], &"dynamo_wheel"]])
	var wheel := of(ctx, 0, &"dynamo_wheel")
	var player := ctx.chariots[0]
	assert_true(wheel != null, "the wheel mounted")
	assert_true(wheel != null and wheel.def.mode == ChPartDef.MODE_WHEEL, "it is a wheel")
	if wheel == null:
		_complete()
		return
	var gained := sink(ctx, ChEvent.ENERGY_GAINED)
	# No regen and a pool well under cap, so every ENERGY_GAINED here is the wheel's own and none is
	# clamped away. The drive cost is still paid, so the net pool falls; only the gain is asserted.
	player.energy.regen = 0.0
	player.energy.value = 5.0
	await step(ctx, 0.5, false, false, 1.0)
	assert_true(player.driving, "the drive was paid")
	assert_near(_gained(gained), 1.0, 0.01, "2 energy a second for half a second")
	gained.clear()
	await step(ctx, 0.5)
	assert_eq(gained.size(), 0, "standing still gains nothing")
	_complete()


# U62: 20 damage, and 3 energy when the part the bolt hit is shocked.
func test_power_siphon_20_damage_and_3_energy_off_a_shocked_part() -> void:
	var ctx := await duel([[[7], &"power_siphon"]], [[[7], &"reinforced_frame"]], 60.0)
	var siphon := of(ctx, 0, &"power_siphon")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(siphon != null and target != null, "the siphon and its target mounted")
	if siphon == null or target == null:
		_complete()
		return
	var hits := sink(ctx, ChEvent.HIT)
	var gained := sink(ctx, ChEvent.ENERGY_GAINED)
	var player := ctx.chariots[0]
	# The rigs settle onto their wheels in the first second; fire after that, so the shot's line is
	# the line the enemy part straddles. Shock goes on after settling so no status second eats it.
	await step(ctx, 1.0, false, false, 0.0, true)
	player.energy.regen = 0.0
	player.energy.value = 6.0
	ctx.give_status(target, ChStatuses.SHOCK, 1)
	siphon.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 30:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the bolt landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 20, "20 damage")
		assert_true(hits[0].data.get("target_part") == target, "it struck the shocked part")
	assert_near(_gained(gained), 3.0, 0.001, "3 energy off a shocked part")
	_complete()


# U63: the press spends the whole pool; 15 damage for every energy spent. The 1-energy cost is paid
# first, so a pool of 7 is 7 spent: 6 left after the cost, plus the 1 the volley paid.
func test_surge_cannon_spends_the_pool_for_15_damage_an_energy() -> void:
	var ctx := await duel([[[7], &"surge_cannon"]], [[[7], &"reinforced_frame"]], 60.0)
	var cannon := of(ctx, 0, &"surge_cannon")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(cannon != null and target != null, "the cannon and its target mounted")
	if cannon == null or target == null:
		_complete()
		return
	var hits := sink(ctx, ChEvent.HIT)
	var player := ctx.chariots[0]
	await step(ctx, 1.0, false, false, 0.0, true)
	player.energy.regen = 0.0
	player.energy.value = 7.0
	cannon.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	assert_near(player.energy.value, 0.0, 0.001, "the pool is spent to nothing")
	for _frame in 30:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the shell landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 105, "15 damage for each of the 7 energy spent")
	_complete()


# U63 again: a forced fire is paid by nobody, so there is no already-paid 1 energy to charge for. A
# pool of 5 is 75 damage, not the 90 a volley's own point would make it.
func test_surge_cannon_forced_fire_charges_only_what_it_spends() -> void:
	var ctx := await duel([[[7], &"surge_cannon"]], [[[7], &"reinforced_frame"]], 60.0)
	var cannon := of(ctx, 0, &"surge_cannon")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(cannon != null and target != null, "the cannon and its target mounted")
	if cannon == null or target == null:
		_complete()
		return
	var hits := sink(ctx, ChEvent.HIT)
	var player := ctx.chariots[0]
	await step(ctx, 1.0, false, false, 0.0, true)
	player.energy.regen = 0.0
	player.energy.value = 5.0
	ctx.force_fire(cannon, target)
	assert_near(player.energy.value, 0.0, 0.001, "the forced fire spends the pool it was given")
	for _frame in 30:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the shell landed")
	if hits.size() == 1:
		assert_eq(int(hits[0].data["hp_damage"]), 75, "15 damage for each of the 5 energy spent")
	_complete()


# R27: while the pool is full, the next part to fire gets one forced second fire; once the pool is
# no longer full, nothing doubles.
func test_fusion_core_doubles_the_next_part_to_fire_while_full() -> void:
	var ctx := await duel([[[4], &"fusion_core"], [[5], &"pulse_gun"]])
	var core := of(ctx, 0, &"fusion_core")
	var gun := of(ctx, 0, &"pulse_gun")
	var player := ctx.chariots[0]
	assert_true(core != null and gun != null, "the core and the gun mounted")
	if core == null or gun == null:
		_complete()
		return
	var fired := sink(ctx, ChEvent.PART_FIRED)
	# One tick with no press lets process arm the core off the full pool.
	await step(ctx, TICK)
	assert_true(player.energy.value >= player.energy.cap, "the pool is full")
	gun.cooldown_left = 0.0
	await step(ctx, TICK, true)
	var shots: Array = []
	for event in fired:
		if event.source == gun:
			shots.append(event)
	assert_eq(shots.size(), 2, "the gun fired twice")
	if shots.size() == 2:
		assert_true(not shots[0].data.get("forced", false), "the first is the volley's own fire")
		assert_true(shots[1].data.get("forced", false), "the second is the core's forced fire")
	gun.cooldown_left = 0.0
	await step(ctx, TICK, true)
	var after := 0
	for event in fired:
		if event.source == gun:
			after += 1
	assert_eq(after, 3, "a pool that is no longer full doubles nothing")
	_complete()


# R28: a part the pool cannot afford fires anyway, the whole pool is paid, and nothing is
# announced as skipped. The gun costs 3 over a pool of 1.
func test_blood_cell_lets_an_unaffordable_part_fire() -> void:
	var ctx := await duel([[[3], &"blood_cell"], [[7], &"pulse_gun"]])
	var cell := of(ctx, 0, &"blood_cell")
	var gun := _at(ctx, 0, 7)
	assert_true(cell != null and gun != null, "the cell and the gun mounted")
	if cell == null or gun == null:
		_complete()
		return
	ctx.setup_all()
	var player := ctx.chariots[0]
	player.energy.regen = 0.0
	player.energy.value = 1.0
	gun.cooldown_left = 0.0
	var skipped := sink(ctx, ChEvent.PART_SKIPPED)
	var fired := sink(ctx, ChEvent.PART_FIRED)
	await step(ctx, TICK, true)
	assert_near(player.energy.value, 0.0, 0.001, "the whole pool is paid")
	assert_eq(skipped.size(), 0, "a blood-paid part is not skipped")
	assert_eq(fired.size(), 1, "and it fires as normal")
	if fired.size() == 1:
		assert_true(fired[0].source == gun, "the gun is what fired")
	assert_true(gun.cooldown_left > 0.0, "with its cooldown spent")
	_complete()


# R28: the shortfall costs 10 HP an energy, paid through lose_hp so the loss is one event with the
# `blood` cause and the part that could not pay as its source.
func test_blood_cell_pays_in_hp_through_lose_hp() -> void:
	var ctx := await duel([[[3], &"blood_cell"], [[7], &"pulse_gun"]])
	var cell := of(ctx, 0, &"blood_cell")
	var gun := _at(ctx, 0, 7)
	assert_true(cell != null and gun != null, "the cell and the gun mounted")
	if cell == null or gun == null:
		_complete()
		return
	ctx.setup_all()
	var player := ctx.chariots[0]
	player.energy.regen = 0.0
	player.energy.value = 1.0
	gun.cooldown_left = 0.0
	assert_near(ctx.stat(gun, ChBattleContext.STAT_BLOOD_PAY, 0.0), 1.0, 0.001,
		"an own part may pay in blood")
	var lost := sink(ctx, ChEvent.HP_LOST)
	await step(ctx, TICK, true)
	assert_eq(player.hp, 780, "the 2 energy short cost 20 HP")
	assert_eq(lost.size(), 1, "one HP loss pays the shortfall")
	if lost.size() == 1:
		assert_eq(int(lost[0].data["amount"]), 20, "10 HP for each of the 2 energy short")
		assert_eq(lost[0].data["cause"], &"blood", "the loss names blood")
		assert_true(lost[0].source == gun, "the part that could not pay is the source")
	_complete()
