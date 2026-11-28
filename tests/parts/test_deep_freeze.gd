extends ChPartTest

# Task 9: the Deep Freeze parts (U07-U13, R04-R06) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn, the shooters aim at the far rig, and a
# projectile only flies on engine frames, so those tests pass frames = true. The passive and trigger
# tests are pure clock and stay synchronous.
# A part that reads a status the fight would decay is given it just before the press, so the number
# the row names is the number the hit reads.

func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))

func _spawned(spawns: Array, material: StringName) -> Array:
	var out: Array = []
	for event in spawns:
		if event.data.get("material") == material:
			out.append(event)
	return out


# U07: a 3 s rain cloud that drops 4 water particles a tick above the enemy.
func test_rainmaker_rains_water_on_the_enemy() -> void:
	var ctx := await duel([[[7], &"rainmaker"]], [], 60.0)
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_true(int(ctx.world.get_stats()["particles_material"]) >= 4,
		"the cloud's first tick pooled 4 water particles")
	await step(ctx, 2.5, false, false, 0.0, true)
	assert_true(_count(ctx, &"water", Rect2i(150, 100, 140, 60)) > 0,
		"and the rain left water above the enemy")
	# The cloud runs 3 s: after it the pool only ever loses particles.
	await step(ctx, 0.7, false, false, 0.0, true)
	var stopped: int = int(ctx.world.get_stats()["particles_material"])
	await step(ctx, 0.6, false, false, 0.0, true)
	assert_true(int(ctx.world.get_stats()["particles_material"]) <= stopped,
		"and no new drops after the 3 s")
	_complete()


# U08: a straight shot that pays 40 and bursts into 8 frost cells, 16 on a Wet part.
func test_cryo_cannon_40_damage_and_double_frost_on_wet() -> void:
	var ctx := await duel([[[6], &"strut"], [[6, 0], &"cryo_cannon"]],
		[[[0], &"strut"], [[0, 0], &"reinforced_frame"]], 60.0)
	var foe_part := of(ctx, 1, &"reinforced_frame")
	assert_true(foe_part != null, "the part on the enemy's strut mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 7.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the shell landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 40, "the shell pays 40")
	assert_eq(_spawned(spawns, &"frost").size(), 1, "it burst into frost once")
	assert_eq(int(_spawned(spawns, &"frost")[0].data["count"]), 8, "8 frost cells on a dry part")
	var wet := await duel([[[6], &"strut"], [[6, 0], &"cryo_cannon"]],
		[[[0], &"strut"], [[0, 0], &"reinforced_frame"]], 60.0)
	var wet_part := of(wet, 1, &"reinforced_frame")
	var wet_spawns := sink(wet, ChEvent.CELLS_SPAWNED)
	await step(wet, 7.1, false, false, 0.0, true)
	wet.give_status(wet_part, ChStatuses.WET, 3)
	await step(wet, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not _spawned(wet_spawns, &"frost").is_empty():
			break
		await step(wet, TICK, false, false, 0.0, true)
	assert_eq(int(_spawned(wet_spawns, &"frost")[0].data["count"]), 16,
		"and twice as many on a Wet part")
	_complete()


# U09: 100 on the body, and an enemy holder's Freeze gives this 1 Speedup.
func test_icebreaker_100_damage_and_speedup_on_enemy_freeze() -> void:
	var ctx := await duel([[[7], &"icebreaker"]], [], 20.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 7.1)
	await step(ctx, TICK, true)
	assert_eq(hits.size(), 1, "the breaker landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 100, "the breaker pays 100")
	var breaker := of(ctx, 0, &"icebreaker")
	ctx.give_status(foe, ChStatuses.FREEZE, 1)
	assert_eq(breaker.statuses.count(ChStatuses.SPEEDUP), 1,
		"the enemy body's Freeze gave it 1 Speedup")
	_complete()


# U10: own parts within range lose Freeze twice as fast; the coat itself does not.
func test_antifreeze_coat_doubles_own_freeze_decay() -> void:
	var ctx := await duel([[[6], &"antifreeze_coat"], [[7], &"spare_cell"]], [], 60.0)
	ctx.setup_all()
	var coat := of(ctx, 0, &"antifreeze_coat")
	var neighbour := of(ctx, 0, &"spare_cell")
	assert_true(coat != null and neighbour != null, "both parts mounted")
	ctx.give_status(coat, ChStatuses.FREEZE, 5)
	ctx.give_status(neighbour, ChStatuses.FREEZE, 5)
	await step(ctx, 2.1)
	assert_eq(neighbour.statuses.count(ChStatuses.FREEZE), 1,
		"the neighbour lost 2 Freeze a second")
	assert_eq(coat.statuses.count(ChStatuses.FREEZE), 3, "the coat itself lost 1 a second")
	_complete()


# U11: frost on the enemy part with the most Wet, or on the hull when nothing is Wet.
func test_cold_snap_targets_the_wettest_enemy_part() -> void:
	var ctx := await duel([[[7], &"cold_snap"]],
		[[[0], &"reinforced_frame"], [[2], &"spare_cell"]], 60.0)
	var wettest := of(ctx, 1, &"reinforced_frame")
	var drier := of(ctx, 1, &"spare_cell")
	assert_true(wettest != null and drier != null, "both enemy parts mounted")
	ctx.give_status(wettest, ChStatuses.WET, 3)
	ctx.give_status(drier, ChStatuses.WET, 1)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 6.1)
	await step(ctx, TICK, true)
	var frost := _spawned(spawns, &"frost")
	assert_eq(frost.size(), 1, "one burst of frost")
	assert_true(Vector2(frost[0].data["at"]).distance_to(wettest.anchor_world()) < 0.1,
		"on the part with the most Wet")
	assert_eq(int(frost[0].data["count"]), 10, "10 frost cells")
	var dry := await duel([[[7], &"cold_snap"]], [[[0], &"reinforced_frame"]], 60.0)
	var dry_spawns := sink(dry, ChEvent.CELLS_SPAWNED)
	await step(dry, 6.1)
	await step(dry, TICK, true)
	var dry_frost := _spawned(dry_spawns, &"frost")
	assert_eq(dry_frost.size(), 1, "one burst with nothing Wet")
	var hull: ChChariotRuntime = dry.chariots[1]
	assert_true(Vector2(dry_frost[0].data["at"]).distance_to(hull.anchor_world()) < 0.1,
		"and it fell on the enemy hull")
	_complete()


# U12: no damage, frost along the beam while it runs, and water the moment it switches on.
func test_freeze_ray_sprays_water_on_switch_on_and_frost_while_running() -> void:
	var ctx := await duel([[[7], &"freeze_ray"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true, 0.0, true)
	assert_eq(foe.hp, before, "the ray deals no damage")
	assert_true(_count(ctx, &"water", Rect2i(180, 100, 80, 60)) > 0,
		"switching on sprayed water at the target")
	# The switch-on burst lands on the same spot as the first frost, and water is what a spawn may
	# overwrite, so the frost is read on the next second's tick rather than on the switch-on frame.
	await step(ctx, 1.1, false, true, 0.0, true)
	assert_true(_count(ctx, &"frost", Rect2i(180, 100, 80, 60)) > 0,
		"and the running beam frosts what it reaches")
	_complete()


# U13: a neighbouring weapon's hit gets +25 on a frozen holder.
func test_ice_scope_25_more_on_a_frozen_target() -> void:
	var ctx := await duel([[[6], &"ice_scope"], [[7], &"chainsaw"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 15, "the saw's 15 on a warm hull")
	var frozen := await duel([[[6], &"ice_scope"], [[7], &"chainsaw"]], [], 60.0)
	var frozen_foe: ChChariotRuntime = frozen.chariots[1]
	frozen.give_status(frozen_foe, ChStatuses.FREEZE, 1)
	var frozen_before := frozen_foe.hp
	await step(frozen, TICK, false, true)
	assert_eq(frozen_before - frozen_foe.hp, 40, "and 40 on a frozen one")
	_complete()


# R04: damage on the enemy body equal to 3 times the enemy's Freeze, parts and body together.
func test_absolute_zero_3_times_the_enemys_freeze() -> void:
	var ctx := await duel([[[7], &"absolute_zero"]], [[[0], &"spare_cell"]], 20.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var part := of(ctx, 1, &"spare_cell")
	assert_true(part != null, "the enemy part mounted")
	await step(ctx, 6.1)
	ctx.give_status(foe, ChStatuses.FREEZE, 4)
	ctx.give_status(part, ChStatuses.FREEZE, 3)
	var before := foe.hp
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 21, "3 for each of the enemy's 7 Freeze")
	_complete()


# R05: an enemy part that is Wet keeps its Freeze.
func test_permafrost_stops_freeze_decay_on_wet_enemy_parts() -> void:
	var ctx := await duel([[[7], &"permafrost"]],
		[[[0], &"reinforced_frame"], [[2], &"spare_cell"]], 60.0)
	ctx.setup_all()
	var wet := of(ctx, 1, &"reinforced_frame")
	var dry := of(ctx, 1, &"spare_cell")
	assert_true(wet != null and dry != null, "both enemy parts mounted")
	ctx.give_status(wet, ChStatuses.FREEZE, 5)
	ctx.give_status(wet, ChStatuses.WET, 5)
	ctx.give_status(dry, ChStatuses.FREEZE, 5)
	await step(ctx, 2.1)
	assert_eq(wet.statuses.count(ChStatuses.FREEZE), 5, "the Wet part kept its Freeze")
	assert_eq(dry.statuses.count(ChStatuses.FREEZE), 3, "and the dry one lost 1 a second")
	_complete()


# R06: an enemy part's Freeze puts 3 frost cells on it and on every part it touches.
func test_glacier_engine_spreads_frost_to_touching_parts() -> void:
	var ctx := await duel([[[7], &"glacier_engine"]],
		[[[0], &"reinforced_frame"], [[1], &"spare_cell"]], 60.0)
	var frozen := of(ctx, 1, &"reinforced_frame")
	var neighbour := of(ctx, 1, &"spare_cell")
	assert_true(frozen != null and neighbour != null, "both enemy parts mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	ctx.give_status(frozen, ChStatuses.FREEZE, 1)
	var frost := _spawned(spawns, &"frost")
	assert_eq(frost.size(), 1 + ctx.touching(frozen).size(),
		"frost on the part and on every part it touches")
	for event in frost:
		assert_eq(int(event.data["count"]), 3, "3 frost cells each")
	var at: Array = []
	for event in frost:
		at.append(Vector2(event.data["at"]))
	assert_true(at.has(frozen.anchor_world()), "one patch on the frozen part")
	assert_true(at.has(neighbour.anchor_world()), "and one on the part it touches")
	_complete()


# Review Focus 4: the engine fires once a second for 10 s without running away.
func test_glacier_engine_runs_10s() -> void:
	var ctx := await duel([[[7], &"glacier_engine"]], [[[0], &"reinforced_frame"]], 60.0)
	var frozen := of(ctx, 1, &"reinforced_frame")
	assert_true(frozen != null, "the enemy part mounted")
	await step(ctx, 5.1)
	ctx.give_status(frozen, ChStatuses.FREEZE, 1)
	await step(ctx, 10.0)
	assert_true(frozen.statuses.count(ChStatuses.FREEZE) > 0, "the part is still frozen")
	assert_true(_count(ctx, &"frost", Rect2i(180, 100, 140, 70)) < 500,
		"and the frost it keeps making stays bounded")
	_complete()