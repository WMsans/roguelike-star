extends ChPartTest

# Task 17: the Rammer parts (U73-U77, R32-R33) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# Ramming and landing are fight-level: ChBattleContext emits RAMMED once per hull contact and LANDED
# on a long enough airborne spell, and ChChariotRuntime.airborne answers the floor question. The
# tests that need real Box2D contacts step the world by hand (simulating off + world.step(1) per
# tick), so one fight tick and one physics step always cover the same 1/60 s.

const RAM_SPEED := 20.0  # ChBattleContext.RAM_SPEED, the speed a contact needs to count as a ram


# The hp_damage of every hit `source` dealt, in delivery order.
func _paid(hits: Array, source: Object) -> Array:
	var out: Array = []
	for hit in hits:
		if hit.source == source:
			out.append(int(hit.data["hp_damage"]))
	return out


# One fight tick and one physics step, so the fight clock and Box2D advance together.
func _roll(ctx: ChBattleContext, ticks: int) -> void:
	for _tick in range(ticks):
		ctx.tick(TICK, [0.0, 0.0], [], [])
		await Engine.get_main_loop().process_frame
		ctx.world.step(1)


# A LANDED event for `side`, as ChBattleContext emits it: source the chariot, no payload.
func _landed(ctx: ChBattleContext, side: int) -> void:
	var event := ChEvent.new()
	event.type = ChEvent.LANDED
	event.side = side
	event.source = ctx.chariots[side]
	event.position = ctx.chariots[side].anchor_world()
	ctx.bus.emit(event)


# The own chariots' hulls start apart (gap 80: two 60-wide boxes), settle on the rock, then touch
# at rest and charge in at `speed`. Answers the RAMMED sink for the caller to count.
func _ram(ctx: ChBattleContext, speed := RAM_SPEED + 5.0) -> Array:
	var player := ctx.chariots[0]
	var foe := ctx.chariots[1]
	var rams := sink(ctx, ChEvent.RAMMED)
	ctx.world.simulating = false
	await _roll(ctx, 40)
	# The enemy hull is moved and the player left where it is, so the player's mounted parts stay
	# inside their own reach of the contact. Hulls touching at rest is not a ram.
	foe.chassis.global_position.x = player.chassis.global_position.x + 50.0
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(rams.size(), 0, "hulls touching at rest emit no RAMMED")
	# Apart, then back together at speed: that is a new contact.
	foe.chassis.global_position.x = player.chassis.global_position.x + 200.0
	ctx.tick(TICK, [0.0, 0.0], [], [])
	foe.chassis.global_position.x = player.chassis.global_position.x + 50.0
	player.chassis.linear_velocity = Vector2(speed, 0.0)
	ctx.tick(TICK, [0.0, 0.0], [], [])
	return rams


# U73: ramming deals 40 to the part rammed.
func test_ram_spike_40_on_the_part_rammed() -> void:
	var ctx := await duel([[[7], &"ram_spike"]], [], 80.0)
	var spike := of(ctx, 0, &"ram_spike")
	assert_true(spike != null, "the ram spike mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var rams: Array = await _ram(ctx)
	assert_eq(rams.size(), 1, "one contact, one ram")
	if rams.size() == 1:
		assert_eq(rams[0].side, 0, "the rammer's side")
		var target: ChPartRuntime = rams[0].data["target_part"]
		assert_true(target != null, "and the part it rammed")
		if target != null:
			assert_true(target.side == 1, "an enemy part")
	assert_eq(_paid(hits, spike), [40], "40 damage on what it rammed")
	# Once per contact: another tick inside the same contact pays nothing more.
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(_paid(hits, spike), [40], "a second tick of the same contact is not a second ram")
	_complete()


# U74: the press launches the chariot forward.
func test_booster_rocket_launches_forward() -> void:
	var ctx := await duel([[[7], &"booster_rocket"]], [], 80.0)
	ctx.world.simulating = false
	var rocket := of(ctx, 0, &"booster_rocket")
	assert_true(rocket != null, "the booster mounted")
	await _roll(ctx, 40)
	var player := ctx.chariots[0]
	rocket.cooldown_left = 0.0
	ctx.tick(TICK, [0.0, 0.0], [true, false], [])
	assert_true(player.chassis.linear_velocity.x > 0.0, "the launch pushes the hull along its facing")
	var start_x := player.chassis.global_position.x
	await _roll(ctx, 30)
	assert_true(player.chassis.global_position.x > start_x, "and the hull travels forward")
	_complete()


# U75: the press jumps, and the next landing deals 30 to the parts underneath.
func test_pogo_spring_jumps_and_30_on_the_next_landing() -> void:
	var ctx := await duel([[[7], &"pogo_spring"]], [[[0], &"reinforced_frame"]], 80.0)
	ctx.world.simulating = false
	var pogo := of(ctx, 0, &"pogo_spring")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(pogo != null and target != null, "the spring and a part to land on mounted")
	await _roll(ctx, 40)
	var player := ctx.chariots[0]
	var hits := sink(ctx, ChEvent.HIT)
	# The part waits 4 cells under the hull, inside the row's 8.
	target.body.global_position = Vector2(player.chassis.global_position.x,
		player.status_box().end.y + 4.0)
	# A landing that is not the jump's pays nothing: the spring is armed by its firing.
	_landed(ctx, 0)
	assert_eq(_paid(hits, pogo), [], "a landing before the press is not the jump")
	pogo.cooldown_left = 0.0
	var fall := player.chassis.linear_velocity.y
	ctx.tick(TICK, [0.0, 0.0], [true, false], [])
	assert_true(player.chassis.linear_velocity.y < fall - 1.0, "the spring shoves the hull up")
	_landed(ctx, 0)
	assert_eq(_paid(hits, pogo), [30], "30 to the part underneath")
	if hits.size() == 1:
		assert_true(hits[0].data["target_part"] == target, "the part under the hull took it")
	# The next landing is not the jump's: the spring pays once.
	_landed(ctx, 0)
	assert_eq(_paid(hits, pogo), [30], "only the next landing pays")
	_complete()


# U76: while driving, one melee tick a second for 8, and PART_FIRED each time.
func test_spiked_wheel_fires_8_each_second_while_driving() -> void:
	var ctx := await duel([[[7], &"spiked_wheel"]])
	var wheel := of(ctx, 0, &"spiked_wheel")
	assert_true(wheel != null, "the spiked wheel mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var fired := sink(ctx, ChEvent.PART_FIRED)
	await step(ctx, 2.1, false, false, 1.0)
	assert_eq(_paid(hits, wheel).size(), 2, "two ticks in two seconds of driving")
	for paid in _paid(hits, wheel):
		assert_eq(paid, 8, "8 a tick")
	var mine := 0
	for event in fired:
		if event.source == wheel:
			mine += 1
	assert_eq(mine, 2, "each tick counts as a melee firing")
	assert_eq(wheel.rate, 2.0, "2 energy a second while driving")
	await step(ctx, 1.2, false, false, 0.0)
	assert_eq(_paid(hits, wheel).size(), 2, "and nothing while not driving")
	_complete()


# U77: start of battle pays 3 and pulls both chariots together.
func test_harpoon_pulls_both_chariots_together() -> void:
	var ctx := await duel([[[6], &"harpoon"]], [], 120.0)
	ctx.world.simulating = false
	var player := ctx.chariots[0]
	var foe := ctx.chariots[1]
	var start_gap := absf(foe.chassis.global_position.x - player.chassis.global_position.x)
	await _roll(ctx, 45)
	assert_near(player.energy.spent, 3.0, 0.01, "the start-of-battle pull pays 3")
	var gap := absf(foe.chassis.global_position.x - player.chassis.global_position.x)
	assert_true(gap < start_gap - 2.0, "the two chariots are pulled together (%s -> %s)" % [start_gap, gap])
	_complete()


# R32: while driving, own parts other than wheels cost no energy.
func test_juggernaut_makes_non_wheels_free_while_driving() -> void:
	var ctx := await duel([[[5], &"stinger"], [[6], &"juggernaut"], [[7], &"laser"]])
	ctx.setup_all()
	var laser := of(ctx, 0, &"laser")
	var stinger := of(ctx, 0, &"stinger")
	var roller := of(ctx, 0, &"roller")
	assert_true(laser != null and stinger != null and roller != null, "the parts mounted")
	# One tick to drive, a second to fold the driving state into the cost refresh.
	await step(ctx, TICK, false, false, 1.0)
	await step(ctx, TICK, false, false, 1.0)
	assert_eq(laser.rate, 0.0, "the beam costs nothing a second while driving")
	assert_eq(stinger.cost, 0, "and neither does the weapon on a press")
	assert_eq(roller.rate, 1.0, "a wheel still costs")
	await step(ctx, TICK, false, false, 0.0)
	await step(ctx, TICK, false, false, 0.0)
	assert_eq(laser.rate, 3.0, "and the beam costs again once the drive stops")
	_complete()


# R33: ramming fires each own melee weapon 3 times.
func test_wrecking_gear_fires_each_melee_3_times() -> void:
	var ctx := await duel([[[6], &"wrecking_gear"], [[7], &"chainsaw"]], [], 80.0)
	var saw := of(ctx, 0, &"chainsaw")
	assert_true(saw != null and of(ctx, 0, &"wrecking_gear") != null, "the gear and its saw mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var fired := sink(ctx, ChEvent.PART_FIRED)
	var rams: Array = await _ram(ctx)
	assert_eq(rams.size(), 1, "the ram landed")
	assert_eq(_paid(hits, saw), [15, 15, 15], "each melee weapon fires 3 times")
	var forced := 0
	for event in fired:
		if event.source == saw and bool(event.data.get("forced", false)):
			forced += 1
	assert_eq(forced, 3, "three forced firings")
	_complete()


# The hull boxes overlap but nobody is moving fast enough: no RAMMED.
func test_ram_needs_speed() -> void:
	var ctx := await duel([], [], 80.0)
	ctx.world.simulating = false
	var player := ctx.chariots[0]
	var foe := ctx.chariots[1]
	var rams := sink(ctx, ChEvent.RAMMED)
	await _roll(ctx, 40)
	# Touching at rest.
	foe.chassis.global_position.x = player.chassis.global_position.x + 50.0
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(rams.size(), 0, "hulls touching at rest emit no RAMMED")
	# A fresh contact just under the threshold.
	foe.chassis.global_position.x = player.chassis.global_position.x + 200.0
	ctx.tick(TICK, [0.0, 0.0], [], [])
	foe.chassis.global_position.x = player.chassis.global_position.x + 50.0
	player.chassis.linear_velocity = Vector2(RAM_SPEED - 0.1, 0.0)
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(rams.size(), 0, "just under 20 cells a second is no ram")
	# A fresh contact exactly at the threshold.
	foe.chassis.global_position.x = player.chassis.global_position.x + 200.0
	ctx.tick(TICK, [0.0, 0.0], [], [])
	foe.chassis.global_position.x = player.chassis.global_position.x + 50.0
	player.chassis.linear_velocity = Vector2(RAM_SPEED, 0.0)
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(rams.size(), 1, "20 cells a second is a ram")
	_complete()


# The fight-level landing seam: airborne() reads the floor contacts and a long enough fall emits
# LANDED. A wheel-less hull is the cleanest body to lift: no wheel can keep it grounded.
func test_airborne_and_landed() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock")
	world.simulating = false
	var catalog := _catalog_with_rig()
	var layout := ChChariotLayout.new()
	layout.body_id = RIG
	var rig := ChChariotBuilder.build(world, _parent(), layout, catalog, 0, Vector2(160, 100), false)
	assert_true(rig != null, "the wheel-less hull builds")
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = [rig]
	var landings := sink(ctx, ChEvent.LANDED)
	assert_true(rig.airborne(), "56 cells up, the hull is airborne")
	for _tick in range(120):
		ctx.tick(TICK, [0.0], [], [])
		await Engine.get_main_loop().process_frame
		world.step(1)
		if not landings.is_empty():
			break
	assert_true(not rig.airborne(), "the hull is on the rock")
	assert_eq(landings.size(), 1, "one landing after the fall")
	if landings.size() == 1:
		assert_eq(landings[0].side, 0, "on the player's side")
	# A hop under 0.2 s lands without a LANDED.
	rig.chassis.linear_velocity = Vector2(0.0, -30.0)
	for _tick in range(30):
		ctx.tick(TICK, [0.0], [], [])
		await Engine.get_main_loop().process_frame
		world.step(1)
	assert_eq(landings.size(), 1, "a 0.1 s hop lands without a LANDED")
	_complete()
