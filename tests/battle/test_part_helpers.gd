extends ChTest

# Task 4: the sim and weapon helpers later parts call — spawn, throw_sparks/discharge, dig, blow and
# the projectile helpers on ChBehaviour. Fake part bodies in a real world, as test_sparks.gd builds
# them; the projectile test awaits physics frames, as the ranged suite does.

const ROW := 150  # the row a strip runs along
const SEED := Vector2i(40, ROW)
const FAR_BODY := Vector2(300, 20)  # chariot bodies sit up here, away from every strip


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


# A stat double that doubles spawn_fire, wired the way setup_all wires a real behaviour.
class DoubleSpawn:
	extends RefCounted

	var part: ChPartRuntime = null

	func setup(ctx) -> void: pass

	func modify_stat(ctx, target, stat, value) -> float:
		if stat == &"spawn_fire":
			return value * 2.0
		return value


func _part(side: int, at: Vector2, size := Vector2i(2, 2)) -> ChPartRuntime:
	var p := ChPartRuntime.new()
	p.def = ChPartDef.new()
	p.def.size = size
	p.side = side
	p.integrity = 500
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


func _shock(holder: Object) -> int:
	return holder.statuses.count(ChStatuses.SHOCK)


func test_spawn_fills_air_only() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(100, 100, 4, 12), &"rock")
	var ctx := _ctx(world, [])
	var source := _part(0, Vector2(90, 105))
	var written: int = ctx.spawn(source, &"fire", Vector2(97, 105), 10)
	assert_eq(written, 10, "ten cells written")
	assert_eq(world.get_material_at(Vector2i(100, 105)), &"rock", "the rock wall stays")
	assert_eq(world.get_material_at(Vector2i(101, 105)), &"rock", "and its neighbour")
	assert_eq(world.count_materials(Rect2i(90, 95, 20, 20)).get(&"fire", 0), 10, "ten fire cells")
	_complete()


func test_spawn_counts_through_stat() -> void:
	var world: PixelWorld = await make_world()
	var source := _part(0, Vector2(90, 105))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [source])])
	var double := DoubleSpawn.new()
	double.part = source
	source.behaviour = double
	var heard: Array[ChEvent] = []
	var sink := heard
	ctx.bus.subscribe(self, ChEvent.CELLS_SPAWNED, func(e: ChEvent): sink.append(e))
	ctx.setup_all()
	var written: int = ctx.spawn(source, &"fire", Vector2(97, 105), 5)
	assert_eq(written, 10, "the stat doubled 5 into 10")
	assert_eq(heard.size(), 1, "one CELLS_SPAWNED")
	assert_eq(heard[0].data["count"], 10, "the event carries the written count")
	assert_eq(heard[0].data["material"], &"fire", "and the material")
	_complete()


func test_spawned_gunpowder_is_owned() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [])])
	var source := _part(0, Vector2(90, 100))
	assert_eq(ctx.spawn(source, &"gunpowder", Vector2(100, 100), 9), 9, "nine gunpowder cells")
	assert_true(world.ignite(Vector2i(100, 100)), "the centre cell lit")
	var blasts: Array = []
	for i in 300:
		world.step(1)
		blasts = world.take_blasts()
		if not blasts.is_empty():
			break
	assert_true(not blasts.is_empty(), "the gunpowder went off")
	var explosions: Array[ChEvent] = []
	var sink := explosions
	ctx.bus.subscribe(self, ChEvent.EXPLOSION, func(e: ChEvent): sink.append(e))
	ctx.hazards.apply(ctx, blasts)
	assert_true(explosions.size() > 0, "an EXPLOSION was emitted")
	for e in explosions:
		assert_eq(e.side, 0, "owned by side 0")
	_complete()


func test_spawned_battery_sparks() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [p])])
	var source := _part(0, Vector2(90, ROW))
	assert_eq(ctx.spawn(source, &"battery", Vector2(100, ROW), 4), 4, "four battery cells")
	ctx._status_second()
	assert_eq(_shock(p), 1, "the part in the battery gains 2 and decays 1")
	_complete()


func test_throw_sparks_shocks_the_holder_there() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(SEED.x, ROW, 101 - SEED.x + 1, 1), &"water")
	var wet := _part(0, Vector2(100, ROW))
	var dry := _part(0, Vector2(200, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [wet, dry])])
	var source := _part(0, Vector2(90, ROW))
	var shocked: Array = ctx.throw_sparks(source, Vector2(100, ROW))
	assert_eq(_shock(wet), 2, "the part in the water gains 2 Shock")
	assert_eq(_shock(dry), 0, "the dry part gains none")
	assert_eq(shocked, [wet], "answers the holders shocked")
	_complete()


func test_discharge_first_only_stops_at_one() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(SEED.x, ROW, 101 - SEED.x + 1, 1), &"water")
	var near := _part(0, Vector2(60, ROW))
	var far := _part(0, Vector2(100, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [near, far])])
	var shocked: Array = ChSparks.discharge(ctx, [SEED] as Array[Vector2i], true, 1, true)
	assert_eq(shocked.size(), 1, "only the first holder reached")
	assert_eq(_shock(near), 2, "the near part is shocked")
	assert_eq(_shock(far), 0, "the far part is not")
	_complete()


func test_discharge_hops_reach_two_parts() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(SEED.x, ROW, 101 - SEED.x + 1, 1), &"water")
	var first := _part(0, Vector2(100, ROW))
	var second := _part(0, Vector2(102, ROW))
	var ctx := _ctx(world, [_chariot(0, FAR_BODY, [first, second])])
	var jumps: Array[ChEvent] = []
	var sink := jumps
	ctx.bus.subscribe(self, ChEvent.SHOCK_JUMPED, func(e: ChEvent): sink.append(e))
	# first_only leaves the second part to the hop alone, so the jump is the only way it is reached.
	ChSparks.discharge(ctx, [SEED] as Array[Vector2i], true, 1, true)
	assert_eq(_shock(first), 2, "the first part is shocked directly")
	assert_eq(_shock(second), 1, "the hop reached the second part")
	assert_eq(jumps.size(), 1, "one jump")
	assert_eq(jumps[0].data["amount"], 1, "half of the 2 Shock")
	_complete()


func test_dig_respects_hardness() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(100, 100, 3, 3), &"sand")
	world.fill_rect(Rect2i(104, 100, 3, 3), &"steel")
	world.fill_rect(Rect2i(104, 104, 3, 3), &"concrete")
	var ctx := _ctx(world, [])
	var dug: Array[ChEvent] = []
	var sink := dug
	ctx.bus.subscribe(self, ChEvent.CELLS_DUG, func(e: ChEvent): sink.append(e))
	# A blast leaves a gas cell in the crater, so the non-air count can be one short of the nine dug.
	var removed: int = ctx.dig(Vector2i(102, 102), 6, 5)
	assert_true(removed == 8 or removed == 9, "the nine sand cells, less any gas the blast left")
	assert_eq(world.count_materials(Rect2i(100, 100, 3, 3)).get(&"sand", 0), 0, "sand gone")
	assert_eq(world.count_materials(Rect2i(104, 100, 3, 3)).get(&"steel", 0), 9, "steel (7) stays at 5")
	assert_eq(dug.size(), 1, "one CELLS_DUG")
	assert_eq(dug[0].data["count"], removed, "the event carries the count")
	var after: int = ctx.dig(Vector2i(102, 102), 6, 9)
	assert_true(after == 8 or after == 9, "hardness 9 takes the steel")
	assert_eq(world.count_materials(Rect2i(104, 100, 3, 3)).get(&"steel", 0), 0, "steel gone")
	assert_eq(world.count_materials(Rect2i(104, 104, 3, 3)).get(&"concrete", 0), 9,
		"concrete stays at 9")
	_complete()


func test_blow_moves_smoke_not_sand() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(100, 100, 1, 1), &"smoke")
	world.fill_rect(Rect2i(104, 100, 1, 1), &"sand")
	var ctx := _ctx(world, [])
	assert_eq(ctx.blow(Rect2i(100, 100, 5, 1), Vector2i(3, 0)), 1, "one gas cell moved")
	assert_eq(world.get_material_at(Vector2i(100, 100)), &"air", "the smoke left")
	assert_eq(world.get_material_at(Vector2i(103, 100)), &"smoke", "three cells along")
	assert_eq(world.get_material_at(Vector2i(104, 100)), &"sand", "the sand stayed")
	_complete()


func test_projectile_with_no_target_expires() -> void:
	var world: PixelWorld = await make_world()
	var ctx := _ctx(world, [])
	var source := _part(0, Vector2(100, 100))
	var fired: Array = []
	var behaviour := ChBehaviour.new()
	behaviour.part = source
	var bolt: ChProjectile = behaviour._shoot(ctx, 100.0, 0.0,
		func(_shot: Dictionary): fired.append(1))
	assert_true(bolt != null, "the shot launched")
	bolt.life = ChProjectile.LIFE
	for i in 3:
		await Engine.get_main_loop().physics_frame
	assert_true(not is_instance_valid(bolt), "the bolt freed itself")
	assert_eq(fired.size(), 0, "no impact without a target")
	_complete()