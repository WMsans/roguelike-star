class_name ChChariotRuntime extends RefCounted

# One live chariot: the chassis body ChChariotBuilder joined from ChBodyDef, plus the parts hanging
# off it. `parts` is depth-first, so a part comes before what is bolted onto it.
# hp is an int per the brief, so fractional damage (Task 10's burn tick) reaches it in whole points
# held back in a float accumulator where the damage is dealt: the convention ChEnergy and ChPartRuntime
# already use. Nothing here keeps that accumulator, since this task's API takes no damage.

var side: int = 0  # 0 = the player's chariot, 1 = the enemy's (the ChariotLayout index)
var body_def: ChBodyDef = null  # the def this chassis was built from
var hp: int = 0  # body HP left; the builder seeds it from body_def.hp
var energy: ChEnergy = null  # the body's pool, capped and regenerating from body_def
var chassis: PixelRigidBody = null  # the one body that carries the whole chariot's HP
var parts: Array[ChPartRuntime] = []  # every part, in the order the builder mounted them

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
