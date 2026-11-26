class_name ChFeedbackParticles extends RefCounted

# The two limits every decorative burst obeys, a feedback beat and a bolt's trail alike. Decoration
# gives up rather than starves the fight: the pool is shared with real material particles (a full pool
# drops Flamethrower/Chainsaw cells), so a burst never takes more than CAP at once and skips entirely
# once the pool is past POOL_SHARE full.

const CAP := 24
const POOL_SHARE := 0.75


static func budget(world: PixelWorld, wanted: int) -> int:
	# A null world has no pool to spend from.
	if world == null:
		return 0
	var stats: Dictionary = world.get_stats()
	var used: int = stats["particles_material"] + stats["particles_visual"]
	if used > POOL_SHARE * world.get_max_particles():
		return 0
	return mini(wanted, CAP)


static func burst_world(world: PixelWorld, at: Vector2, profile: ChFeedbackProfile, color: Color) -> int:
	# Visual particles only: they never become cells, which keeps feedback out of fight state.
	var n := budget(world, profile.particle_count)
	if n <= 0:
		return 0
	world.spawn_visual_particles(color, at, Vector2(0, -profile.particle_speed), n, 1.2, 0.5, 1.0, true)
	return n
