class_name ChTest extends RefCounted

# Assertions never raise: they append to `failures`, which run_tests.gd turns into a
# pass/fail count per `test_*` method.
# CONTRACT: every `test_*` method calls `_complete()` as its LAST statement. GDScript has
# no exceptions, so a body that dies mid-way (runtime error) just stops; the runner treats
# a missing `_complete()` bump as a FAIL instead of a silent PASS.
const WAIT_FRAMES = 600

var failures: Array[String] = []
var completed: int = 0


func _complete() -> void:
	completed += 1


func _record(what: String, msg: String) -> void:
	if msg != "":
		what += ": " + msg
	failures.append(what)


func assert_eq(a, b, msg := "") -> void:
	if a != b:
		_record("assert_eq: got %s, expected %s" % [a, b], msg)


func assert_true(c, msg := "") -> void:
	if not c:
		_record("assert_true: condition is false", msg)


func assert_near(a: float, b: float, eps := 0.001, msg := "") -> void:
	if absf(a - b) > eps:
		_record("assert_near: %s and %s differ by more than %s" % [a, b, eps], msg)


func make_world(arena := Rect2i(0, 0, 480, 180)) -> PixelWorld:
	# Kept untyped: with a `: SceneTree` annotation the frame wait below never resumes (the
	# coroutine stops at the await), so look these up dynamically.
	var main_loop = Engine.get_main_loop()
	var world: PixelWorld = PixelWorld.new()
	world.material_set = load("res://game/materials/game_set.tres")
	world.arena = arena
	# concrete is the indestructible wall, so blasts in later tests cannot open the arena.
	# shortcut: fixed here; add a border parameter if a test ever needs another wall.
	world.arena_border_material = &"concrete"
	# The arena path streams a window of chunks around target_cell() (the origin while follow_target
	# stays unset) and a chunk is 64 cells (addons/noita_engine/engine/core/coords.h: CHUNK), so the
	# radius has to reach the chunk holding the arena's far corner or is_area_ready(arena) never
	# turns true. floori matches chunk_of()'s floor_div: GDScript int division truncates towards zero,
	# which would read the wrong chunk for a negative arena start.
	# shortcut: the window is centred on chunk (0, 0), which holds while make_world leaves follow_target
	# unset; a test that follows a node has to widen around that chunk instead.
	var near_chunk := Vector2i(floori(arena.position.x / 64.0), floori(arena.position.y / 64.0))
	var far_chunk := Vector2i(floori((arena.end.x - 1) / 64.0), floori((arena.end.y - 1) / 64.0))
	world.load_radius = Vector2i(maxi(absi(near_chunk.x), absi(far_chunk.x)),
		maxi(absi(near_chunk.y), absi(far_chunk.y)))
	# The runner's main loop is a SceneTree script, so nodes go under its root viewport.
	main_loop.get_root().add_child(world)
	# _ready() bails out when material_set is missing or does not compile, and then
	# is_area_ready() stays false forever, so the wait is capped: a broken world becomes
	# a recorded failure instead of hanging the whole run (~4s at this cap).
	var frames := 0
	while not world.is_area_ready(arena):
		if frames >= WAIT_FRAMES:
			_record("make_world: arena %s not ready after %d frames (missing or invalid material_set)" % [arena, frames], "")
			return world
		frames += 1
		# The main loop ticks its own process_frame; wait on it, not the world.
		await main_loop.process_frame
	# shortcut: returns the half-built world anyway; callers hit their own assertions, and
	# the recorded failure above already fails the test.
	return world
