extends ChTest

# Task 2 engine additions: PixelMaterial.indestructible, PixelWorld.arena_border_material and
# PixelWorld.count_materials. ChTest.make_world loads res://game/materials/game_set.tres, which a
# later task writes, so these tests compile a PixelMaterialSet in code instead.


func _make_world(arena := Rect2i(0, 0, 64, 64), border := &"rock") -> PixelWorld:
	var rock := PixelMaterial.new()
	rock.name = &"rock"
	rock.material_class = PixelMaterial.CLASS_SOLID
	rock.color = Color(0.5, 0.5, 0.55)
	rock.collision_solid = true
	var concrete := PixelMaterial.new()
	concrete.name = &"concrete"
	concrete.material_class = PixelMaterial.CLASS_SOLID
	concrete.color = Color(0.65, 0.62, 0.55)
	concrete.collision_solid = true
	concrete.indestructible = true
	var sand := PixelMaterial.new()
	sand.name = &"sand"
	sand.material_class = PixelMaterial.CLASS_POWDER
	sand.color = Color(0.85, 0.72, 0.4)
	var material_set := PixelMaterialSet.new()
	material_set.materials = [rock, concrete, sand]
	var world := PixelWorld.new()
	world.material_set = material_set
	world.arena = arena
	world.arena_border_material = border
	var main_loop = Engine.get_main_loop()
	main_loop.get_root().add_child(world)
	# _ready() streams the arena chunks; wait until the area reads back loaded (ChTest.make_world's
	# cap), so a world that never built up fails instead of hanging the run.
	var frames := 0
	while not world.is_area_ready(arena):
		if frames >= WAIT_FRAMES:
			return world
		frames += 1
		await main_loop.process_frame
	return world


func test_explode_spares_indestructible() -> void:
	var world := await _make_world()
	var filled := world.fill_rect(Rect2i(10, 10, 20, 20), &"concrete")
	assert_true(filled == 400, "fill_rect wrote %d of the 400 concrete cells" % filled)
	world.explode(Vector2i(20, 20), 8, 300)
	world.step(2)
	assert_eq(world.get_material_at(Vector2i(20, 20)), &"concrete", "the blast centre stays concrete")
	_complete()


func test_arena_border_material() -> void:
	var world := await _make_world(Rect2i(0, 0, 64, 64), &"concrete")
	assert_eq(world.get_material_at(Vector2i(-1, 10)), &"concrete", "the arena border is concrete")
	_complete()


func test_count_materials() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(5, 5, 4, 4), &"sand")
	var counts: Dictionary = world.count_materials(Rect2i(0, 0, 20, 20))
	assert_eq(counts.get(&"sand", 0), 16, "sand cells in the rect")
	assert_eq(counts.get(&"burning", 0), 0, "burning cells in the rect")
	_complete()


# --- garage-battle-ui Task 1: PixelRigidBody.collision_group ---
# Two 10x4 wood boxes whose centres sit 3 cells apart, so their hulls overlap by 7 cells.
# gravity_scale 0: only their own contact can move them. ChTest.make_world loads game_set.tres,
# which carries the wood material these bodies stamp.
const GROUP_SPAWN := Vector2(120, 90)  # interior air, far from the arena border
const GROUP_FRAMES := 30
# stamp() keeps the cell the first body wrote, so the second body's overlapping pixels are
# contested: (10 - 3) columns x 4 rows of hull overlap.
const GROUP_CONTESTS := 28


func _stamp_contests(world: PixelWorld) -> int:
	# Contested cells counted by this tick's stamp(). FLAG_BODY cells exist only between stamp() and
	# unstamp() inside one tick, so no frame-boundary grid read (count_materials) can see a stamped
	# cell at all; this is the seam that measures them.
	return int(world.get_stats()["stamp_contests"])


func _overlap_pair(world: PixelWorld, group_a: int, group_b: int) -> Array[PixelRigidBody]:
	# `world` by path, not the pixel_world group: this file's `_make_world` worlds are never freed
	# and would be found first, and their material set has no wood.
	var parent := _parent()
	var pair: Array[PixelRigidBody] = []
	for i in 2:
		var body := PixelRigidBody.new()
		body.texture = ChTextures.box(10, 4, Color(0.6, 0.45, 0.3))
		body.pixel_material = &"wood"
		body.gravity_scale = 0
		body.collision_group = group_a if i == 0 else group_b
		body.world = world.get_path()
		parent.add_child(body)
		body.global_position = GROUP_SPAWN + Vector2(3 * i, 0)
		pair.append(body)
	return pair


func test_same_group_bodies_overlap_freely() -> void:
	var world: PixelWorld = await make_world()
	# simulating off + one step(1) per frame: the headless frame rate can skip physics ticks, and
	# the collide test's margin needs exactly the 30 steps the brief names.
	world.simulating = false
	var pair := _overlap_pair(world, 1, 1)
	var start_a := pair[0].global_position
	var start_b := pair[1].global_position
	# The union of the two 10x4 footprints: x 115..127, y 88..91.
	var footprints := Rect2i(115, 88, 13, 4)
	var wood_frame_1 := 0
	var wood_after := 0
	var contests_frame_1 := 0
	var contests_after := 0
	for frame in range(1, GROUP_FRAMES + 1):
		await Engine.get_main_loop().process_frame
		world.step(1)
		if frame == 1 or frame == GROUP_FRAMES:
			var wood: int = world.count_materials(footprints).get(&"wood", 0)
			var contests := _stamp_contests(world)
			if frame == 1:
				wood_frame_1 = wood
				contests_frame_1 = contests
			else:
				wood_after = wood
				contests_after = contests
	assert_true(pair[0].global_position.distance_to(start_a) < 0.5,
		"same-group bodies must not push each other apart (a moved %s)" % [pair[0].global_position.distance_to(start_a)])
	assert_true(pair[1].global_position.distance_to(start_b) < 0.5,
		"same-group bodies must not push each other apart (b moved %s)" % [pair[1].global_position.distance_to(start_b)])
	# The hulls really are stamped: all 28 overlapping cells are contested on frame 1 and still 28
	# after 30 frames, so neither body lost its stamped cells to the other, and the contested-cell
	# skip (the first holder keeps the cell) still protects them.
	assert_eq(contests_frame_1, GROUP_CONTESTS,
		"contested stamped cells over the overlapping hulls on frame 1")
	assert_eq(contests_after, GROUP_CONTESTS,
		"contested stamped cells over the overlapping hulls after %d frames (%d on frame 1)"
		% [GROUP_FRAMES, contests_frame_1])
	# Leak guard, kept from the plan's wording: unstamp() lifts everything stamp() wrote, so a frame
	# boundary reads air over the footprints. It cannot see the stamped cells themselves.
	assert_eq(wood_frame_1, 0, "wood left in the grid at a frame boundary (frame 1)")
	assert_eq(wood_after, 0, "wood left in the grid at a frame boundary (frame %d)" % GROUP_FRAMES)
	_complete()


func test_different_group_bodies_still_collide() -> void:
	var world: PixelWorld = await make_world()
	world.simulating = false
	var pair := _overlap_pair(world, 1, 2)
	var gap_before := pair[0].global_position.distance_to(pair[1].global_position)
	for _frame in GROUP_FRAMES:
		await Engine.get_main_loop().process_frame
		world.step(1)
	var gap_after := pair[0].global_position.distance_to(pair[1].global_position)
	assert_true(gap_after - gap_before > 1.0,
		"the overlapping bodies must separate by more than 1 cell (before %s, after %s)" % [gap_before, gap_after])
	# Discriminates the counter: Box2D pushes this pair apart, so the cells their stamps share run
	# out (measured 2, 1, 0 over the extra ticks) while the same-group pair stays at GROUP_CONTESTS.
	world.step(GROUP_FRAMES)
	assert_eq(_stamp_contests(world), 0, "contested stamped cells once the pair has separated")
	_complete()


func test_collision_group_defaults_to_zero() -> void:
	var body := PixelRigidBody.new()
	assert_eq(body.collision_group, 0, "a fresh body has no collision group")
	body.free()
	_complete()


func test_count_materials_without_grid() -> void:
	# A world that never finished _ready has no grid; the header still promises the burning key,
	# which is how the per-tick status sample reads counts[&"burning"].
	var world := PixelWorld.new()  # never added to the tree, so _ready never ran and there is no grid
	var counts: Dictionary = world.count_materials(Rect2i(0, 0, 8, 8))
	world.free()
	assert_true(&"burning" in counts, "the burning key is present")
	assert_eq(counts[&"burning"], 0, "no grid means nothing is burning")
	_complete()
