extends ChPartTest

# Task 10: the Steam parts (U69-U72, R31) on the Task 1 RIG, one test per part, each asserting the
# number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn, the shooters aim at the far rig, and a
# projectile only flies on engine frames, so those tests pass frames = true. The passive and trigger
# tests are pure clock and stay synchronous.
# A part that reads a status the fight would decay is given it just before the press, so the number
# the row names is the number the hit reads.

func _spawned(spawns: Array, material: StringName) -> Array:
	var out: Array = []
	for event in spawns:
		if event.data.get("material") == material:
			out.append(event)
	return out


# U69: a straight shot that lays 10 water cells on the part it meets, then 6 fire cells on the same
# spot, where the sim's water and fire meet in steam.
func test_boiler_splashes_water_then_fire_on_the_part_hit() -> void:
	var ctx := await duel([[[6], &"strut"], [[6, 0], &"boiler"]],
		[[[0], &"strut"], [[0, 0], &"reinforced_frame"]], 60.0)
	var foe_part := of(ctx, 1, &"reinforced_frame")
	assert_true(foe_part != null, "the part on the enemy's strut mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 7.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not _spawned(spawns, &"fire").is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	var water := _spawned(spawns, &"water")
	var fire := _spawned(spawns, &"fire")
	assert_eq(water.size(), 1, "one splash of water")
	assert_eq(int(water[0].data["count"]), 10, "10 water cells")
	assert_eq(fire.size(), 1, "one burst of fire")
	assert_eq(int(fire[0].data["count"]), 6, "6 fire cells")
	var first_water := -1
	var first_fire := -1
	for i in spawns.size():
		var material: StringName = spawns[i].data.get("material")
		if material == &"water" and first_water < 0:
			first_water = i
		elif material == &"fire" and first_fire < 0:
			first_fire = i
	assert_true(first_water >= 0 and first_fire > first_water, "the water landed before the fire")
	_complete()


# U70: Flame put out on any holder gives every own Fire and Ice part 1 Speedup, and nothing to a part
# with neither tag.
func test_pressure_valve_speeds_own_fire_and_ice_parts() -> void:
	var ctx := await duel([[[5], &"spare_cell"], [[6], &"heat_shield"], [[7], &"pressure_valve"]],
		[[[0], &"reinforced_frame"]], 60.0)
	var valve := of(ctx, 0, &"pressure_valve")
	var shield := of(ctx, 0, &"heat_shield")
	var spare := of(ctx, 0, &"spare_cell")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(valve != null and shield != null and spare != null and foe != null, "all four parts mounted")
	ctx.give_status(foe, ChStatuses.WET, 2)
	ctx.give_status(foe, ChStatuses.FLAME, 3)
	assert_eq(valve.statuses.count(ChStatuses.SPEEDUP), 1,
		"the valve is Fire and Ice, so it gained 1 Speedup")
	assert_eq(shield.statuses.count(ChStatuses.SPEEDUP), 1, "and so did the Fire part beside it")
	assert_eq(spare.statuses.count(ChStatuses.SPEEDUP), 0, "the untagged neighbour gained none")
	# Freeze puts Flame out the same way.
	var frozen := await duel([[[5], &"spare_cell"], [[6], &"heat_shield"], [[7], &"pressure_valve"]],
		[[[0], &"reinforced_frame"]], 60.0)
	var frozen_foe := of(frozen, 1, &"reinforced_frame")
	var frozen_valve := of(frozen, 0, &"pressure_valve")
	assert_true(frozen_foe != null and frozen_valve != null, "the frozen duel mounted")
	frozen.give_status(frozen_foe, ChStatuses.FREEZE, 2)
	frozen.give_status(frozen_foe, ChStatuses.FLAME, 3)
	assert_eq(frozen_valve.statuses.count(ChStatuses.SPEEDUP), 1,
		"and a Freeze that put the Flame out did the same")
	_complete()


# U71: a straight shot that pays 30, then 12 frost cells on a part without Freeze, or 3 fire cells
# for each Freeze on a part that has it.
func test_thermal_shock_gun_30_damage_and_fire_on_a_frozen_part() -> void:
	var ctx := await duel([[[6], &"strut"], [[6, 0], &"thermal_shock_gun"]],
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
	assert_eq(int(hits[0].data["hp_damage"]), 30, "the shell pays 30")
	var frost := _spawned(spawns, &"frost")
	assert_eq(frost.size(), 1, "one burst of frost")
	assert_eq(int(frost[0].data["count"]), 12, "12 frost cells on a part without Freeze")
	# The same shot at a part that has Freeze bursts into fire instead.
	var frozen := await duel([[[6], &"strut"], [[6, 0], &"thermal_shock_gun"]],
		[[[0], &"strut"], [[0, 0], &"reinforced_frame"]], 60.0)
	var frozen_part := of(frozen, 1, &"reinforced_frame")
	var frozen_spawns := sink(frozen, ChEvent.CELLS_SPAWNED)
	assert_true(frozen_part != null, "the frozen duel mounted")
	await step(frozen, 7.1, false, false, 0.0, true)
	frozen.give_status(frozen_part, ChStatuses.FREEZE, 3)
	await step(frozen, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not _spawned(frozen_spawns, &"fire").is_empty():
			break
		await step(frozen, TICK, false, false, 0.0, true)
	var fire := _spawned(frozen_spawns, &"fire")
	assert_eq(fire.size(), 1, "one burst of fire")
	assert_eq(int(fire[0].data["count"]), 9, "3 Freeze gave 9 fire cells")
	_complete()


# U72: steam within the L range of its anchor turns to water at once, and steam past it does not.
func test_condenser_turns_nearby_steam_into_water() -> void:
	var ctx := await duel([[[7], &"condenser"]], [], 60.0)
	var condenser := of(ctx, 0, &"condenser")
	assert_true(condenser != null, "the condenser mounted")
	var at := Vector2i(roundi(condenser.anchor_world().x), roundi(condenser.anchor_world().y))
	var near := at + Vector2i(0, -10)
	var far := at + Vector2i(0, -40)
	ctx.world.set_cell(near, &"steam")
	ctx.world.set_cell(far, &"steam")
	await step(ctx, TICK)
	assert_eq(ctx.world.get_material_at(near), &"water", "steam within range turned to water")
	assert_eq(ctx.world.get_material_at(far), &"steam", "steam past the range stayed steam")
	_complete()


# R31: an enemy part's cancelled stacks cost it 5 damage each, and a cancel on our own part does not.
func test_steam_engine_5_damage_per_stack_cancelled_on_an_enemy_part() -> void:
	var ctx := await duel([[[6], &"spare_cell"], [[7], &"steam_engine"]],
		[[[0], &"reinforced_frame"]], 60.0)
	var engine := of(ctx, 0, &"steam_engine")
	var foe := of(ctx, 1, &"reinforced_frame")
	var own := of(ctx, 0, &"spare_cell")
	assert_true(engine != null and foe != null and own != null, "all three parts mounted")
	var hits := sink(ctx, ChEvent.HIT)
	ctx.give_status(foe, ChStatuses.WET, 2)
	ctx.give_status(foe, ChStatuses.FLAME, 3)
	assert_eq(hits.size(), 1, "the enemy part's cancel landed one hit")
	assert_eq(int(hits[0].data["hp_damage"]), 10, "5 for each of the 2 stacks cancelled")
	assert_eq(hits[0].data["target_part"], foe, "on the part that cancelled")
	# A cancel on our own part is not the enemy's.
	ctx.give_status(own, ChStatuses.WET, 1)
	ctx.give_status(own, ChStatuses.FLAME, 2)
	assert_eq(hits.size(), 1, "and our own part's cancel landed none")
	_complete()