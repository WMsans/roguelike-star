extends ChTest

# Button & bodies Task 7: no body shape is unplayable. Each body, on its two wheels, drives the real
# arena and lands upright. A fight nobody presses in, with the drive replaced (ChBattle.drivers); it
# ends on the tick the test wants by zeroing the enemy's HP, since a battle may only be freed after
# `finished` (ChBattle.start's contract).

const BODY_IDS: Array[StringName] = [&"cutter", &"dozer", &"corsair"]
const TALL_HP := 100000


func _run(body_id: StringName, drive: float, ticks: int, later_mass: float = 0.0) -> Dictionary:
	# later_mass > 0 sets the player's chassis mass by hand halfway through, the way a part loss or a
	# mass payoff would.
	# Both sides drive the same way, so the enemy pulls away instead of standing in the way.
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	battle.pressers = [func(_b, _s): return false, func(_b, _s): return false]
	battle.drivers = [func(_b, _s): return drive, func(_b, _s): return drive]
	Engine.get_main_loop().get_root().add_child(battle)
	var seen := {"start": NAN, "moved": 0.0, "max_rot": 0.0, "end_rot": 0.0, "ticks": 0, "mass": 0.0}
	battle.stepped.connect(func(ctx: ChBattleContext):
		var hull: Node2D = ctx.chariots[0].chassis
		if is_nan(seen.start):
			seen.start = hull.global_position.x
		var rot := absf(wrapf(hull.global_rotation, -PI, PI))
		seen.moved = maxf(seen.moved, absf(hull.global_position.x - seen.start))
		seen.max_rot = maxf(seen.max_rot, rot)
		seen.end_rot = rot
		seen.mass = ctx.chariots[0].chassis.get_mass()
		seen.ticks += 1
		if later_mass > 0.0 and seen.ticks == ticks / 2:
			ctx.chariots[0].chassis.mass = later_mass
		if seen.ticks >= ticks:
			ctx.chariots[1].hp = 0)
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	assert_true(layout.place(_typed_path([0]), &"wheel") and layout.place(_typed_path([1]), &"wheel"),
		"%s takes two wheels" % body_id)
	await battle.start(layout, _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP), 12345)
	battle.free()
	return seen


func test_each_body_drives_the_arena() -> void:
	for id in BODY_IDS:
		var seen := await _run(id, 1.0, 600)
		assert_true(seen.moved >= 100.0, "%s drove %.1f cells in 600 ticks" % [id, seen.moved])
		assert_true(seen.max_rot < PI / 2, "%s stayed wheels-down (max |rotation| %.2f)" % [id, seen.max_rot])
	_complete()


func test_each_body_lands_upright() -> void:
	for id in BODY_IDS:
		var seen := await _run(id, 0.0, 120)
		assert_true(seen.end_rot < 0.3, "%s landed at |rotation| %.2f" % [id, seen.end_rot])
	_complete()


func test_body_mass_reaches_the_physics() -> void:
	# A pixel body joins with the mass of its pixels; a def's mass has to win over it once joined, or
	# the Barge is no heavier than its outline and nothing it shoves feels the difference.
	for id in BODY_IDS:
		var def: ChBodyDef = ChCatalog.load_default().body(id)
		if def.mass <= 0.0:
			continue
		var seen := await _run(id, 0.0, 30)
		assert_near(seen.mass, def.mass, 0.5, "%s chassis mass" % id)
		# The def's mass is applied once at join: a later change is not put back on the next tick.
		var changed := await _run(id, 0.0, 30, 123.0)
		assert_near(changed.mass, 123.0, 0.5, "%s keeps a mass set after join" % id)
	_complete()
