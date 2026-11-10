extends ChTest

# Task 11: the closed pit every fight runs in. ChArenaBuilder.build lays the arena's layers into
# ChTest's world (arena 480x180, concrete border) and hands back the two spawn points.
# The fills want a loaded world, so every test is world-backed like Tasks 9/10's.

const ARENA := Rect2i(0, 0, 480, 180)
const SPAWN_LEFT_X := 170
const SPAWN_RIGHT_X := 309
const ABOVE_SURFACE := 30
# Everything the builder puts in the ground: a column is solid from its first one down.
const TERRAIN := [&"concrete", &"rock", &"sand", &"wood", &"water", &"lava", &"tnt", &"gunpowder", &"acid", &"oil"]
const LIQUIDS := [&"water", &"oil", &"acid", &"lava"]


func _surface_y(world: PixelWorld, x: int) -> int:
	# The column's first terrain cell; ARENA.end.y means the column never closes.
	for y in range(ARENA.position.y, ARENA.end.y):
		if world.get_material_at(Vector2i(x, y)) in TERRAIN:
			return y
	return ARENA.end.y


func _spawn_x(spawn: Dictionary, key: String) -> int:
	# The spawn dict is keyed by side; a missing key reads as a failure, not a crash.
	assert_true(key in spawn, "the build answers %s" % key)
	if not (key in spawn):
		return -1
	var at: Vector2 = spawn[key]
	assert_true(is_finite(at.x) and is_finite(at.y), "%s is a real point" % key)
	return int(at.x)


func test_walls_concrete_and_indestructible() -> void:
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	# Task 2's ruling: a blast wholly inside a solid fill proves nothing about the border, so this
	# one sits at x = 2, straddling the arena's left edge, under the sand.
	# explode answers the cells it removed: the blast really has to dig.
	var removed := world.explode(Vector2i(2, 120), 10, 300)
	assert_true(removed > 0, "the blast at the wall removed cells")
	# The sim gets two ticks to try to collapse the pit onto the wall.
	world.step(2)
	assert_eq(world.get_material_at(Vector2i(-1, 120)), &"concrete", "the left border is still concrete")
	world.free()
	_complete()


func test_layers_present() -> void:
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	# count_materials keys its counts by material name and always carries the burning key.
	var counts: Dictionary = world.count_materials(ARENA)
	for material in [&"sand", &"rock", &"lava"]:
		assert_true(counts.get(material, 0) > 0, "%s cells laid in the arena" % material)
	world.free()
	_complete()


func test_no_caves() -> void:
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	# The pit is packed: from a column's first terrain cell down to the arena floor the only
	# non-terrain cells are the water and lava pools sunk into it, never air.
	var holes := 0
	for x in range(ARENA.position.x, ARENA.end.x):
		var top := _surface_y(world, x)
		# The column has to close somewhere, or a chariot falls through the arena floor.
		assert_true(top < ARENA.end.y, "column %d holds terrain" % x)
		holes += _air_below(world, x, top)
	assert_eq(holes, 0, "air cells under the surface line (caves)")
	world.free()
	_complete()


func _air_below(world: PixelWorld, x: int, top: int) -> int:
	var holes := 0
	for y in range(top, ARENA.end.y):
		if not (world.get_material_at(Vector2i(x, y)) in TERRAIN):
			holes += 1
	return holes


func test_spawns_above_surface() -> void:
	var world: PixelWorld = await make_world()
	var spawn: Dictionary = ChArenaBuilder.build(world, 12345)
	var left_x := _spawn_x(spawn, "spawn_left")
	var right_x := _spawn_x(spawn, "spawn_right")
	assert_eq(left_x, SPAWN_LEFT_X, "spawn_left stands at %d" % SPAWN_LEFT_X)
	assert_eq(right_x, SPAWN_RIGHT_X, "spawn_right stands at %d" % SPAWN_RIGHT_X)
	# Each spawn hangs in the air 30 cells above its own column's surface, so a chariot dropped
	# there falls through air, not through rock onto the concrete border (Task 9's tunneling).
	assert_eq(_spawn_y(spawn, "spawn_left"), _surface_y(world, SPAWN_LEFT_X) - ABOVE_SURFACE,
		"spawn_left is 30 cells above its surface")
	assert_eq(_spawn_y(spawn, "spawn_right"), _surface_y(world, SPAWN_RIGHT_X) - ABOVE_SURFACE,
		"spawn_right is 30 cells above its surface")
	world.free()
	_complete()


func _spawn_y(spawn: Dictionary, key: String) -> int:
	if not (key in spawn):
		return -1
	return int((spawn[key] as Vector2).y)


func test_arena_is_mirrored() -> void:
	# One hand-designed arena, mirrored about x 239.5, so neither side starts with the better ground.
	for rng_seed in [12345, 7]:
		var world: PixelWorld = await make_world()
		ChArenaBuilder.build(world, rng_seed)
		var mismatched := 0
		for x in range(ChArenaBuilder.MIRROR_X):
			for y in range(ARENA.position.y, ARENA.end.y):
				if world.get_material_at(Vector2i(x, y)) != world.get_material_at(Vector2i(479 - x, y)):
					mismatched += 1
		assert_eq(mismatched, 0, "seed %d: cells that differ from their mirror" % rng_seed)
		world.free()
	_complete()


func test_set_pieces_present() -> void:
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	var counts: Dictionary = world.count_materials(ARENA)
	assert_true(counts.get(&"tnt", 0) >= 72, "two 6x6 TNT crates (%d cells)" % counts.get(&"tnt", 0))
	for material in [&"gunpowder", &"acid", &"oil"]:
		assert_true(counts.get(material, 0) > 0, "%s laid in the arena" % material)
	# The lava sits under a crust in the middle, close enough that a dig reaches it.
	var top := _surface_y(world, 240)
	var lava := false
	for y in range(top, top + 9):
		if world.get_material_at(Vector2i(240, y)) == &"lava":
			lava = true
	assert_true(lava, "lava within 8 cells under the surface at x 240")
	world.free()
	_complete()


func test_no_deep_liquid_on_driving_line() -> void:
	# A chassis floats on liquid it covers (physics.cpp apply_buoyancy), so the driving line never
	# holds a pool two cells deep from the surface down.
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	var deep := []
	for x in range(140, 341):
		var y := _surface_y(world, x)
		var run := 0
		while y < ARENA.end.y and world.get_material_at(Vector2i(x, y)) in LIQUIDS:
			run += 1
			y += 1
		if run >= 2:
			deep.append(x)
	assert_eq(deep, [], "driving-line columns with liquid 2+ deep at the surface")
	world.free()
	_complete()


func test_nothing_explodes_on_its_own() -> void:
	# Nothing goes off unless a shot, flame, blast or dig reaches it: 600 idle ticks set off no
	# explosive (the lava stays under its crust, the gunpowder stays cold).
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	var went_off := []
	for i in range(60):
		world.step(10)
		for blast in world.take_blasts():
			if blast["material"] in [&"tnt", &"gunpowder"]:
				went_off.append(blast)
	assert_eq(went_off, [], "explosives that went off with nobody near them")
	world.free()
	_complete()


func test_lit_seam_sets_off_its_crate() -> void:
	# The spec's fuse: a lit seam walks to its TNT crate. A 1-cell blast on the seam's far end
	# (x 150, the spawn side) lights it; the chain has to reach the crate at x 118-123.
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	world.take_blasts()
	var y := _surface_y(world, 150) + 2
	assert_eq(world.get_material_at(Vector2i(150, y)), &"gunpowder", "the seam's far end is gunpowder")
	world.explode(Vector2i(150, y), 1, 50)
	var tnt := false
	for i in range(60):  # 600 ticks, 10 s
		world.step(10)
		if world.take_blasts().any(func(b): return b["material"] == &"tnt"):
			tnt = true
			break
	assert_true(tnt, "the lit seam set off its crate within 600 ticks")
	world.free()
	_complete()
