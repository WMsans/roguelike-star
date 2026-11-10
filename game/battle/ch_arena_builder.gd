class_name ChArenaBuilder extends RefCounted

# The closed pit one fight runs in: one hand-designed arena, mirrored about x 239.5 so neither side
# starts on better ground. Air down to a noise-scarred surface line, sand packed down to the rock
# band, and per half, from the wall in: an oil tank sunk against the arena wall, a sealed acid
# cistern beside it, a TNT crate buried by the spawn with a gunpowder seam running from it toward
# the spawn, the sand dig room under the spawn, and a lava pocket under a sand-and-rock crust in
# the middle. Nothing goes off on its own: the level only acts when a shot, flame, blast or dig
# reaches it. The spawns hang 30 cells of air above the surface: a chariot dropped through rock
# tunnels onto the arena border (measured in Task 9).
# It lays into ChTest.make_world's arena: Rect2i(0, 0, 480, 180) with arena_border_material &"concrete".

const ARENA := Rect2i(0, 0, 480, 180)
const SURFACE_Y := 110
const SURFACE_NOISE := 6
const SURFACE_FREQUENCY := 0.02
const ROCK_TOP := 125
const SPAWN_LEFT_X := 170
const SPAWN_RIGHT_X := 309
const SPAWN_ABOVE := 30
const MIRROR_X := 240
const OIL_W := 34  # the oil tank's outer width, walls included, from the arena wall in
const ACID_X := 34  # the acid cistern's left edge: 16 wide, rock walls 2 thick
const FLANK_CRATE_X := 118  # the flank crate's left edge (left half)
const FUSE_END := 150  # the seam's far end, at the spawn hull's tail (144)
const MID_CRATE_X := 198  # the middle crate's left edge (left half)
const LAVA_TOP := 6  # cells under the surface; a wheel samples about 4 down (ChPartRuntime.sample_rect)


static func _surface(rng_seed: int) -> Array[int]:
	# The top terrain cell of every arena column, from a noise seeded by rng_seed.
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = SURFACE_FREQUENCY
	var surface: Array[int] = []
	for x in range(ARENA.size.x):
		if x < MIRROR_X:
			surface.append(SURFACE_Y + roundi(noise.get_noise_1d(x) * SURFACE_NOISE))
		else:
			surface.append(surface[_mirror(x)])
	return surface


static func _mirror(x: int) -> int:
	return ARENA.end.x - 1 - x


static func _replace(world: PixelWorld, rect: Rect2i, material: StringName) -> void:
	# fill_rect writes every cell of the rect it is handed, so a short write means the rect left the
	# loaded arena and the pit grew an air gap.
	if world.fill_rect(rect, material) != rect.size.x * rect.size.y:
		push_error("ChArenaBuilder: %s wrote fewer than %d %s cells" % [rect, rect.size.x * rect.size.y, material])


static func _both(world: PixelWorld, rect: Rect2i, material: StringName) -> void:
	# A left-half piece and its mirror on the right.
	_replace(world, rect, material)
	_replace(world, Rect2i(_mirror(rect.end.x - 1), rect.position.y, rect.size.x, rect.size.y), material)


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
	# No liquid on the driving line (x 140-340) is ever 2 cells deep from the surface down:
	# PhysicsWorld::apply_buoyancy (physics.cpp:521) floats a stamped body on the liquid it covers, so
	# a chassis in a deep pool loses wheel contact and the pool becomes a wall (measured in Task 11:
	# the Corsair stopped dead at a 6-deep pool and the Dozer rolled onto its side in one).
	# Two engine facts shape every piece below. The terrain collider (outline.cpp chunk_solid_mask)
	# counts a powder cell as solid only when solid ground holds it up, so sand laid straight on a
	# liquid or on gunpowder drops out of the collision shape and a wheel sinks into it. And
	# test_bodies' fleeing enemy pins on the first wall at the far end and climbs it: anything raised
	# there (the brief's 26-high oil ledge, an 8-high acid mound) pinned it close enough for the
	# player's chariot to catch it and flip on it. So the far end is flush with the ground.
	# The oil tank, sunk flush against the arena wall: wood walls 2 wide and a 1-cell wood floor
	# around a 30x8 oil pool, its top level with the lowest ground cell there, with rock filling up
	# to that level where the ground dips. Off the driving line, so a chassis may float in it.
	var tank_top: int = surface.slice(0, OIL_W).min()
	for x in range(0, OIL_W):
		_both(world, Rect2i(x, tank_top, 1, surface[x] - tank_top), &"rock")
	_both(world, Rect2i(0, tank_top, 2, 9), &"wood")
	_both(world, Rect2i(OIL_W - 2, tank_top, 2, 9), &"wood")
	_both(world, Rect2i(2, tank_top + 8, OIL_W - 4, 1), &"wood")
	_both(world, Rect2i(2, tank_top, OIL_W - 4, 8), &"oil")
	# The acid cistern beside it: a 12x5 acid pool in a rock box under a 1-cell rock lid, flush with
	# the ground. Acid eats sand, wood and explosives but not rock, so it waits for a blast to break
	# the lid.
	var cistern_top: int = surface.slice(ACID_X, ACID_X + 16).min()
	for x in range(ACID_X, ACID_X + 16):
		_both(world, Rect2i(x, cistern_top, 1, maxi(surface[x] - cistern_top, 0) + 7), &"rock")
	_both(world, Rect2i(ACID_X + 2, cistern_top + 1, 12, 5), &"acid")
	# TNT crate buried 3 under the lowest surface cell over it, clear of the spawn hull (144-196).
	# Tried under the hull's tail (crate x 138, fuse to 176) to punish a chariot that never leaves
	# its spawn: nothing lit it in most fights (cook-and-arena Task 6, tuning log row 9).
	var crate_top: int = surface.slice(FLANK_CRATE_X, FLANK_CRATE_X + 6).max() + 3
	_both(world, Rect2i(FLANK_CRATE_X, crate_top, 6, 6), &"tnt")
	# A second crate where the chariots meet, at the lava's edge (x 198-203, mirrored 276-281), buried
	# the same way: a Rocket or Firebolt that digs there, or a fire that burns down to it, sets it off
	# under whoever is brawling over it. Without it the flank crates went off in under 1 fight in 8.
	var mid_top: int = surface.slice(MID_CRATE_X, MID_CRATE_X + 6).max() + 3
	_both(world, Rect2i(MID_CRATE_X, mid_top, 6, 6), &"tnt")
	# The gunpowder seam: a fuse 2 rows deep, 2 under the surface, from the crate toward the spawn,
	# under a 1-cell wood plank. One row did not carry: each blast's ragged crater dropped the next
	# grains out of reach and the chain died halfway (test_arena's test_lit_seam_sets_off_its_crate). Gunpowder is not collision-solid, and the terrain collider (outline.cpp
	# chunk_solid_mask) only counts powder held up by solid ground, so sand straight on the seam
	# drops out of the collision shape: measured, the Dozer tipped in that 3-cell dip. The plank
	# holds the sand up, and a flame that reaches it burns down into the fuse.
	for x in range(FLANK_CRATE_X + 6, FUSE_END + 1):
		_both(world, Rect2i(x, surface[x] + 1, 1, 1), &"wood")
		_both(world, Rect2i(x, surface[x] + 2, 1, 2), &"gunpowder")
	# Lava 6 deep under a crust, spanning the middle once mirrored (x 210-269). The crust is sand on
	# a 1-cell rock lid: sand straight on lava drops out of the collider for the same reason as the
	# seam, and the measured Dozer fell through it and rolled. The lid is a blast's to break. The
	# lava's top sits 6 under the surface, past the 4 or so cells a wheel's status sample reaches,
	# because a wheel that samples lava wears and burns (ChPartRuntime.apply_sample).
	# The mirrored noise leaves a dip on each side of the centre; sand fills both part way.
	var crust_y: int = surface.slice(210, MIRROR_X).min() + 1
	for x in range(210, MIRROR_X):
		if surface[x] > crust_y:
			# Filled to one cell below the middle's highest ground, not flat: the Dozer stalled for good
			# climbing out of the right dip (x 252-268) unfilled, and with the dips filled flat the
			# chariots crossed so fast that test_bodies' player caught the pinned enemy and flipped.
			_both(world, Rect2i(x, crust_y, 1, surface[x] - crust_y), &"sand")
			surface[x] = crust_y
		_both(world, Rect2i(x, surface[x] + LAVA_TOP - 1, 1, 1), &"rock")
		_both(world, Rect2i(x, surface[x] + LAVA_TOP, 1, 6), &"lava")
	# The dig room is the sand under the spawns (x 151-197): nothing placed.
	return {
		"spawn_left": Vector2(SPAWN_LEFT_X, surface[SPAWN_LEFT_X] - SPAWN_ABOVE),
		"spawn_right": Vector2(SPAWN_RIGHT_X, surface[SPAWN_RIGHT_X] - SPAWN_ABOVE),
	}
