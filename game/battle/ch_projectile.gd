extends Node2D

class_name ChProjectile

# Task 13's flying part: a bolt that moves each physics frame and tests the segment it crossed with
# world.raycast, so a fast shot cannot tunnel the hull it passed between two frames. The behaviour
# that fired it owns what an impact means (the blast, the hit, the fire); this only flies, reports
# once, and frees itself. The world runs its own simulation steps on the same physics frame, so the
# bolt steps by the delta it is handed rather than driving a second loop of its own.

var battle: ChBattleContext = null  # the fight the bolt flies in
var launcher: ChPartRuntime = null  # the part that fired it
var bolt_velocity: Vector2 = Vector2.ZERO  # cells per second
var bolt_gravity: float = 0.0  # cells per second squared, 0 for a straight shot
var impact: Callable = Callable()  # called with the raycast dict on the hit
var life: float = 0.0  # seconds flown
var trail: ChFx = null  # the bolt's own look (a ChFx loop parented here), turned along its flight

const LIFE := 3.0  # seconds before the bolt gives up

func setup(ctx: ChBattleContext, source: ChPartRuntime, velocity: Vector2, gravity: float,
	on_impact: Callable) -> void:
	# The bolt starts where its part points and takes the callback the behaviour wants for an
	# impact. Callers add the node to the tree first: _physics_process only runs on the next frame.
	battle = ctx
	launcher = source
	bolt_velocity = velocity
	bolt_gravity = gravity
	impact = on_impact

func _physics_process(delta: float) -> void:
	# A bolt with no world to query sits until its setup runs, rather than raising in a frame.
	if battle == null or battle.world == null:
		return
	# The fight's clock keeps this bolt's own age, so a paused fight does not spend the 3 s.
	life += delta
	# The gravity is an acceleration in cells per second squared, so it lands on the velocity before
	# the step does: a lobbed bolt falls more every frame it flies.
	bolt_velocity.y += bolt_gravity * delta
	if trail != null and is_instance_valid(trail):
		trail.face(bolt_velocity)
	var from := global_position
	var to := from + bolt_velocity * delta
	global_position = to
	# shortcut: the world's own transform is the arena's identity in the battle scene and the tests,
	# so the bolt's global position is already the cell space raycast wants.
	var shot: Dictionary = battle.world.raycast(from, to)
	# The dict answers empty for nothing met; a terrain hit carries a material and a null collider.
	if not shot.is_empty() and not _own_hull(shot.get("collider")):
		# Leaving the arena or its age are checked here rather than after, so a bolt that met the
		# border reports the impact it made before it stops.
		if impact.is_valid():
			impact.call(shot)
		queue_free()
		return
	# A bolt that flew out of the arena, or past its 3 s, stops without calling anything.
	if life >= LIFE or not Rect2(battle.world.arena).has_point(to):
		queue_free()

func _own_hull(met: Object) -> bool:
	# The bolt starts inside its own hull, so the body the segment meets at its own mount is not an
	# impact: a rocket that detonated on its launcher would never reach the fight at all.
	if met == null or not is_instance_valid(met):
		return false
	return battle.chariot_of_body(met) == battle.own(launcher)
