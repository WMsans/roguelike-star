extends ChTest

# Task 9: a ChariotLayout becomes jointed PixelRigidBodies in a PixelWorld. World-backed: the
# joints and the chassis have to settle under Box2D. Review Focus 1 is the wheelless chariot.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
# Spawning near the floor, not 30 cells above it: a drop that fast tunnels the jointed bodies
# through the rock (verified: a Dozer dropped from y = 130 ends at y = 164, inside the floor).
const ORIGIN := Vector2(120, 140)
const TICKS := 120
const WINDOW := 10
# Review item 7: how long the wheelless test waits for its two bodies to join. See that test's note.
const JOIN_WAIT_FRAMES := 240


func _ground(world: PixelWorld) -> void:
	# The floor the chariot stands on; fill_rect returns the cells written.
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")


func _mount(body_id: StringName, mounts: Array) -> ChChariotLayout:
	# A build from [[path, part_id]] in mount order; place() takes Array[int].
	var layout: ChChariotLayout = ChChariotLayout.new()
	layout.body_id = body_id
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout


func _typed_path(path) -> Array[int]:
	# all_paths/place both speak typed slot indices, same shape as tests/data/test_catalog.gd.
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	# The part the builder put at a layout path; runtime.parts keeps every part's own path.
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null


func test_builds_bodies_and_joints() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	# Dozer slots 0/1 are the two lowest (y = 6), so the wheels sit under the hull; slot 2 is (12,-3)
	# and the mace hangs off the strut's first extension slot, one body further out.
	var layout: ChChariotLayout = _mount(&"dozer", [
		[[0], &"wheel"], [[1], &"wheel"], [[2], &"strut"], [[2, 0], &"ice_cream_mace"]])
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), layout, ChCatalog.load_default(), 0, ORIGIN, false)
	assert_true(runtime != null, "the build returns a runtime")
	assert_eq(runtime.chassis.get_body_size(), Vector2i(30, 18), "the chassis is the Dozer's 30x18 box")
	assert_true(is_instance_of(runtime.chassis, PixelRigidBody), "the chassis is a PixelRigidBody")
	var bodies := 1
	var joints := 0
	for part in runtime.parts:
		if is_instance_of(part.body, PixelRigidBody):
			bodies += 1
		if part.joint != null:
			joints += 1
	assert_eq(bodies, 5, "chassis plus one PixelRigidBody per part")
	assert_eq(joints, 4, "one joint per part")
	var wheel := _part_of(runtime, [0])
	var strut := _part_of(runtime, [2])
	var child := _part_of(runtime, [2, 0])
	assert_true(wheel != null and strut != null and child != null, "the wheels, strut and child all mounted")
	assert_true(is_instance_of(wheel.joint, PixelWheelJoint), "a wheel gets a PixelWheelJoint")
	assert_near(wheel.joint.max_motor_torque, 3e6, 0.0001, "the demo's motor torque")
	assert_near(wheel.joint.frequency, 5.0, 0.0001, "the demo's suspension frequency")
	assert_true(is_instance_of(strut.joint, PixelRevoluteJoint), "a part that is not a wheel hinges")
	assert_true(strut.joint.enable_limit, "the hinge is limited")
	assert_near(strut.joint.lower_angle, 0.0, 0.0001, "limited to 0")
	assert_near(strut.joint.upper_angle, 0.0, 0.0001, "limited to 0")
	# The child bolts onto its parent part, so its joint names the strut's body, not the chassis.
	assert_eq(child.joint.body_a, child.joint.get_path_to(strut.body), "the child joints to the strut")
	assert_eq(child.joint.body_b, child.joint.get_path_to(child.body), "and to its own body")
	world.free()
	_complete()


func test_settles_on_ground() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[0], &"wheel"], [[1], &"wheel"]]), ChCatalog.load_default(), 0, ORIGIN, false)
	assert_true(runtime != null, "the build returns a runtime")
	# One world.step per awaited frame: joining runs on the engine's internal physics tick, so a
	# single step(120) call would tick an empty world before any body had joined.
	var ys: Array[float] = []
	for _tick in range(TICKS):
		await Engine.get_main_loop().process_frame
		world.step(1)
		ys.append(runtime.chassis.global_position.y)
	# The chassis box spans its own 18 cells about its centre, so its centre sitting at or under the
	# rock's first row means it sank into the floor.
	assert_true(ys[TICKS - 1] < GROUND_TOP, "the chassis sits above the rock")
	assert_true(absf(ys[TICKS - 1] - ys[TICKS - WINDOW]) < 1.0, "the last 10 ticks move it under 1 cell")
	world.free()
	_complete()


func test_drive_moves_right() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[0], &"wheel"], [[1], &"wheel"]]), ChCatalog.load_default(), 0, ORIGIN, false)
	var start_x := runtime.chassis.global_position.x
	for _tick in range(TICKS):
		runtime.drive(1.0)
		await Engine.get_main_loop().process_frame
		world.step(1)
	assert_true(runtime.chassis.global_position.x - start_x > 5.0,
		"the motors carried the chassis right")
	world.free()
	_complete()


func test_wheelless_chariot_spawns_and_fires() -> void:
	# Review Focus 1: nothing in the build is a wheel, so the chariot still exists and fights;
	# driving input just does nothing.
	var world: PixelWorld = await make_world()
	_ground(world)
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[2], &"ice_cream_mace"]]), ChCatalog.load_default(), 0, ORIGIN, false)
	assert_eq(runtime.parts.size(), 1, "the mace is the only part")
	assert_eq(runtime.wheels(), [], "nothing to motorise")
	# The chassis and the part still joined the world, so the chariot stands in the arena.
	# Review item 7 (the flake this used to be): a body joins on an internal physics tick
	# (pixel_physics_node.cpp:27 NOTIFICATION_INTERNAL_PHYSICS_PROCESS -> try_join), and try_join
	# refuses while the world owns no physics yet (pixel_physics_node.cpp:57). One awaited process
	# frame is not one physics tick: the runner's frames are unpaced, so a frame can land between two
	# ticks and get_mass() is still 0 there. Measured: this assert passed 5/5 running this file alone
	# (frames ~4 ms) and failed inside the full suite (frames ~40 ms), which is what an unpaced-frame
	# race looks like. Waiting for the join is the fixture; the assert below still fails a body that
	# never joins, and now names the mass and the wait it needed.
	var joined := 0
	while joined < JOIN_WAIT_FRAMES and (runtime.chassis.get_mass() <= 0.0
			or runtime.parts[0].body.get_mass() <= 0.0):
		await Engine.get_main_loop().process_frame
		joined += 1
	world.step(1)
	# get_mass reads 0 until a body has joined and Box2D has given it its mass.
	assert_true(runtime.chassis.get_mass() > 0.0,
		"the chassis joined the world (mass %s after %d frames)" % [runtime.chassis.get_mass(), joined])
	assert_true(runtime.parts[0].body.get_mass() > 0.0, "and so does the mace (mass %s)"
		% [runtime.parts[0].body.get_mass()])
	# drive() on a chariot with no wheels must not raise: a body that dies here never reaches
	# _complete(), which the runner already counts as a failure.
	runtime.drive(1.0)
	runtime.drive(-1.0)
	assert_true(runtime.chassis.global_position.y < GROUND_TOP,
		"it still stands above the rock (chassis y %s)" % [runtime.chassis.global_position.y])
	world.free()
	_complete()


func test_off_ground_wheel_drives_nothing() -> void:
	# Review Focus 1's other half: a wheel mounted off the ground still builds and still gets its
	# motor, so driving must leave the chariot where it stands.
	var world: PixelWorld = await make_world()
	_ground(world)
	# Dozer slot 4 is body-local (-6, -9): after the settle the chassis rests on the rock (centre y 151)
	# and this wheel's 12-cell disc hangs with its bottom at 148.8, 11 cells clear of the floor.
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[4], &"wheel"]]), ChCatalog.load_default(), 0, ORIGIN, false)
	assert_true(runtime != null, "the build returns a runtime")
	assert_eq(runtime.parts.size(), 1, "the hovering wheel is the only part")
	var wheel := _part_of(runtime, [4])
	assert_true(is_instance_of(wheel.joint, PixelWheelJoint), "the hovering wheel still gets its motor joint")
	# Settle first with no input, so a fall under gravity cannot be read as drive.
	for _tick in range(TICKS):
		await Engine.get_main_loop().process_frame
		world.step(1)
	assert_true(runtime.chassis.global_position.y < GROUND_TOP, "the chassis still stands above the rock")
	assert_true(wheel.body.get_mass() > 0.0, "and the hovering wheel joined the world")
	var settled := runtime.chassis.global_position
	for _tick in range(TICKS):
		runtime.drive(1.0)
		await Engine.get_main_loop().process_frame
		world.step(1)
	var driven := runtime.chassis.global_position
	# The motor does run on a hovering wheel (ChariotRuntime.drive sets it, the joint spins it in air):
	# pinning that keeps the position asserts below from passing when drive silently skips the wheel.
	assert_true(wheel.joint.enable_motor, "the hovering wheel's motor is on under drive(+1)")
	assert_near(wheel.joint.motor_speed, 12.0, 0.0001, "at the full drive speed")
	# Measured: the hovering wheel spins at 12 rad/s while the chassis does not move, so the motor
	# runs on it and only the physics has nothing to grip — the chariot, not the motor, does nothing.
	assert_true(wheel.body.angular_velocity != 0.0, "and the hovering wheel really turns under it")
	assert_near(driven.x, settled.x, 1.0, "drive(+1) left the hovering wheel spinning without moving the chassis")
	assert_near(driven.y, settled.y, 1.0, "and nothing lifted or dragged it")
	for _tick in range(TICKS):
		runtime.drive(-1.0)
		await Engine.get_main_loop().process_frame
		world.step(1)
	var reversed := runtime.chassis.global_position
	assert_near(reversed.x, settled.x, 1.0, "drive(-1) is the same: the chassis stays put")
	assert_near(reversed.y, settled.y, 1.0, "and so it stays above the rock")
	world.free()
	_complete()


func test_mirror_x_flips_anchor() -> void:
	# Corsair slot 1 is body-local (10, 5): a mirrored build sits at the far side of the hull, so the
	# x anchor negates and y stays (a flip turns the build left/right, not upside down).
	var world: PixelWorld = await make_world()
	_ground(world)
	var layout := _mount(&"corsair", [[[1], &"ice_cream_mace"]])
	var runtime: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, ChCatalog.load_default(), 1, ORIGIN, true)
	var part := _part_of(runtime, [1])
	# Read before any physics tick: the builder put the body where the layout said it sits.
	assert_eq(part.body.global_position, Vector2(ORIGIN.x - 10, ORIGIN.y + 5), "mirrored to origin.x - 10")
	world.free()
	_complete()