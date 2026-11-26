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
	rock.hardness = 5
	var steel := PixelMaterial.new()
	steel.name = &"steel"
	steel.material_class = PixelMaterial.CLASS_SOLID
	steel.color = Color(0.6, 0.62, 0.68)
	steel.collision_solid = true
	steel.hardness = 7
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
	sand.hardness = 1
	var gunpowder := PixelMaterial.new()
	gunpowder.name = &"gunpowder"
	gunpowder.material_class = PixelMaterial.CLASS_POWDER
	gunpowder.color = Color(0.3, 0.3, 0.32)
	gunpowder.ignite_temperature = 150
	gunpowder.explode_radius = 3
	gunpowder.explode_power = 150
	var tnt := PixelMaterial.new()
	tnt.name = &"tnt"
	tnt.material_class = PixelMaterial.CLASS_SOLID
	tnt.color = Color(0.8, 0.15, 0.1)
	tnt.collision_solid = true
	tnt.ignite_temperature = 250
	tnt.explode_radius = 10
	tnt.explode_power = 400
	tnt.hardness = 3
	# A charge that digs only up to hardness 4 when it goes off.
	var tnt_dig: PixelMaterial = tnt.duplicate()
	tnt_dig.name = &"tnt_dig"
	tnt_dig.explode_dig = 4
	var material_set := PixelMaterialSet.new()
	# fire and smoke: the blast style's leftovers, and what a lit cell spreads, as in the game set.
	material_set.materials = [rock, steel, concrete, sand, gunpowder, tnt, tnt_dig,
		load("res://game/materials/fire.tres"), load("res://game/materials/smoke.tres")]
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


# --- cook-and-arena Task 1: explosive materials, chained detonation and the blast queue ---


func test_lit_tnt_detonates_and_reports() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 6, 6), &"tnt")
	world.take_blasts()
	world.explode(Vector2i(28, 33), 2, 100)   # covers TNT cells: lights them
	world.step(3)
	var blasts := world.take_blasts()
	var tnt := blasts.filter(func(b): return b["material"] == &"tnt")
	assert_true(blasts.any(func(b): return b["material"] == &"" and b["radius"] == 2), "explode() is reported")
	assert_eq(tnt.size(), 3, "a lone 6x6 crate goes off as 3 blasts on consecutive ticks")
	assert_eq(tnt[0]["radius"], 10)
	assert_eq(world.count_materials(Rect2i(30, 30, 6, 6)).get(&"tnt", 0), 0, "the crate is gone")
	assert_eq(world.take_blasts().size(), 0, "take_blasts clears the queue")
	_complete()


func test_gunpowder_pile_chains_past_the_cap() -> void:
	var world := await _make_world()
	# On the floor (the border starts at y 64): a pile dropped from mid-air scatters grains out of
	# every blast's reach, which tests the fall rather than the chain.
	world.fill_rect(Rect2i(10, 59, 40, 5), &"gunpowder")   # 200 cells
	world.explode(Vector2i(10, 61), 2, 50)
	world.step(120)
	assert_eq(world.count_materials(Rect2i(0, 0, 64, 64)).get(&"gunpowder", 0), 0, "every cell went")
	_complete()


func test_unlit_tnt_is_inert() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 4, 4), &"tnt")
	world.step(60)
	assert_eq(world.count_materials(Rect2i(30, 30, 4, 4)).get(&"tnt", 0), 16)
	assert_eq(world.take_blasts().size(), 0)
	_complete()


func test_chain_next_to_border_keeps_the_wall() -> void:
	var world := await _make_world(Rect2i(0, 0, 64, 64), &"concrete")
	world.fill_rect(Rect2i(0, 20, 6, 6), &"tnt")
	world.explode(Vector2i(4, 22), 2, 50)
	world.step(5)
	# The border sits just outside the arena rect (test_arena_border_material reads x -1).
	assert_eq(world.get_material_at(Vector2i(-1, 22)), &"concrete", "the border survives")
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


# --- materials Task 1: hardness, dig-limited blasts, and blow (wind) ---
const DIG_CENTRE := Vector2i(32, 32)


func _half_rock_half_steel(world: PixelWorld) -> void:
	world.fill_rect(Rect2i(22, 22, 10, 21), &"rock")   # left of the centre
	world.fill_rect(Rect2i(32, 22, 10, 21), &"steel")  # the centre and right of it


func test_explode_dig_spares_harder_cells() -> void:
	var world := await _make_world()
	_half_rock_half_steel(world)
	var removed := world.explode(DIG_CENTRE, 8, 300, 6)
	var counts: Dictionary = world.count_materials(Rect2i(22, 22, 20, 21))
	assert_eq(counts.get(&"steel", 0), 210, "every steel cell (hardness 7 > dig 6) stays")
	assert_true(removed > 0, "the blast removed cells")
	assert_eq(210 - counts.get(&"rock", 0), removed, "only rock (hardness 5) was removed")
	assert_true(world.get_material_at(DIG_CENTRE - Vector2i(1, 0)) != &"rock", "rock beside the centre is gone")
	assert_eq(world.take_blasts().back()["dig"], 6, "the queued blast carries its dig")
	_complete()


func test_explode_dig_equal_hardness_is_dug() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(22, 22, 20, 21), &"rock")   # hardness 5
	var removed := world.explode(DIG_CENTRE, 8, 300, 5)
	assert_true(removed > 0, "dig 5 removes hardness 5")
	assert_true(world.get_material_at(DIG_CENTRE) != &"rock", "the centre rock is gone")
	_complete()


func test_explode_dig_default_digs_all() -> void:
	var world := await _make_world()
	_half_rock_half_steel(world)
	world.explode(DIG_CENTRE, 8, 300)
	var counts: Dictionary = world.count_materials(Rect2i(22, 22, 20, 21))
	assert_true(counts.get(&"steel", 0) < 210, "steel was removed")
	assert_true(counts.get(&"rock", 0) < 210, "rock was removed")
	assert_true(world.get_material_at(DIG_CENTRE) != &"steel", "the centre (steel) is gone")
	assert_eq(world.take_blasts().back()["dig"], -1, "explode() without dig reports -1")
	_complete()


func test_explode_dig_still_lights_explosives() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 4, 4), &"tnt")   # hardness 3
	world.take_blasts()
	world.explode(Vector2i(31, 31), 8, 300, 0)
	assert_eq(world.count_materials(Rect2i(30, 30, 4, 4)).get(&"burning", 0), 16, "every TNT cell is lit")
	world.step(1)
	assert_true(world.take_blasts().any(func(b): return b["material"] == &"tnt"), "a tnt blast is queued")
	_complete()


func test_lit_blast_uses_explode_dig() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 2, 2), &"tnt_dig")
	world.fill_rect(Rect2i(32, 26, 4, 10), &"steel")
	world.fill_rect(Rect2i(26, 26, 4, 10), &"rock")
	world.fill_rect(Rect2i(30, 36, 2, 1), &"rock")  # a floor under the charge
	world.set_cell(Vector2i(30, 35), &"sand")  # hardness 1, on the floor, 5 cells from the charge
	world.take_blasts()
	world.explode(Vector2i(30, 30), 1, 50, 0)   # lights the charge, digs nothing harder than 0
	assert_eq(world.get_material_at(Vector2i(30, 35)), &"sand", "the sand is there before the charge goes")
	world.step(3)
	var charge := world.take_blasts().filter(func(b): return b["material"] == &"tnt_dig")
	assert_true(charge.size() > 0, "the charge went off")
	assert_eq(charge[0]["dig"], 4, "a lit blast digs with its material's explode_dig")
	assert_eq(world.count_materials(Rect2i(32, 26, 4, 10)).get(&"steel", 0), 40, "the steel remains")
	assert_true(world.get_material_at(Vector2i(30, 35)) != &"sand", "the sand (hardness 1 <= 4) is dug")
	_complete()


func test_blow_moves_gas_only() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(10, 10, 3, 3), &"smoke")
	world.fill_rect(Rect2i(10, 20, 3, 3), &"sand")
	world.fill_rect(Rect2i(10, 30, 3, 3), &"rock")
	var moved := world.blow(Rect2i(5, 5, 30, 30), Vector2i(5, 0))
	assert_eq(moved, 9, "the answer is the smoke count")
	assert_eq(world.count_materials(Rect2i(15, 10, 3, 3)).get(&"smoke", 0), 9, "the smoke moved +5 in x")
	assert_eq(world.count_materials(Rect2i(10, 10, 5, 3)).get(&"smoke", 0), 0, "no smoke stayed behind")
	assert_eq(world.count_materials(Rect2i(10, 20, 3, 3)).get(&"sand", 0), 9, "the sand stayed")
	assert_eq(world.count_materials(Rect2i(10, 30, 3, 3)).get(&"rock", 0), 9, "the rock stayed")
	_complete()


func test_blow_moves_a_column_every_way() -> void:
	for v in [Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5)]:
		var world := await _make_world()
		world.fill_rect(Rect2i(30, 20, 1, 5), &"smoke")   # a column, x 30, y 20..24
		assert_eq(world.blow(Rect2i(5, 5, 50, 50), v), 5, "%s moves all 5" % v)
		var landed := Rect2i(Vector2i(30, 20) + v, Vector2i(1, 5))
		assert_eq(world.count_materials(landed).get(&"smoke", 0), 5, "%s: the column moved whole" % v)
	_complete()


func test_blow_keeps_fire_and_burning() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(100, 100, 1, 3), &"fire")
	world.set_cell(Vector2i(100, 120), &"flammable_gas")
	assert_true(world.ignite(Vector2i(100, 120)), "the gas cell lights")
	world.blow(Rect2i(90, 90, 30, 40), Vector2i(5, 0))
	assert_eq(world.count_materials(Rect2i(105, 100, 1, 3)).get(&"fire", 0), 3, "the fire moved as fire")
	var gas: Dictionary = world.count_materials(Rect2i(105, 120, 1, 1))
	assert_eq(gas.get(&"flammable_gas", 0), 1, "the lit gas moved")
	assert_eq(gas.get(&"burning", 0), 1, "and it is still burning")
	_complete()


func test_blow_stops_at_walls() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(20, 5, 2, 20), &"rock")
	world.fill_rect(Rect2i(17, 10, 1, 3), &"smoke")   # x 18 and 19 are free, then the wall
	world.blow(Rect2i(0, 0, 40, 40), Vector2i(5, 0))
	assert_eq(world.count_materials(Rect2i(19, 10, 1, 3)).get(&"smoke", 0), 3, "the smoke ends next to the wall")
	assert_eq(world.count_materials(Rect2i(20, 5, 2, 20)).get(&"rock", 0), 40, "no rock cell changed")
	_complete()


func test_blow_across_the_border() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(60, 0, 4, 4), &"smoke")
	world.fill_rect(Rect2i(0, 60, 4, 4), &"smoke")
	var rect := Rect2i(-300, -300, 700, 700)   # past the border and into unloaded space
	var moved := 0
	for v in [Vector2i(5, 3), Vector2i(-1000, 1000), Vector2i(64, -64)]:
		moved += world.blow(rect, v)
	assert_true(moved >= 0, "blow answers a count")
	for i in 64:
		for cell in [Vector2i(-1, i), Vector2i(64, i), Vector2i(i, -1), Vector2i(i, 64)]:
			if world.get_material_at(cell) != &"rock":
				assert_eq(world.get_material_at(cell), &"rock", "border cell %s" % cell)
				_complete()
				return
	_complete()


func test_ignite_lights_explosives_only() -> void:
	var world := await _make_world()
	world.fill_rect(Rect2i(30, 30, 4, 4), &"tnt")
	world.fill_rect(Rect2i(10, 50, 4, 4), &"rock")
	assert_true(world.ignite(Vector2i(31, 31)), "a tnt cell lights")
	assert_true(not world.ignite(Vector2i(11, 51)), "rock cannot")
	assert_true(not world.ignite(Vector2i(20, 20)), "nor air")
	var lit := false
	for i in 60:
		world.step(1)
		for b in world.take_blasts():
			lit = lit or b["material"] == &"tnt"
	assert_true(lit, "the lit tnt went off")
	assert_eq(world.count_materials(Rect2i(10, 50, 4, 4)).get(&"rock", 0), 16, "the rock is unchanged")
	_complete()
