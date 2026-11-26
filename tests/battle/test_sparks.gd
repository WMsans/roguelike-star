extends ChTest

# Sparks through water and steel, batteries that spark every status second and leak acid when broken,
# and Shock's own sparks, which light explosives but shock nobody. Fake part bodies in a real world,
# as test_status_second.gd builds them.

const ROW := 150  # the row a strip runs along
const SEED := Vector2i(40, ROW)
const FAR_BODY := Vector2(300, 20)  # chariot bodies sit up here, away from every strip


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


func _part(side: int, at: Vector2, integrity := 500) -> ChPartRuntime:
	var p := ChPartRuntime.new()
	p.def = ChPartDef.new()
	p.def.size = Vector2i(2, 2)
	p.side = side
	p.integrity = integrity
	p.body = FakeBody.new()
	p.body.global_position = at
	return p


func _chariot(side: int, at: Vector2, parts: Array, hp := 1000) -> ChChariotRuntime:
	var c := ChChariotRuntime.new()
	c.side = side
	c.hp = hp
	c.body_def = ChBodyDef.new()
	c.body_def.size = Vector2i(4, 4)
	c.energy = ChEnergy.new(0, 0)
	c.chassis = _track(PixelRigidBody.new())
	c.chassis.position = at
	for p in parts:
		c.parts.append(p)
	return c


func _ctx(world: PixelWorld, chariots: Array) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.bus = ChEventBus.new()
	ctx.world = world
	for c in chariots:
		ctx.chariots.append(c)
	return ctx


func _blasts_within(world: PixelWorld, material: StringName, ticks: int) -> bool:
	# Steps the world until a blast of `material` is queued, at most `ticks` ticks.
	for i in ticks:
		world.step(1)
		for b in world.take_blasts():
			if b["material"] == material:
				return true
	return false


func _shock(holder: Object) -> int:
	return holder.statuses.count(ChStatuses.SHOCK)


# A conductor strip from SEED to x 101, a part at its far end (sample rect 97..102) and one on dry
# ground. `gap` puts one sand cell in the strip.
func _strip(conductor: StringName, gap := false) -> Dictionary:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(SEED.x, ROW, 101 - SEED.x + 1, 1), conductor)
	if gap:
		world.fill_rect(Rect2i(70, ROW, 1, 1), &"sand")
	var wet := _part(0, Vector2(100, ROW))
	var dry := _part(0, Vector2(200, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [wet, dry])])
	return {"world": world, "ctx": ctx, "wet": wet, "dry": dry}


func test_spark_through_water_shocks_a_part_in_it() -> void:
	var f := await _strip(&"water")
	var shocked: Array = ChSparks.discharge(f.ctx, [SEED] as Array[Vector2i])
	assert_eq(_shock(f.wet), 2, "the part in the water gains 2 Shock")
	assert_eq(_shock(f.dry), 0, "the part on dry ground gains none")
	assert_eq(shocked, [f.wet], "answers the holders shocked")
	_complete()


func test_spark_through_steel() -> void:
	var f := await _strip(&"steel")
	ChSparks.discharge(f.ctx, [SEED] as Array[Vector2i])
	assert_eq(_shock(f.wet), 2, "the part on the rail gains 2 Shock")
	assert_eq(_shock(f.dry), 0, "the part on dry ground gains none")
	_complete()


func test_spark_does_not_cross_air_or_sand() -> void:
	var f := await _strip(&"water", true)
	ChSparks.discharge(f.ctx, [SEED] as Array[Vector2i])
	assert_eq(_shock(f.wet), 0, "sand stops the spark")
	_complete()


func test_spark_shocks_each_holder_once() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, ROW))
	assert_eq(world.fill_rect(Rect2i(97, 148, 6, 5), &"water"), 30, "30 water cells in the part's rect")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [p])])
	ChSparks.discharge(ctx, [Vector2i(97, 148)] as Array[Vector2i])
	assert_eq(_shock(p), 2, "2 Shock however many reached cells it holds")
	_complete()


func test_spark_lights_gunpowder_and_tnt() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	world.fill_rect(Rect2i(SEED.x, 159, 41, 1), &"steel")  # the rail ends at x 80
	world.fill_rect(Rect2i(81, 152, 6, 8), &"gunpowder")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [])])
	ChSparks.discharge(ctx, [Vector2i(SEED.x, 159)] as Array[Vector2i])
	assert_true(_blasts_within(world, &"gunpowder", 300), "a gunpowder blast within 300 ticks")
	_complete()


func test_spark_flood_is_capped() -> void:
	var world: PixelWorld = await make_world()
	assert_eq(world.fill_rect(Rect2i(20, ROW, 420, 2), &"water"), 840, "more water than MAX_CELLS")
	var near := _part(0, Vector2(25, ROW))
	var far := _part(0, Vector2(435, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [near, far])])
	ChSparks.discharge(ctx, [Vector2i(20, ROW)] as Array[Vector2i])
	assert_eq(_shock(near), 2, "the part beside the seed is shocked")
	assert_eq(_shock(far), 0, "the far end is past the cap")
	_complete()


func test_battery_sparks_every_second() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, ROW))  # sample rect x 97..102
	world.fill_rect(Rect2i(101, 148, 3, 4), &"battery")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [p])])
	ctx.sparks.add_battery(ctx, Rect2i(101, 148, 3, 4))
	ctx._status_second()
	assert_eq(_shock(p), 1, "gains 2, decays 1")
	ctx._status_second()
	assert_eq(_shock(p), 2, "gains 2 again, net of decay")
	_complete()


func test_broken_battery_leaks_acid() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(200, 150, 4, 4), &"battery")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [])])
	ctx.sparks.add_battery(ctx, Rect2i(200, 150, 4, 4))
	world.set_cell(Vector2i(200, 150), &"air")
	world.set_cell(Vector2i(203, 153), &"air")
	ctx._status_second()
	assert_eq(world.get_material_at(Vector2i(200, 150)), &"acid", "the first broken cell leaks acid")
	assert_eq(world.get_material_at(Vector2i(203, 153)), &"acid", "the second too")
	assert_eq(world.get_material_at(Vector2i(201, 151)), &"battery", "the rest is still battery")
	_complete()


func test_shock_status_lights_but_does_not_shock() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	world.fill_rect(Rect2i(90, 158, 20, 2), &"water")  # x 90..109
	world.fill_rect(Rect2i(110, 158, 2, 2), &"gunpowder")  # the rim, outside both rects
	var mine := _part(0, Vector2(98, 157))
	var theirs := _part(1, Vector2(103, 157))
	mine.statuses.stacks[ChStatuses.SHOCK] = 5
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [mine]), _chariot(1, Vector2(400, 20), [theirs])])
	for i in 10:
		ctx._status_second()
	assert_eq(_shock(mine), 0, "the shocked part decayed to 0")
	assert_eq(_shock(theirs), 0, "the other side was never shocked")
	assert_true(_blasts_within(world, &"gunpowder", 300), "the rim's gunpowder was lit")
	_complete()


func test_spark_arc_is_visible() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	world.fill_rect(Rect2i(100, 158, 10, 2), &"water")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [])])
	ChSparks.discharge(ctx, [Vector2i(100, 158)] as Array[Vector2i])
	var around := Rect2i(90, 145, 30, 15)
	assert_true(world.count_materials(around).get(&"spark", 0) > 0, "spark cells over the water")
	world.step(30)
	assert_eq(world.count_materials(around).get(&"spark", 0), 0, "gone after 30 ticks")
	_complete()
