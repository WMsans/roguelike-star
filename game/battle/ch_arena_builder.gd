class_name ChArenaBuilder extends RefCounted

# The closed pit one fight runs in: air down to a noise-scarred surface line, sand packed down to
# the rock band, wood and water sunk into the surface, lava pockets in the rock, and the two spawn
# points 30 cells of air above the surface. A chariot dropped through rock tunnels onto the arena
# border (measured in Task 9), so the spawns have to hang in air.
# It lays into ChTest.make_world's arena: Rect2i(0, 0, 480, 180) with arena_border_material &"concrete".

const ARENA := Rect2i(0, 0, 480, 180)
const SURFACE_Y := 110
const SURFACE_NOISE := 6
const SURFACE_FREQUENCY := 0.02
const ROCK_TOP := 125
const SPAWN_LEFT_X := 60
const SPAWN_RIGHT_X := 420
const SPAWN_ABOVE := 30


static func _surface(rng_seed: int) -> Array[int]:
	# The top terrain cell of every arena column, from a noise seeded by rng_seed.
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = SURFACE_FREQUENCY
	var surface: Array[int] = []
	for x in range(ARENA.size.x):
		surface.append(SURFACE_Y + roundi(noise.get_noise_1d(x) * SURFACE_NOISE))
	return surface


static func _replace(world: PixelWorld, rect: Rect2i, material: StringName) -> void:
	# fill_rect writes every cell of the rect it is handed, so a short write means the rect left the
	# loaded arena and the pit grew an air gap.
	if world.fill_rect(rect, material) != rect.size.x * rect.size.y:
		push_error("ChArenaBuilder: %s wrote fewer than %d %s cells" % [rect, rect.size.x * rect.size.y, material])


static func _patch(world: PixelWorld, surface: Array[int], x: int, w: int, depth: int, material: StringName) -> void:
	# A patch sunk into the surface, one column at a time so its top follows the surface line. It
	# replaces ground cells rather than digging air, so the column stays packed under the patch.
	for i in range(w):
		_replace(world, Rect2i(x + i, surface[x + i], 1, depth), material)


static func build(world: PixelWorld, rng_seed: int) -> Dictionary:
	var surface := _surface(rng_seed)
	# Sand packs each column from its surface cell down to the rock band, rock fills the rest of the
	# way to the floor, and every cell either has to be written: unwritten ground is air, and air
	# under the surface line is a cave.
	# shortcut: sand fills down to ROCK_TOP instead of a fixed 6-10 rows, because 6-10 rows under a
	# surface line at 104-116 would leave air above the rock band. Raise SURFACE_Y near 115-119 if
	# a fight wants the thinner band.
	var wanted := (ARENA.end.y - ROCK_TOP) * ARENA.size.x
	var written := world.fill_rect(Rect2i(0, ROCK_TOP, ARENA.size.x, ARENA.end.y - ROCK_TOP), &"rock")
	for x in range(ARENA.size.x):
		wanted += ROCK_TOP - surface[x]
		written += world.fill_rect(Rect2i(x, surface[x], 1, ROCK_TOP - surface[x]), &"sand")
	if written != wanted:
		push_error("ChArenaBuilder: %d of %d ground cells went unwritten, so the arena holds air caves" % [wanted - written, wanted])
	# Wood and water sink into the surface in the middle of the pit, 60 cells clear of both spawn
	# columns, so a chariot starts on plain ground.
	# Water is one cell deep rather than the plan's 6: PhysicsWorld::apply_buoyancy (physics.cpp:521)
	# floats a stamped body on the liquid it covers, so a chassis in a deep pool loses wheel contact
	# with the ground and the pool becomes a wall. Measured with the plan's Step-5 build: the Corsair
	# stopped dead at the first pool's near edge and never crossed, and the Dozer rolled onto its side
	# in the second (both while their motors were on); at one cell the same build drives the whole
	# arena. The pools keep their width and their reactions, and a wheel still reaches sand under the
	# water.
	_patch(world, surface, 130, 20, 6, &"wood")
	_patch(world, surface, 322, 20, 6, &"wood")
	_patch(world, surface, 196, 30, 1, &"water")
	_patch(world, surface, 252, 30, 1, &"water")
	# Two lava pools in the rock under the middle third, inside y 140-160.
	_replace(world, Rect2i(172, 142, 24, 8), &"lava")
	_replace(world, Rect2i(246, 148, 24, 8), &"lava")
	return {
		"spawn_left": Vector2(SPAWN_LEFT_X, surface[SPAWN_LEFT_X] - SPAWN_ABOVE),
		"spawn_right": Vector2(SPAWN_RIGHT_X, surface[SPAWN_RIGHT_X] - SPAWN_ABOVE),
	}
