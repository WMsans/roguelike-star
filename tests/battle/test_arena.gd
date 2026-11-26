extends ChTest

# Task 11: the closed pit every fight runs in. ChArenaBuilder.build lays the arena's layers into
# ChTest's world (arena 480x180, concrete border) and hands back the two spawn points.
# The fills want a loaded world, so every test is world-backed like Tasks 9/10's.

const ARENA := Rect2i(0, 0, 480, 180)
const SPAWN_LEFT_X := 170
const SPAWN_RIGHT_X := 309
const ABOVE_SURFACE := 30
# Everything the builder puts in the ground: a column is solid from its first one down.
const TERRAIN := [&"concrete", &"rock", &"sand", &"wood", &"water", &"lava", &"tnt", &"gunpowder", &"acid", &"oil",
	&"steel", &"battery"]
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
	# The water pools are lidded wherever they lie: no column anywhere opens onto water.
	var open_water := []
	for x in range(ARENA.position.x, ARENA.end.x):
		if world.get_material_at(Vector2i(x, _surface_y(world, x))) == &"water":
			open_water.append(x)
	assert_eq(open_water, [], "columns whose surface is water")
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
	# (ChArenaBuilder.FUSE_END, under the spawn) lights it; the chain has to reach the crate.
	var world: PixelWorld = await make_world()
	ChArenaBuilder.build(world, 12345)
	world.take_blasts()
	var end := ChArenaBuilder.FUSE_END
	var y := _surface_y(world, end) + 2
	assert_eq(world.get_material_at(Vector2i(end, y)), &"gunpowder", "the seam's far end is gunpowder")
	world.explode(Vector2i(end, y), 1, 50)
	var tnt := false
	for i in range(60):  # 600 ticks, 10 s
		world.step(10)
		if world.take_blasts().any(func(b): return b["material"] == &"tnt"):
			tnt = true
			break
	assert_true(tnt, "the lit seam set off its crate within 600 ticks")
	world.free()
	_complete()


func _longest_steel_run(world: PixelWorld, half: Rect2i) -> int:
	var best := 0
	for y in range(half.position.y, half.end.y):
		var run := 0
		for x in range(half.position.x, half.end.x):
			run = run + 1 if world.get_material_at(Vector2i(x, y)) == &"steel" else 0
			best = maxi(best, run)
	return best


func test_arena_has_batteries_steel_and_water() -> void:
	var world: PixelWorld = await make_world()
	var built: Dictionary = ChArenaBuilder.build(world, 12345)
	var halves := [Rect2i(0, 0, 240, 180), Rect2i(240, 0, 240, 180)]
	for half in halves:
		var counts: Dictionary = world.count_materials(half)
		assert_true(counts.get(&"battery", 0) >= 12, "a battery block in %s (%d cells)" % [half, counts.get(&"battery", 0)])
		assert_true(counts.get(&"water", 0) > 0, "a water pool in %s" % half)
		assert_true(_longest_steel_run(world, half) >= 12, "a steel run of 12+ in %s" % half)
	# A conductor in the fighting area (the driving line, x 140-340) for a part's spark to use: a
	# steel run of 12+ in each half of it.
	for half in [Rect2i(140, 0, 100, 180), Rect2i(240, 0, 101, 180)]:
		assert_true(_longest_steel_run(world, half) >= 12, "a steel run of 12+ on the driving line in %s" % half)
	# "batteries" lists the battery rects, whole, and every battery cell sits in one.
	assert_true("batteries" in built, "the build answers batteries")
	var rects: Array = built.get("batteries", [])
	var listed := 0
	for half in halves:
		assert_true(rects.any(func(r: Rect2i) -> bool: return half.encloses(r)), "a battery rect in %s" % half)
	for rect: Rect2i in rects:
		var cells: Dictionary = world.count_materials(rect)
		assert_eq(cells.get(&"battery", 0), rect.size.x * rect.size.y, "%s is all battery" % rect)
		listed += rect.size.x * rect.size.y
	assert_eq(listed, world.count_materials(ARENA).get(&"battery", 0), "every battery cell is in a listed rect")
	world.free()
	_complete()


class CountingSparks extends ChSparks:
	# Counts the blocks each status second discharges (second() discharges every block left).
	var discharges := 0

	func second(ctx: ChBattleContext) -> void:
		super(ctx)
		discharges += _batteries.size()


func test_idle_arena_never_blows() -> void:
	# The batteries spark every status second; 60 s of that with nobody near sets off nothing.
	var world: PixelWorld = await make_world()
	var built: Dictionary = ChArenaBuilder.build(world, 12345)
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	var sparks := CountingSparks.new()
	ctx.sparks = sparks
	for rect: Rect2i in built.get("batteries", []):
		ctx.sparks.add_battery(ctx, rect)
	world.take_blasts()
	var went_off := []
	for i in range(3600):
		world.step(1)
		# Taken here, before tick's hazards.apply eats them.
		for blast in world.take_blasts():
			if blast["material"] != &"":
				went_off.append(blast)
		ctx.tick(1.0 / 60.0, [], [])
	assert_eq(went_off, [], "material blasts in an idle minute")
	# Not vacuous: both batteries discharged every status second (buried, so no arc cells show).
	assert_true(sparks.discharges >= 2 * 59, "battery discharges in the minute (%d)" % sparks.discharges)
	world.free()
	_complete()


func test_battery_spark_stays_off_explosives() -> void:
	# ChSparks.discharge's flood from each battery's cells (shock = false): through touching water
	# and steel, at most MAX_CELLS. No reached cell is next to an explosive.
	var world: PixelWorld = await make_world()
	var built: Dictionary = ChArenaBuilder.build(world, 12345)
	var rects: Array = built.get("batteries", [])
	assert_true(rects.size() >= 2, "batteries to flood from")
	var touching := []
	for rect: Rect2i in rects:
		var reached := {}
		var queue: Array[Vector2i] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				reached[Vector2i(x, y)] = true
				queue.append(Vector2i(x, y))
		var head := 0
		while head < queue.size() and reached.size() < ChSparks.MAX_CELLS:
			var at := queue[head]
			head += 1
			for d in ChSparks.DIRS:
				var next := at + d
				if not reached.has(next) and world.get_material_at(next) in ChSparks.CONDUCTORS:
					reached[next] = true
					queue.append(next)
		for at in queue:
			for d in [Vector2i.ZERO] + ChSparks.DIRS:
				if world.get_material_at(at + d) in ChSparks.EXPLOSIVES:
					touching.append(at)
		assert_true(queue.size() > rect.size.x * rect.size.y, "%s feeds a conductor" % rect)
	assert_eq(touching, [], "battery-reached cells next to an explosive")
	world.free()
	_complete()
