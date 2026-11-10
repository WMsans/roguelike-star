class_name ChTest extends RefCounted

# Assertions never raise: they append to `failures`, which run_tests.gd turns into a
# pass/fail count per `test_*` method.
# CONTRACT: every `test_*` method calls `_complete()` as its LAST statement. GDScript has
# no exceptions, so a body that dies mid-way (runtime error) just stops; the runner treats
# a missing `_complete()` bump as a FAIL instead of a silent PASS.
# `_complete()` also frees what the test built (see _track), which is why it stays the last
# statement: nothing may read a node after it.
const WAIT_FRAMES = 600

var failures: Array[String] = []
var completed: int = 0
# What this test instance added to the tree, freed by _complete(). The suite used to leave most
# of it behind (38 make_world calls against 14 world.free(), and every _parent() Node2D plus the
# bodies and joints under it never freed), which is what made Godot report 321 leaked ObjectDB
# instances at exit and left the run's exit code useless as the plan's gate.
var _tracked: Array[Node] = []


func _track(node: Node) -> Node:
	# One place to keep what a test had to put in the tree, so freeing it is not a per-test chore.
	_tracked.append(node)
	return node


func _complete() -> void:
	# Nodes are freed in the order they were made: a PixelRigidBody or joint leaves before the world
	# it joined, so the body detaches from a Box2D world that is still alive (PixelWorld's own
	# predelete detaches whatever is left, but only for a world that outlives its bodies).
	for node in _tracked:
		if is_instance_valid(node):
			node.free()
	_tracked.clear()
	completed += 1


func _parent() -> Node2D:
	# The node a test hangs built bodies under; the arena lives in root space, so this goes under
	# the runner's root viewport (the runner's main loop is a SceneTree script).
	var parent := Node2D.new()
	Engine.get_main_loop().get_root().add_child(parent)
	return _track(parent)


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


# --- Fight fixtures -------------------------------------------------------------------------------
# test_battle.gd and test_battle_hud.gd both drive fights on the same two builds, so the builds live
# here once. A second copy is not a style problem: _body_with_hp encodes how a Resource's duplicate()
# behaves on this build, and a copy that got that wrong would fail as a mystery HP override in an
# unrelated fight test rather than at the copy site.
func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func _player_layout() -> ChChariotLayout:
	# The brief's "player Cutter + Rocket": two wheels in the Cutter's low slots (y = 4.5) and the
	# Rocket in slot 3 (6, -3), unflipped so it fires +x, which is the way the player faces.
	var layout := ChChariotLayout.new()
	layout.body_id = &"cutter"
	for mount in [[[0], &"wheel"], [[1], &"wheel"], [[3], &"cutter_rocket"]]:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout


func _enemy_layout() -> ChChariotLayout:
	# The fixed enemy of spec 5.9, as data: game/data/enemies/dozer_cook.tres. ChBattle mirrors it
	# (mirrored() plus the builder's mirror_x) so its parts face the player.
	var loaded: ChChariotLayout = ResourceLoader.load("res://game/data/enemies/dozer_cook.tres")
	assert_true(loaded != null, "the dozer_cook layout loads")
	# A copy with the layout's own max_hp cleared: fight tests size the enemy through the catalog's
	# body HP (_fight_catalog), and a layout max_hp would win over it. Mirroring twice is a deep copy
	# with every flip as it was, so the shared resource is never touched.
	var layout := loaded.mirrored().mirrored()
	layout.max_hp = 0
	return layout


func _body_with_hp(loaded: ChBodyDef, hp: int) -> ChBodyDef:
	# A body def with its HP replaced; copy() writes every field across (see ChBodyDef.copy).
	var out := loaded.copy()
	out.hp = hp
	return out


func _fight_catalog(enemy_hp: int, player_hp: int = 0) -> ChCatalog:
	# The slice's defs with the cook's body HP overridden (30 means one Rocket hit ends the enemy);
	# pass player_hp to raise the player's Cutter too, which is how a fight nobody dies in is forced.
	# The cook's body is read off dozer_cook.tres (a Corsair since the bodies spec), so moving the cook
	# to another hull keeps sizing the enemy. A player on that same body gets enemy_hp as well.
	# shortcut: the override travels as a catalog because a def on disk is shared by every test in
	# the run; mutating it would make a later test's enemy body fragile.
	var cook_body: StringName = ResourceLoader.load("res://game/data/enemies/dozer_cook.tres").body_id
	var loaded := ChCatalog.load_default()
	var parts: Array[ChPartDef] = []
	for def in loaded.parts.values():
		parts.append(def)
	var bodies: Array[ChBodyDef] = []
	for def in loaded.bodies.values():
		if def.id == cook_body:
			bodies.append(_body_with_hp(def, enemy_hp))
		elif player_hp > 0 and def.id == &"cutter":
			bodies.append(_body_with_hp(def, player_hp))
		else:
			bodies.append(def)
	return ChCatalog.from_defs(parts, bodies)


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
	main_loop.get_root().add_child(_track(world))
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
