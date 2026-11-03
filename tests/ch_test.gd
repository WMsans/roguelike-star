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
