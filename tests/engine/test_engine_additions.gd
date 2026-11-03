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


func test_count_materials_without_grid() -> void:
	# A world that never finished _ready has no grid; the header still promises the burning key,
	# which is how the per-tick status sample reads counts[&"burning"].
	var world := PixelWorld.new()  # never added to the tree, so _ready never ran and there is no grid
	var counts: Dictionary = world.count_materials(Rect2i(0, 0, 8, 8))
	world.free()
	assert_true(&"burning" in counts, "the burning key is present")
	assert_eq(counts[&"burning"], 0, "no grid means nothing is burning")
	_complete()
