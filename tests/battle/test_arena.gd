extends ChTest

# Task 11: the closed pit every fight runs in. ChArenaBuilder.build lays the arena's layers into
# ChTest's world (arena 480x180, concrete border) and hands back the two spawn points.
# The fills want a loaded world, so every test is world-backed like Tasks 9/10's.

const ARENA := Rect2i(0, 0, 480, 180)
const SPAWN_LEFT_X := 60
const SPAWN_RIGHT_X := 420
const ABOVE_SURFACE := 30
# Everything the builder puts in the ground: a column is solid from its first one down.
const TERRAIN := [&"concrete", &"rock", &"sand", &"wood", &"water", &"lava"]


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
	for material in [&"sand", &"wood", &"water", &"rock", &"lava"]:
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
