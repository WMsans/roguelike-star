extends ChPartTest

# Task 20: the Gale parts (U48-U52, R23-R24) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn and the wind parts on the cells they move.
# The passive listeners stay synchronous; only the Gust Cannon's push needs engine frames.

func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))


func _spawned(spawns: Array, material: StringName) -> Array:
	var out: Array = []
	for event in spawns:
		if event.data.get("material") == material:
			out.append(event)
	return out


# U48: a 20-cell box ahead: 10 damage, a shove for the enemy and a 20-cell blow for the gases in it.
func test_gust_cannon_10_damage_pushes_and_blows_gas_20_cells() -> void:
	var ctx := await duel([[[7], &"gust_cannon"]], [], 60.0)
	var cannon := of(ctx, 0, &"gust_cannon")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(cannon != null, "the gust cannon mounted")
	if cannon == null:
		_complete()
		return
	var at := Vector2i(roundi(cannon.anchor_world().x) + 14, roundi(cannon.anchor_world().y) - 1)
	ctx.world.set_cell(at, &"smoke")
	cannon.cooldown_left = 0.0
	var before := foe.hp
	var foe_x := foe.chassis.global_position.x
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 10, "the blast pays 10")
	assert_eq(ctx.world.get_material_at(at + Vector2i(20, 0)), &"smoke", "the gas moved 20 cells")
	assert_eq(ctx.world.get_material_at(at), &"air", "and left its old cell")
	await step(ctx, 0.5, false, false, 0.0, true)
	assert_true(foe.chassis.global_position.x > foe_x, "the blast shoves the enemy away")
	_complete()


# U49: a Fire-tagged own part firing leaves 8 smoke cells 4 cells in front of it; another part's
# firing leaves none.
func test_smokestack_puffs_8_smoke_4_in_front_of_a_fire_part() -> void:
	var ctx := await duel([[[5], &"igniter"], [[6], &"minigun"], [[7], &"smokestack"]], [], 60.0)
	var igniter := of(ctx, 0, &"igniter")
	var minigun := of(ctx, 0, &"minigun")
	var stack := of(ctx, 0, &"smokestack")
	assert_true(igniter != null and minigun != null and stack != null, "all three parts mounted")
	if igniter == null or minigun == null or stack == null:
		_complete()
		return
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	igniter.cooldown_left = 0.0
	minigun.cooldown_left = 0.0
	await step(ctx, TICK, true)
	var smoke := _spawned(spawns, &"smoke")
	assert_eq(smoke.size(), 1, "only the Fire part's firing puffed smoke")
	if smoke.size() == 1:
		assert_eq(int(smoke[0].data["count"]), 8, "8 smoke cells")
		var want := igniter.anchor_world() + igniter.facing() * 4.0
		var at: Vector2 = smoke[0].data["at"]
		assert_near(at.x, want.x, 0.001, "4 cells in front of the part that fired")
		assert_near(at.y, want.y, 0.001, "on its own line")
	_complete()


# U50: an enemy part's Slow gains 1 energy; the enemy hull's, an own part's, or another status gains
# none.
func test_turbine_gains_1_energy_for_an_enemy_slow() -> void:
	var ctx := await duel([[[7], &"turbine"]], [[[7], &"reinforced_frame"]], 60.0)
	var turbine := of(ctx, 0, &"turbine")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(turbine != null and foe != null, "both parts mounted")
	if turbine == null or foe == null:
		_complete()
		return
	var energy: ChEnergy = ctx.chariots[0].energy
	energy.value = 5.0
	ctx.give_status(foe, ChStatuses.SLOW, 2)
	assert_eq(energy.value, 6.0, "an enemy part's Slow gained 1 energy")
	# The row says enemy part, so the enemy hull's own Slow is not the enemy part's.
	ctx.give_status(ctx.chariots[1], ChStatuses.SLOW, 1)
	assert_eq(energy.value, 6.0, "an enemy body's Slow gains nothing")
	energy.value = 5.0
	ctx.give_status(turbine, ChStatuses.SLOW, 1)
	assert_eq(energy.value, 5.0, "an own Slow gains none")
	energy.value = 5.0
	ctx.give_status(foe, ChStatuses.BLOCK, 3)
	assert_eq(energy.value, 5.0, "and another status gains none")
	_complete()


# U51: 20 steam cells 6 cells in front.
func test_steam_vent_bursts_20_steam_6_ahead() -> void:
	var ctx := await duel([[[7], &"steam_vent"]], [], 60.0)
	var vent := of(ctx, 0, &"steam_vent")
	assert_true(vent != null, "the steam vent mounted")
	if vent == null:
		_complete()
		return
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	vent.cooldown_left = 0.0
	await step(ctx, TICK, true)
	var steam := _spawned(spawns, &"steam")
	assert_eq(steam.size(), 1, "one burst of steam")
	if steam.size() == 1:
		assert_eq(int(steam[0].data["count"]), 20, "20 steam cells")
		var want := vent.anchor_world() + vent.facing() * 6.0
		var at: Vector2 = steam[0].data["at"]
		assert_near(at.x, want.x, 0.001, "6 cells in front")
		assert_near(at.y, want.y, 0.001, "on the vent's line")
	_complete()


# U52: gases inside the L disc drift one cell a frame towards the enemy's x; gases outside stay.
func test_weather_vane_drifts_gases_sideways_toward_the_enemy() -> void:
	var ctx := await duel([[[7], &"weather_vane"]], [], 60.0)
	var vane := of(ctx, 0, &"weather_vane")
	assert_true(vane != null, "the weather vane mounted")
	if vane == null:
		_complete()
		return
	var anchor := Vector2i(roundi(vane.anchor_world().x), roundi(vane.anchor_world().y))
	var near := anchor + Vector2i(0, -10)
	var corner := anchor + Vector2i(30, -30)  # 42 cells out: inside the square, outside the disc
	var far := anchor + Vector2i(0, -40)
	ctx.world.set_cell(near, &"steam")
	ctx.world.set_cell(corner, &"steam")
	ctx.world.set_cell(far, &"steam")
	await step(ctx, TICK)
	assert_eq(ctx.world.get_material_at(near + Vector2i(1, 0)), &"steam",
		"the gas drifted one cell towards the enemy")
	assert_eq(ctx.world.get_material_at(near), &"air", "and left its old cell")
	assert_eq(ctx.world.get_material_at(corner), &"steam", "a cell outside the disc stays")
	assert_eq(ctx.world.get_material_at(far), &"steam", "and one past the range stays")
	# The mirrored vane faces the other way, so its gas drifts left, towards the player.
	var mirrored := await duel([], [[[7], &"weather_vane"]], 60.0)
	var foe_vane := of(mirrored, 1, &"weather_vane")
	assert_true(foe_vane != null, "the mirrored vane mounted")
	if foe_vane == null:
		_complete()
		return
	var foe_anchor := Vector2i(roundi(foe_vane.anchor_world().x), roundi(foe_vane.anchor_world().y))
	var foe_near := foe_anchor + Vector2i(0, -10)
	mirrored.world.set_cell(foe_near, &"steam")
	await step(mirrored, TICK)
	assert_eq(mirrored.world.get_material_at(foe_near - Vector2i(1, 0)), &"steam",
		"the mirrored vane drifts gas the other way")
	_complete()


# R23: a gas exactly 40 cells out moves onto the enemy hull; one at 41 stays where it is. The
# boundary is pinned on both sides, so any other RANGE fails.
func test_toxic_tempest_moves_gas_within_40_onto_the_enemy() -> void:
	var ctx := await duel([[[7], &"toxic_tempest"]], [], 60.0)
	var tempest := of(ctx, 0, &"toxic_tempest")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(tempest != null, "the toxic tempest mounted")
	if tempest == null:
		_complete()
		return
	var anchor := Vector2i(roundi(tempest.anchor_world().x), roundi(tempest.anchor_world().y))
	var near := anchor + Vector2i(0, -40)
	var far := anchor + Vector2i(0, -41)
	ctx.world.set_cell(near, &"smoke")
	ctx.world.set_cell(far, &"smoke")
	tempest.cooldown_left = 0.0
	await step(ctx, TICK, true)
	await step(ctx, 0.5)
	var hull := Rect2i(ChBattle.hull_box(foe)).grow(1)
	assert_true(_count(ctx, &"smoke", hull) > 0, "the gas exactly 40 cells out moved onto the enemy hull")
	assert_eq(ctx.world.get_material_at(far), &"smoke", "the gas 41 cells out stayed")
	_complete()


# R24: an enemy part's Slow gives every own part the same Speedup; an own Slow gives none.
func test_stormfront_gives_own_parts_the_enemy_slow_amount_as_speedup() -> void:
	var ctx := await duel([[[0], &"spare_cell"], [[6], &"stormfront"]],
		[[[7], &"reinforced_frame"]], 60.0)
	var front := of(ctx, 0, &"stormfront")
	var spare := of(ctx, 0, &"spare_cell")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(front != null and spare != null and foe != null, "all three parts mounted")
	if front == null or spare == null or foe == null:
		_complete()
		return
	ctx.give_status(foe, ChStatuses.SLOW, 3)
	assert_eq(spare.statuses.count(ChStatuses.SPEEDUP), 3, "the spare gained the 3 Slow as Speedup")
	assert_eq(front.statuses.count(ChStatuses.SPEEDUP), 3, "and the stormfront itself gained 3")
	# The row says enemy part, so the enemy hull's own Slow is not the enemy part's.
	var body_ctx := await duel([[[0], &"spare_cell"], [[6], &"stormfront"]],
		[[[7], &"reinforced_frame"]], 60.0)
	var body_spare := of(body_ctx, 0, &"spare_cell")
	assert_true(body_spare != null, "the body duel mounted")
	if body_spare == null:
		_complete()
		return
	body_ctx.give_status(body_ctx.chariots[1], ChStatuses.SLOW, 2)
	assert_eq(body_spare.statuses.count(ChStatuses.SPEEDUP), 0,
		"an enemy body's Slow gives no Speedup")
	# Our own Slow is not the enemy's.
	var own_ctx := await duel([[[0], &"spare_cell"], [[6], &"stormfront"]],
		[[[7], &"reinforced_frame"]], 60.0)
	var own_spare := of(own_ctx, 0, &"spare_cell")
	var own_front := of(own_ctx, 0, &"stormfront")
	assert_true(own_spare != null and own_front != null, "the own-Slow duel mounted")
	if own_spare == null or own_front == null:
		_complete()
		return
	own_ctx.give_status(own_spare, ChStatuses.SLOW, 1)
	assert_eq(own_spare.statuses.count(ChStatuses.SPEEDUP), 0, "our own Slow gives no Speedup")
	assert_eq(own_front.statuses.count(ChStatuses.SPEEDUP), 0, "to any own part")
	_complete()


# R24 bridge: the Smoke Bomb's smoke slows the enemy, and Stormfront turns that Slow into Speedup.
func test_stormfront_with_smoke_bomb() -> void:
	var ctx := await duel([[[0], &"spare_cell"], [[6], &"stormfront"], [[7], &"smoke_bomb"]],
		[[[7], &"reinforced_frame"]], 40.0)
	var spare := of(ctx, 0, &"spare_cell")
	var bomb := of(ctx, 0, &"smoke_bomb")
	assert_true(spare != null and bomb != null, "the bridge's parts mounted")
	if spare == null or bomb == null:
		_complete()
		return
	var gains := sink(ctx, ChEvent.STATUS_GAINED)
	bomb.cooldown_left = 0.0
	await step(ctx, TICK, true)
	assert_eq(ctx.chariots[1].statuses.count(ChStatuses.SLOW), 0, "no Slow before a status second")
	await step(ctx, 1.1)
	assert_true(ctx.chariots[1].statuses.count(ChStatuses.SLOW) > 0, "the smoke slowed the enemy")
	# The smoke can reach more than one enemy part, and every gain is its own trigger. The hull's own
	# Slow is not an enemy part's, so the Speedup counts only the parts' gains.
	var slowed := 0
	for event in gains:
		if event.side == 1 and event.source is ChPartRuntime \
				and event.data.get("status") == ChStatuses.SLOW:
			slowed += int(event.data.get("amount", 0))
	assert_true(slowed > 0, "an enemy part gained Slow")
	assert_eq(spare.statuses.count(ChStatuses.SPEEDUP), slowed,
		"and every stack of it came back as Speedup")
	_complete()
