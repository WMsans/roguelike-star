class_name ChChariotBuilder extends RefCounted

# Turns a ChariotLayout into bodies: one chassis PixelRigidBody from ChBodyDef, plus one body per
# part at its anchor, each hung on whatever carries it. A wheel gets the demo car's motorised
# PixelWheelJoint, everything else a PixelRevoluteJoint limited to one angle.
# Box2D works in cells, so its torques and frictions are the demo car's big numbers.

const MOTOR_TORQUE := 3e6
const WHEEL_FREQUENCY := 5.0
const WHEEL_FRICTION := 1.5  # rubber: the grip the demo car's wheels need on a sand pile
const WHEEL_ID := &"wheel"  # shortcut: one wheel type in the slice; a wheel set wants a flag on ChPartDef
const HULL_MATERIAL := &"wood"  # PixelRigidBody refuses an unknown pixel_material, so a def that leaves material empty is stamped in the hull material instead of joining nothing


static func build(world: PixelWorld, parent: Node, layout: ChChariotLayout, catalog: ChCatalog, side: int, origin: Vector2, mirror_x: bool) -> ChChariotRuntime:
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def == null:
		push_error("chariot builder: body id %s has no def, so nothing builds" % String(layout.body_id))
		return null
	var runtime: ChChariotRuntime = ChChariotRuntime.new()
	runtime.side = side
	runtime.body_def = body_def
	runtime.max_hp = layout.max_hp if layout.max_hp > 0 else body_def.hp
	runtime.hp = runtime.max_hp
	runtime.energy = ChEnergy.new(body_def.energy_cap, body_def.energy_regen)
	# One collision group per chariot (Task 1): two bodies with an equal non-zero group never collide,
	# so a part that overlaps its own hull or another part costs nothing, while terrain, projectiles
	# and the other chariot (whose group is side + 1 too) still hit every body here.
	var group := side + 1
	var hull := ChTextures.art(body_def.texture, mirror_x) if body_def.texture != null \
			else ChTextures.polygon(body_def.outline, body_def.size, body_def.color, mirror_x) if not body_def.outline.is_empty() \
			else ChTextures.box(body_def.size.x, body_def.size.y, body_def.color)
	runtime.chassis = _body(parent, world, hull, _material(body_def.material), body_def.size, origin, PixelRigidBody.SHAPE_HULL, group, body_def)
	runtime.chassis_visual = visual_of(runtime.chassis)
	# all_paths is depth-first, parent before child, so a joint always names a body already mounted.
	var mounted: Dictionary = {}  # layout path -> the part runtime built there
	for path in layout.all_paths():
		# all_paths hands back untyped slot indices; get_node and anchor_of want Array[int].
		var steps: Array[int] = []
		for index in path:
			steps.append(index)
		var node: ChSlotNode = layout.get_node(steps)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			push_error("chariot builder: part id %s at %s has no def, so it does not mount" % [String(node.part_id), steps])
			continue
		var holder: ChPartRuntime = null
		if steps.size() > 1:
			# A part bolted onto another part hangs on that part's body, not on the chassis.
			# A parent that mounted nothing (no def) has nothing to hold this one, so this skips too.
			holder = mounted.get(steps.slice(0, steps.size() - 1))
			if holder == null:
				push_error("chariot builder: %s has no parent part, so it does not mount" % [steps])
				continue
		var anchor := layout.anchor_of(steps, catalog)
		# A mirrored build mirrors the anchor only: the layout itself keeps its slot indices.
		# shortcut: only x negates, since a flip turns the build left/right rather than upside down.
		if mirror_x:
			anchor.x = -anchor.x
		var at := origin + anchor
		var wheel := def.id == WHEEL_ID
		# A wheel is a disc so Box2D joins a circle it can roll; everything else is a box hull.
		# The art faces +x, so it mirrors when the part's facing and the build's mirror disagree.
		var texture := ChTextures.art(def.texture, node.flipped != mirror_x) if def.texture != null \
				else ChTextures.disc(def.size.x, def.color) if wheel else ChTextures.box(def.size.x, def.size.y, def.color)
		# Every textured part but the wheel (outlined inside its disc) has a transparent background and no
		# outline of its own: it collides as its full box and is seen with a navy rim outside its shape.
		var hand := def.texture != null and not wheel
		var look := ChTextures.ringed(texture.get_image()) if hand else texture
		if hand:
			texture = ChTextures.solid(texture.get_image())
		var body := _body(parent, world, texture, _material(def.material), def.size, at, PixelRigidBody.SHAPE_CIRCLE if wheel else PixelRigidBody.SHAPE_HULL, group)
		(visual_of(body) as Sprite2D).texture = look
		if wheel:
			body.friction = WHEEL_FRICTION
		var other_body: PixelRigidBody = holder.body if holder != null else runtime.chassis
		var joint := _joint(parent, body, other_body, at, wheel)
		# Everything ChPartRuntime leaves unset (its defaults serve the fake bodies its tests use)
		# is seeded here from the def, since this is the only path that builds a live part.
		var part_runtime := ChPartRuntime.new()
		part_runtime.def = def
		part_runtime.side = side
		part_runtime.path = steps
		part_runtime.flipped = node.flipped
		part_runtime.integrity = def.integrity
		part_runtime.cooldown_left = def.cooldown
		part_runtime.charges_left = def.charges
		part_runtime.body = body
		part_runtime.visual = visual_of(body)
		if def.cooldown > 0.0:
			# Only a part the button fires can be "ready". White, because ChBattle tints it (HDR) when lit.
			# z -1 under the Visual so the ring never covers the art; hidden until a part is ready.
			var ring := Sprite2D.new()
			ring.name = "Outline"
			ring.texture = ChTextures.outline(look.get_image(), Color.WHITE)
			ring.centered = true
			ring.z_index = -1
			ring.visible = false
			body.add_child(ring)
			part_runtime.outline = ring
		part_runtime.joint = joint
		part_runtime.parent = holder
		if holder != null:
			holder.children.append(part_runtime)
		if def.behaviour != null:
			var behaviour = def.behaviour.new()
			# ChBehaviour's own contract: the behaviour drives a part, and it is the listener its
			# subscriptions key on, so the instance needs the part it drives before setup runs.
			behaviour.part = part_runtime
			part_runtime.behaviour = behaviour
		runtime.parts.append(part_runtime)
		mounted[steps] = part_runtime
	return runtime


static func visual_of(body: Node) -> Node2D:
	# The child sprite that draws a body's art (see _body). Null for anything the builder did not make.
	return body.get_node_or_null("Visual") as Node2D


static func _material(def_material: StringName) -> StringName:
	# PixelRigidBody refuses an unknown pixel_material at join, which would leave the body out of
	# the world entirely, so a def that names no material gets the hull material.
	if def_material == &"":
		return HULL_MATERIAL
	return def_material


static func _body(parent: Node, world: PixelWorld, texture: Texture2D, material: StringName, size: Vector2i, at: Vector2, shape: int, group: int, def: ChBodyDef = null) -> PixelRigidBody:
	var body := PixelRigidBody.new()
	body.texture = texture
	body.pixel_material = material
	body.shape = shape
	# Set before add_child, the way terrain_collision is: the setter calls apply_props(), and a body
	# joins the world on its first physics tick once it is in the tree, so the group is already on
	# the shape when Box2D first filters it.
	body.collision_group = group
	# A body def's grip and weight go on before add_child too; 0 / -1 keep the engine's own values.
	if def != null:
		# No-op for the physics: a pixel body joins with its pixels' mass, so Box2D never reads this.
		# It only records the def's mass on the node; ChChariotRuntime.settle_mass applies it after
		# the join.
		if def.mass > 0.0:
			body.mass = def.mass
		if def.friction > 0.0:
			body.friction = def.friction
		if def.restitution >= 0.0:
			body.restitution = def.restitution
	# body_size is not the joined shape, which comes from the texture's pixels: it is the footprint
	# ChPartRuntime sample_rect reads back through get_body_size.
	body.body_size = size
	body.position = at
	parent.add_child(body)
	# The body stops drawing its own texture; self_modulate reaches only the body's own draw, so a
	# "Visual" child carries the art and the juice. Everything that wobbles is that child's, which
	# leaves the collision, the mass and the body transform Box2D joined untouched.
	body.self_modulate = Color(1, 1, 1, 0)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = texture
	# Same pixels in the same place: PixelRigidBody::_draw draws the texture at -size * 0.5, which is
	# a centred sprite at the body's own origin.
	visual.centered = true
	body.add_child(visual)
	ChJuice.attach(visual)
	# Joining finds the world by this path first and the "pixel_world" group second; naming it keeps
	# the build tied to the world the caller handed over. get_path_to needs the body in the tree
	# already, so this runs after add_child.
	body.world = body.get_path_to(world)
	return body


static func _joint(parent: Node, part_body: PixelRigidBody, other_body: PixelRigidBody, anchor: Vector2, wheel: bool) -> Node:
	# The joint sits at the part's anchor, which is where Box2D pins the two bodies together.
	if wheel:
		var wheel_joint := PixelWheelJoint.new()
		wheel_joint.position = anchor
		parent.add_child(wheel_joint)
		wheel_joint.body_a = wheel_joint.get_path_to(other_body)
		wheel_joint.body_b = wheel_joint.get_path_to(part_body)
		wheel_joint.max_motor_torque = MOTOR_TORQUE
		wheel_joint.frequency = WHEEL_FREQUENCY
		return wheel_joint
	var hinge := PixelRevoluteJoint.new()
	hinge.position = anchor
	parent.add_child(hinge)
	hinge.body_a = hinge.get_path_to(other_body)
	hinge.body_b = hinge.get_path_to(part_body)
	# A part that is not a wheel hinges at one angle only, so it cannot swing free of the build.
	hinge.enable_limit = true
	hinge.lower_angle = 0.0
	hinge.upper_angle = 0.0
	return hinge
