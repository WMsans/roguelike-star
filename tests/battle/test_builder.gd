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
# Plan Review Focus 4: two wide parts sharing a strut's two extension slots. See that test's note.
const STRUT_FRAMES := 180  # frames the strut-pair rig is given to settle
const STRUT_WINDOW := 30  # the frames the chassis rotation is measured over
const STRUT_MOUNTS: Array = [
	[[0], &"wheel"], [[1], &"wheel"], [[2], &"strut"],
	[[2, 0], &"cutter_chainsaw"], [[2, 1], &"flamethrower"]]
const STRUT_HINGED: Array = [[2], [2, 0], [2, 1]]  # that build's parts, the wheels excepted


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


func test_parts_have_real_sizes() -> void:
	# Task 2: every part def on disk carries its own footprint in cells. The builder joins a body of
	# this size and ChPartRuntime.sample_rect / ChBehaviour._reach_box both measure it, so a def left
	# at ChPartDef's 1x1 default samples and reaches from a footprint the part does not have.
	var catalog := ChCatalog.load_default()
	for pair in [
		[&"ice_cream_mace", Vector2i(8, 4)],
		[&"cutter_chainsaw", Vector2i(10, 4)],
		[&"flamethrower", Vector2i(8, 4)],
		[&"hearth", Vector2i(6, 6)],
		[&"cutter_rocket", Vector2i(8, 3)],
		[&"corsair_harpoon", Vector2i(10, 3)],
		[&"ember_battery", Vector2i(5, 5)],
		[&"firebolt_launcher", Vector2i(8, 4)],
		[&"ring_of_fire", Vector2i(6, 6)],
		[&"freeze_charge", Vector2i(4, 4)],
		[&"strut", Vector2i(3, 8)],
		[&"wheel", Vector2i(12, 12)],
	]:
		var def: ChPartDef = catalog.part(pair[0])
		assert_true(def != null, "%s loads from res://game/data/parts" % [String(pair[0])])
		if def != null:
			assert_eq(def.size, pair[1], "%s carries its own footprint" % [String(pair[0])])
	_complete()


func test_chariot_shares_one_group() -> void:
	# Task 1's collision group: two bodies with an equal non-zero group never collide, so a whole
	# chariot (its chassis plus every part body) goes in one group. Its own parts stop grinding on
	# each other, and the pair of groups below is what keeps the other chariot hitting it: side 1 must
	# not land in side 0's group, or the two chariots would pass through each other.
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := ChCatalog.load_default()
	var mounts: Array = [[[0], &"wheel"], [[1], &"wheel"], [[2], &"strut"], [[2, 0], &"ice_cream_mace"]]
	var left: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", mounts), catalog, 0, ORIGIN, false)
	var right: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", mounts), catalog, 1, ORIGIN + Vector2(200, 0), false)
	assert_true(left != null and right != null, "both builds return a runtime")
	assert_eq(left.chassis.collision_group, 1, "side 0's chassis is in group 1")
	for part in left.parts:
		assert_eq(part.body.collision_group, 1, "and so is the part body at %s" % [part.path])
	assert_eq(right.chassis.collision_group, 2, "side 1's chassis is in group 2, not side 0's")
	for part in right.parts:
		assert_eq(part.body.collision_group, 2, "and so is the part body at %s" % [part.path])
	world.free()
	_complete()


# Each hinged part of a strut-pair build and how far its body sits from the anchor its layout gives
# it, as [[path, cells]]. A helper rather than a test: the runner's test methods take no arguments,
# and a helper that awaited frames would never resume (see tests/run_tests.gd).
func _hinged_drift(runtime: ChChariotRuntime, layout: ChChariotLayout, catalog: ChCatalog) -> Array:
	var drift: Array = []
	for mount in STRUT_HINGED:
		var steps: Array[int] = _typed_path(mount)
		var part := _part_of(runtime, steps)
		assert_true(part != null, "the part at %s mounted" % [steps])
		if part == null:
			continue
		drift.append([steps, part.body.global_position.distance_to(
			runtime.chassis.global_position + layout.anchor_of(steps, catalog))])
	return drift


func test_strut_pair_holds_still() -> void:
	# Plan Review Focus 4, with real sizes: the strut's two extension slots are 4 cells apart, so the
	# 10x4 Chainsaw and the 8x4 Flamethrower bolted to them overlap each other by 5 cells, and both
	# overlap the hull the strut stands on. In one collision group that overlap costs nothing: the rig
	# still holds its shape and settles rather than shoving its own parts off the hull.
	# The control is the same build at the far end of the arena with every body put back in group 0, the
	# way it was before build() wrote side + 1: that rig has no group to hide its own overlaps, and it
	# comes apart. Same world, same 180 ticks, so the only difference is the group.
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := ChCatalog.load_default()
	var layout: ChChariotLayout = _mount(&"cutter", STRUT_MOUNTS)
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), layout, catalog, 0, ORIGIN, false)
	assert_true(runtime != null, "the build returns a runtime")
	var loose_layout: ChChariotLayout = _mount(&"cutter", STRUT_MOUNTS)
	var loose: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), loose_layout, catalog, 0, ORIGIN + Vector2(200, 0), false)
	assert_true(loose != null, "the control build returns a runtime")
	var loose_bodies: Array = [loose.chassis]
	for part in loose.parts:
		loose_bodies.append(part.body)
	for body in loose_bodies:
		# The control: every body of this rig back in group 0, the value before build() wrote side + 1.
		body.collision_group = 0
		assert_eq(body.collision_group, 0, "the control rig's body is back in group 0")
	# simulating off: the world ticks once per awaited frame of its own too, and how many physics
	# frames land between two process frames is headless-frame-rate dependent. Stepping by hand makes
	# these STRUT_FRAMES exactly that many Box2D ticks, which is what makes the numbers below stable.
	world.simulating = false
	var rotations: Array[float] = []
	for _tick in range(STRUT_FRAMES):
		await Engine.get_main_loop().process_frame
		world.step(1)
		rotations.append(runtime.chassis.global_rotation)
	# A hinged part (the builder limits its hinge to one angle) that has moved off its layout anchor was
	# pushed out of the build. Measured at rest, in one group: strut 0.71, Chainsaw 1.37, Flamethrower
	# 1.21 cells. The control rig's same three read 2.09, 3.28 and 3.43 once the group is off, so what
	# the window below measures is the collision group, not just the sizes.
	for pair in _hinged_drift(runtime, layout, catalog):
		assert_true(pair[1] < 1.5,
			"%s still sits %.2f cells from its layout anchor" % [pair[0], pair[1]])
	for pair in _hinged_drift(loose, loose_layout, catalog):
		assert_true(pair[1] > 1.5,
			"%s left its layout anchor by %.2f cells with its bodies in group 0" % [pair[0], pair[1]])
	# The wheels are the exception that 1.5-cell rule cannot carry: PixelWheelJoint is a spring
	# (WHEEL_FREQUENCY 5), so the distance from the layout anchor is the suspension compressing under the
	# build's own weight, and a 12-cell disc on this body cannot even reach its own anchor. Measured at
	# rest: 1.78 and 1.81 cells, which is what the 2.5-cell window and the 0.2-cell pairing below pin. A
	# wheel's travel has never been inside 1.5 cells, whatever the build. What the pairing keeps is both
	# springs compressing together: a build that rolled, threw a wheel or dragged its hull on the rock
	# moves them apart.
	var wheel_path: Array[int] = _typed_path([0])
	var wheel_other_path: Array[int] = _typed_path([1])
	var wheel := _part_of(runtime, wheel_path)
	var wheel_other := _part_of(runtime, wheel_other_path)
	assert_true(wheel != null and wheel_other != null, "both wheels mounted")
	if wheel != null and wheel_other != null:
		var chassis_at := runtime.chassis.global_position
		var pressed := [
			wheel.body.global_position.distance_to(chassis_at + layout.anchor_of(wheel_path, catalog)),
			wheel_other.body.global_position.distance_to(
				chassis_at + layout.anchor_of(wheel_other_path, catalog))]
		assert_true(pressed[0] < 2.5 and pressed[1] < 2.5,
			"both wheels stay under 2.5 cells of suspension travel (%.2f, %.2f)" % [pressed[0], pressed[1]])
		assert_near(pressed[0], pressed[1], 0.2, "and both springs compressed by the same amount")
	# Measured over those last 30 frames: 0.00007 rad, the rig holding a static lean of -0.138 rad.
	assert_true(absf(rotations[STRUT_FRAMES - 1] - rotations[STRUT_FRAMES - STRUT_WINDOW]) < 0.2,
		"the chassis turned %.3f rad over the last %d frames"
		% [absf(rotations[STRUT_FRAMES - 1] - rotations[STRUT_FRAMES - STRUT_WINDOW]), STRUT_WINDOW])
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


func test_bodies_hide_and_carry_a_visual() -> void:
	# Task 6: a body stops drawing its own texture (self_modulate alpha 0 hides only the node's own
	# draw) and a "Visual" Sprite2D child carries the art and the juice, so collision, mass and the
	# body transform are the ones Box2D joined while everything that wobbles lives one node down.
	var world: PixelWorld = await make_world()
	_ground(world)
	var layout: ChChariotLayout = _mount(&"dozer", [[[0], &"wheel"], [[2], &"strut"]])
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), layout, ChCatalog.load_default(), 0, ORIGIN, false)
	assert_true(runtime != null, "the build returns a runtime")
	# The chassis and every part body, the one list both loops below walk.
	var bodies: Array = [runtime.chassis]
	for part in runtime.parts:
		bodies.append(part.body)
	for body in bodies:
		assert_true(body.self_modulate.a == 0.0, "the body draws nothing of its own")
		var visual: Node2D = ChChariotBuilder.visual_of(body)
		assert_true(visual is Sprite2D, "the body carries a Visual Sprite2D")
		if visual == null:
			continue
		# centred, at the body's origin: that is where PixelRigidBody::_draw puts the same texture
		# (draw_texture(texture, -texture->get_size() * 0.5)), so the art does not move.
		assert_true((visual as Sprite2D).texture == body.texture, "the visual draws the body's texture")
		assert_true((visual as Sprite2D).centered, "centred on the body's origin")
		assert_eq(visual.position, Vector2.ZERO, "at the body's origin")
		assert_eq((visual as Sprite2D).offset, Vector2.ZERO, "and with no offset, so the texture stays put")
		assert_true(ChJuice.of(body) == null, "the juice hangs on the visual, not the body")
		assert_true(ChJuice.of(visual) != null, "the visual carries a ChJuice")
	assert_eq(runtime.chassis_visual, ChChariotBuilder.visual_of(runtime.chassis),
		"the runtime names the chassis visual")
	for part in runtime.parts:
		assert_eq(part.visual, ChChariotBuilder.visual_of(part.body),
			"the runtime names the part visual at %s" % [part.path])
	world.free()
	_complete()


func test_visual_does_not_change_collision() -> void:
	# The shape, and so the mass, comes from the texture's pixels and not from the sprite that draws
	# them: the same build with its visuals freed joins bodies of the same mass.
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := ChCatalog.load_default()
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[0], &"wheel"], [[2], &"strut"]]), catalog, 0, ORIGIN, false)
	# The control build sits 200 cells along, out of the first one's way.
	var bare: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[0], &"wheel"], [[2], &"strut"]]), catalog, 0,
		ORIGIN + Vector2(200, 0), false)
	assert_true(runtime != null and bare != null, "both builds return a runtime")
	ChChariotBuilder.visual_of(bare.chassis).free()
	for part in bare.parts:
		ChChariotBuilder.visual_of(part.body).free()
	# One world.step per awaited frame, as test_settles_on_ground does: the bodies join on the
	# engine's internal physics tick, which a single step(60) call would not catch.
	for _tick in range(60):
		await Engine.get_main_loop().process_frame
		world.step(1)
	var chassis_mass: float = runtime.chassis.get_mass()
	assert_true(chassis_mass > 0.0, "the chassis joined the world")
	assert_eq(bare.chassis.get_mass(), chassis_mass, "the visual changes nothing about the chassis mass")
	for part in runtime.parts:
		var bare_part := _part_of(bare, part.path)
		assert_true(bare_part != null, "the control build mounted the part at %s" % [part.path])
		if bare_part == null:
			continue
		var mass: float = part.body.get_mass()
		assert_true(mass > 0.0, "the part body at %s joined the world" % [part.path])
		assert_eq(bare_part.body.get_mass(), mass,
			"and nothing about the mass at %s" % [part.path])
	world.free()
	_complete()


func test_kicked_visual_leaves_body_alone() -> void:
	# Every wobble is the visual's: a kick moves the child sprite, and the body Box2D joined keeps its
	# transform, so juice can never fight the collision.
	var world: PixelWorld = await make_world()
	_ground(world)
	var runtime: ChChariotRuntime = ChChariotBuilder.build(
		world, _parent(), _mount(&"dozer", [[[0], &"wheel"], [[2], &"strut"]]),
		ChCatalog.load_default(), 0, ORIGIN, false)
	# simulating off: no physics tick can move the body between the two reads below, so the transform
	# is the same value before and after the kick unless something wrote it.
	world.simulating = false
	var part := _part_of(runtime, [2])
	assert_true(part != null, "the strut mounted")
	if part == null:
		world.free()
		_complete()
		return
	var before: Transform2D = part.body.global_transform
	var juice := ChJuice.of(part.visual)
	assert_true(juice != null, "the strut's visual carries a ChJuice")
	if juice == null:
		world.free()
		_complete()
		return
	juice.kick(9.0, 3.0)
	juice.advance(0.1)
	assert_eq(part.body.global_transform, before, "the kick left the body's transform alone")
	assert_eq(part.body.scale, Vector2.ONE, "and the body's scale")
	assert_true(part.visual.scale != Vector2.ONE, "while the visual's scale moved")
	world.free()
	_complete()
