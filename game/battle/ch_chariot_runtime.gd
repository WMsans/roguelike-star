class_name ChChariotRuntime extends RefCounted

# One live chariot: the chassis body ChChariotBuilder joined from ChBodyDef, plus the parts hanging
# off it. `parts` is depth-first, so a part comes before what is bolted onto it.

var side: int = 0  # 0 = the player's chariot, 1 = the enemy's (the ChariotLayout index)
var body_def: ChBodyDef = null  # the def this chassis was built from
var hp: int = 0  # body HP left; the builder seeds it from max_hp
# Starting HP: the layout's max_hp, set by the builder. Unset (0) reads as the body's own hp, so a
# runtime made by hand (the HUD tests) still has a max to measure against.
var max_hp: int = 0:
	get:
		if max_hp > 0 or body_def == null:
			return max_hp
		return body_def.hp
var energy: ChEnergy = null  # the body's pool, capped and regenerating from body_def
var chassis: PixelRigidBody = null  # the one body that carries the whole chariot's HP
var chassis_visual: Node2D = null  # the chassis body's "Visual" child (the builder's, Task 6)
var parts: Array[ChPartRuntime] = []  # every part, in the order the builder mounted them

var statuses := ChStatuses.new()  # the body's statuses
var last_anchor: Vector2 = Vector2.ZERO  # the last chassis reading, for a freed chassis
var _mass_settled := false  # settle_mass has applied the def mass

func anchor_world() -> Vector2:
	if chassis != null and is_instance_valid(chassis):
		last_anchor = Vector2(chassis.global_position.x, chassis.global_position.y)
	return last_anchor

func status_box() -> Rect2:
	return ChBattle.hull_box(self)

func sample_rect() -> Rect2i:
	# The hull box in whole cells, grown by the part margin.
	var box := status_box()
	var lo := Vector2i(floori(box.position.x), floori(box.position.y))
	var hi := Vector2i(ceili(box.end.x), ceili(box.end.y))
	var m := Vector2i(ChPartRuntime.SAMPLE_MARGIN, ChPartRuntime.SAMPLE_MARGIN)
	return Rect2i(lo - m, hi - lo + m * 2)

func wheels() -> Array[ChPartRuntime]:
	# The parts the builder motorised, recognised by the wheel tag on the def (ChPartDef.is_wheel).
	var out: Array[ChPartRuntime] = []
	for part in parts:
		if part.def != null and part.def.is_wheel():
			out.append(part)
	return out


func drive_cost() -> float:
	# The drive's price per second: the energy_per_second of every unbroken wheel. A frozen wheel
	# still counts (the spec says unbroken), and a broken one is out of the fight.
	var total := 0.0
	for part in parts:
		if part.def != null and part.def.is_wheel() and not part.broken:
			total += part.def.energy_per_second
	return total


func drive(direction: float) -> void:
	# The demo car's rule: the motor runs while a direction is held. A frozen or broken wheel gets
	# the motor off with speed 0 (spec 5.7: a wheel's motor locks).
	# A chariot with no wheels has nothing to set, so this does nothing (Review Focus 1).
	# shortcut: a wheel off the ground still gets its motor set: Box2D spins it and the chariot
	# stays put, which is the physics' answer rather than an error to paper over here.
	for wheel in wheels():
		# Task 10's break_part frees the joint so the wheel falls off: nothing left to drive.
		var joint = wheel.joint
		if not is_instance_valid(joint):
			continue
		var disabled := wheel.broken or wheel.is_frozen()
		joint.enable_motor = not disabled and direction != 0.0
		joint.motor_speed = 0.0 if disabled else direction * wheel.def.wheel_speed

func settle_mass() -> void:
	# A pixel body joins with its pixels' mass (the engine reads props.mass at join only for a
	# texture-less box), so the def's mass is set once, on the first call after the chassis has
	# joined (set_mass on a joined body rescales its mass data, inertia with it). One-shot: anything
	# that changes the chassis mass later (a part loss, a payoff) is never put back.
	if _mass_settled or body_def == null or body_def.mass <= 0.0 or not is_instance_valid(chassis):
		return
	if chassis.get_mass() > 0.0:
		chassis.mass = body_def.mass
		_mass_settled = true

func is_dead() -> bool:
	return hp <= 0

func break_part(part: ChPartRuntime, ctx: ChBattleContext) -> void:
	# A part that broke is disabled for the rest of the fight (§5.2): its joint is removed, so it
	# falls off into the sand, and everything bolted onto it falls with it.
	# shortcut: the brief names break_part(part); ctx is provisional, since unsubscribing the part's
	# behaviour and announcing PART_BROKEN both need the battle's bus, which a chariot does not own.
	if part == null or part.broken:
		# An already-broken part answers without announcing itself again, so a later hit on it or a
		# second path through the tree cannot double the event a listener counts.
		return
	part.broken = true
	var behaviour = part.behaviour
	if behaviour != null:
		# The behaviour is the listener it subscribed as, per ChBehaviour.setup's contract, and the
		# bus never drops a listener by itself, so this is the whole seam that takes it out. It runs
		# before the emit below, so a broken part hears nothing, even its own PART_BROKEN.
		ctx.bus.unsubscribe_all(behaviour)
		# The look goes with the part: a looping fx the behaviour spawned rides the world, so with no
		# process left to stop it, teardown is what keeps it from playing on the wreck forever.
		behaviour.teardown()
	if part.joint != null and is_instance_valid(part.joint):
		# The joint goes, so the body has nothing holding it and falls. queue_free rather than free,
		# since a joint is a node in the tree and Godot frees a queued node at the frame's end.
		# shortcut: that frame boundary is why a test asserting the joint is gone reads it after a
		# frame, which is how the break test reads the pair after its further ticks.
		part.joint.queue_free()
	# The part's own body is left in the world: a broken part falls rather than vanishes, and nothing
	# in the chariot's parts list carries its joint any more, so a later hit on the fallen body
	# resolves through no chariot and ChBattleContext.deal_hit drops it.
	var event := ChEvent.new()
	event.type = ChEvent.PART_BROKEN
	event.side = side
	event.source = part
	event.position = part.anchor_world()
	event.data = {"part": part}
	ctx.bus.emit(event)
	# Everything bolted onto a broken part breaks with it: the layout is a tree, and a child falls
	# with its parent, so each one stops being ready, loses its behaviour's listener and loses its
	# joint through this same step list, one level down.
	for child in part.children:
		# The guard above is what keeps a part reached twice from announcing itself twice, so the
		# recursion needs no visited set of its own.
		break_part(child, ctx)
