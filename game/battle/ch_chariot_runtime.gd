class_name ChChariotRuntime extends RefCounted

# One live chariot: the chassis body ChChariotBuilder joined from ChBodyDef, plus the parts hanging
# off it. `parts` is depth-first, so a part comes before what is bolted onto it.
# hp is an int per the brief, so fractional damage reaches it in whole points, and the fraction that
# does not add up yet is held back in burn_damage_left: the convention ChEnergy keeps its regen in and
# ChPartRuntime keeps its lava wear in. ChDamage.burn_tick returns a float, so that is where the
# fraction has to wait, and ChBattleContext.tick is the one that pays it into hp.

var side: int = 0  # 0 = the player's chariot, 1 = the enemy's (the ChariotLayout index)
var body_def: ChBodyDef = null  # the def this chassis was built from
var hp: int = 0  # body HP left; the builder seeds it from body_def.hp
var energy: ChEnergy = null  # the body's pool, capped and regenerating from body_def
var chassis: PixelRigidBody = null  # the one body that carries the whole chariot's HP
var parts: Array[ChPartRuntime] = []  # every part, in the order the builder mounted them

var burn_damage_left: float = 0.0  # burn damage held back until it adds up to a whole HP point

const MOTOR_SPEED := 12.0  # rad/s at full drive, as the demo car's export
const WHEEL_ID := &"wheel"  # shortcut: one wheel type in the slice; a wheel set wants a flag on ChPartDef

func wheels() -> Array[ChPartRuntime]:
	# The parts the builder motorised. A wheel is recognised by its def id, the same rule the
	# builder uses to give a body a PixelWheelJoint.
	var out: Array[ChPartRuntime] = []
	for part in parts:
		if part.def != null and part.def.id == WHEEL_ID:
			out.append(part)
	return out

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
		joint.motor_speed = 0.0 if disabled else direction * MOTOR_SPEED

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
	# The part leaves the energy queue before it can be asked again: a waiting entry for a part that
	# is no longer in the fight would fire it later. The requester is the part itself, per
	# ChBattleContext.tick's request, which is what lets cancel find the entry by identity.
	energy.cancel(part)
	var behaviour = part.behaviour
	if behaviour != null:
		# The behaviour is the listener it subscribed as, per ChBehaviour.setup's contract, and the
		# bus never drops a listener by itself, so this is the whole seam that takes it out. It runs
		# before the emit below, so a broken part hears nothing, even its own PART_BROKEN.
		ctx.bus.unsubscribe_all(behaviour)
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
	# with its parent, so each one leaves the queue, loses its behaviour's listener and loses its
	# joint through this same step list, one level down.
	for child in part.children:
		# The guard above is what keeps a part reached twice from announcing itself twice, so the
		# recursion needs no visited set of its own.
		break_part(child, ctx)
