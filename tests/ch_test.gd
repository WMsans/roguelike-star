class_name ChTest extends RefCounted

# Assertions never raise: they append to `failures`, which run_tests.gd turns into a
# pass/fail count per `test_*` method.
var failures: Array[String] = []


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
	var root: SceneTree = Engine.get_main_loop()
	var world: PixelWorld = PixelWorld.new()
	world.material_set = load("res://game/materials/game_set.tres")
	world.arena = arena
	root.add_child(world)
	while not world.is_area_ready(arena):
		await root.process_frame
	return world
