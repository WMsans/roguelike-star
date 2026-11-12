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
var core: Texture2D = null  # the bolt's own body, defaulted to a disc in the launcher's colour
var _core: Sprite2D = null  # the node that core is drawn on, made on the first frame
var _puff_owed: float = 0.0  # cells flown since the last puff
var _puff_turn: int = 0  # which of TRAIL_FX the next puff is

const LIFE := 3.0  # seconds before the bolt gives up
# The trail's mass is baked and the world keeps it: a puff is dropped where the bolt was and stays there,
# so the emitter moves and its pixels do not. Distance rather than time, so a lobbed bolt and a straight
# one both read continuous and a paused fight drops nothing.
const TRAIL_FX := [&"puff_fire", &"puff_smoke"]  # taken in turn: a wisp of flame under the smoke
const PUFF_EVERY := 8.0  # cells between puffs
const PUFF_OFFSET := 3.0  # cells behind the bolt's nose, where a trail begins
# The sparks on top of it, in the world's own pool: a share of the flight speed rather than the whole of
# it, so the bolt outruns what it threw and the stream falls behind it instead of riding it.
const TRAIL_PER_TICK := 3  # pixels a frame, capped again by ChFeedbackParticles.budget
const TRAIL_SPEED_SHARE := 0.3
const TRAIL_SPREAD := 1.0  # radians
const TRAIL_LIFE := 0.35  # seconds, and the fade runs over it
const CORE_DIAMETER := 3  # cells across, bigger than the 1-cell pixels of its own trail

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
	var from := global_position
	var to := from + bolt_velocity * delta
	global_position = to
	_draw_core()
	_drop_puffs(from.distance_to(to))
	_throw_trail()
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

func _draw_core() -> void:
	# The bolt's body, which is the one look that belongs to it: a body is its own emitter. Made on the
	# first frame rather than in setup, because the behaviour sets `core` after that call.
	if _core == null or not is_instance_valid(_core):
		_core = Sprite2D.new()
		_core.texture = core if core != null else ChTextures.disc(CORE_DIAMETER, _core_colour())
		_core.z_index = ChFx.Z  # the same rule as a baked effect: a bolt reads over the hulls it passes
		add_child(_core)
	# Mirrored, never rotated: a rotated sprite leaves the pixel grid the world is drawn on.
	_core.scale.x = -1.0 if bolt_velocity.x < 0.0 else 1.0


func _core_colour() -> Color:
	return launcher.def.color if launcher != null and launcher.def != null else Color.WHITE


func _throw_trail() -> void:
	# Emitted into the world's pool and never addressed again, so nothing the bolt does from here can
	# move a pixel that is already out. collides stays false: a trail that died on the first cell it
	# crossed would vanish inside the ground it is flying over.
	if battle.world == null:
		return
	var n := ChFeedbackParticles.budget(battle.world, TRAIL_PER_TICK)
	if n <= 0:
		return
	battle.world.spawn_visual_particles(_core_colour(), global_position, bolt_velocity * TRAIL_SPEED_SHARE,
		n, TRAIL_SPREAD, TRAIL_LIFE, 0.0, false)


func _drop_puffs(flew: float) -> void:
	# Only the world may own a baked effect, and a puff is one: it stays where it was born. The pool's
	# budget does not apply here — puffs are nodes, not particles — so a busy fight keeps its trail.
	if battle.world == null:
		return
	_puff_owed += flew
	while _puff_owed >= PUFF_EVERY:
		_puff_owed -= PUFF_EVERY
		var back := bolt_velocity.normalized() * PUFF_OFFSET
		if ChFx.spawn(battle.world, TRAIL_FX[_puff_turn], global_position - back, bolt_velocity) != null:
			_puff_turn = (_puff_turn + 1) % TRAIL_FX.size()


func _own_hull(met: Object) -> bool:
	# The bolt starts inside its own hull, so the body the segment meets at its own mount is not an
	# impact: a rocket that detonated on its launcher would never reach the fight at all.
	if met == null or not is_instance_valid(met):
		return false
	return battle.chariot_of_body(met) == battle.own(launcher)
