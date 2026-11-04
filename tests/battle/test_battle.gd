extends ChTest

# Task 15: the battle scene — ChEnemyAI's drive decision, ChBattle's result rule, and one real
# headless fight that ends.
# Seam: the world, the arena fill, the two builds, the fight's tick loop and the win/lose emit
# live once in game/battle/ch_battle.gd. The tests below start a fight and watch frames only, so
# the fight loop is never re-implemented here.
# ChBattle.start is a coroutine that awaits one frame per tick, so a fight test awaits it.
# The catalog the fight tests hand over is ChCatalog.load_default's content with the Dozer's HP
# overridden to 30 (the brief's "the enemy with HP overridden to 30"), so one Rocket hit ends it.
# shortcut: the enemy HP override travels as a hand-built catalog because a def on disk is shared
# by every test in the run; mutating it would make a later test's Dozer fragile.

const FIGHT_SECONDS := 60.0  # the brief's ceiling: a headless fight has to finish inside this
const TICK := 1.0 / 60.0
const ENEMY_HP := 30  # the Dozer's HP overridden


func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func _player_layout() -> ChChariotLayout:
	# The brief's "player Cutter + Rocket": two wheels in the Cutter's low slots (y = 3) and the
	# Rocket in slot 3 (6, -3), unflipped so it fires +x, which is the way the player faces.
	var layout := ChChariotLayout.new()
	layout.body_id = &"cutter"
	for mount in [[[0], &"wheel"], [[1], &"wheel"], [[3], &"cutter_rocket"]]:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout


func _enemy_layout() -> ChChariotLayout:
	# The fixed enemy of spec 5.9, as data: game/data/enemies/dozer_cook.tres. ChBattle mirrors it
	# (mirrored() plus the builder's mirror_x) so its parts face the player.
	var layout: ChChariotLayout = ResourceLoader.load("res://game/data/enemies/dozer_cook.tres")
	assert_true(layout != null, "the dozer_cook layout loads")
	return layout


func _dozer(enemy_hp: int) -> ChBodyDef:
	# The Dozer with the brief's HP override. ChBodyDef.duplicate() drops a script resource's own
	# properties on this build (verified: the copy answers an empty id and 0 HP), so the fields the
	# builder reads are written across one by one rather than guessed at.
	var loaded: ChBodyDef = ChCatalog.load_default().body(&"dozer")
	assert_true(loaded != null, "the dozer body def loads")
	var copy := ChBodyDef.new()
	copy.id = loaded.id
	copy.display_name = loaded.display_name
	copy.hp = enemy_hp
	copy.energy_cap = loaded.energy_cap
	copy.energy_regen = loaded.energy_regen
	copy.size = loaded.size
	copy.color = loaded.color
	copy.slots = loaded.slots
	copy.material = loaded.material
	return copy


func _catalog(enemy_hp: int) -> ChCatalog:
	# The slice's defs with the Dozer's HP overridden to 30, so one Rocket hit ends the enemy.
	# shortcut: the override travels as a catalog because a def on disk is shared by every test in
	# the run; mutating it would make a later test's Dozer fragile.
	var loaded := ChCatalog.load_default()
	var parts: Array[ChPartDef] = []
	for def in loaded.parts.values():
		parts.append(def)
	var bodies: Array[ChBodyDef] = []
	for def in loaded.bodies.values():
		bodies.append(_dozer(enemy_hp) if def.id == &"dozer" else def)
	return ChCatalog.from_defs(parts, bodies)


# The seam every fight test uses: connect to finished, start the fight, then let frames run.
# Returns whatever `finished` announced, in order, so "emitted once" is a size check.
func _fight(battle: Node2D, player_layout: ChChariotLayout, enemy_layout: ChChariotLayout,
	catalog: ChCatalog, seed: int) -> Array[StringName]:
	var results: Array[StringName] = []
	var sink := results
	battle.finished.connect(func(result: StringName): sink.append(result))
	await battle.start(player_layout, enemy_layout, catalog, seed)
	return results


func test_ai_approaches_then_holds() -> void:
	var ai := ChEnemyAI.new()
	assert_eq(ai.decide(420.0, 60.0, 6.0), -1.0, "target to the left: drive left")
	assert_eq(ai.decide(60.0, 420.0, 6.0), 1.0, "target to the right: drive right")
	assert_eq(ai.decide(420.0, 414.0, 6.0), 0.0, "inside reach: hold")
	assert_eq(ai.decide(420.0, 426.0, 6.0), 0.0, "exactly at reach: hold, the rule is |dx| <= range")
	assert_eq(ai.decide(420.0, 426.5, 6.0), 1.0, "one hair past reach: close in")
	assert_eq(ai.decide(100.0, 100.0, 0.0), 0.0, "no range to close: hold still")
	# The reach table ChBattle hands that parameter: a weapon's proximity_range is its reach in
	# cells (ChBehaviour._reach_box), and the Harpoon owns its behaviour's own range, counted only
	# while it can fire.
	var catalog := ChCatalog.load_default()
	var mace := ChPartRuntime.new()
	mace.def = catalog.part(&"ice_cream_mace")
	mace.cooldown_left = mace.def.cooldown
	var harpoon := ChPartRuntime.new()
	harpoon.def = catalog.part(&"corsair_harpoon")
	harpoon.cooldown_left = harpoon.def.cooldown
	var parts: Array[ChPartRuntime] = [mace, harpoon]
	var rig := ChChariotRuntime.new()
	rig.parts = parts
	assert_near(ai.reach(rig), 6.0, 0.001, "the shortest reach the Dozer can bring to bear is the Mace's 6")
	# The Harpoon's 120 cells count only while it can fire, so a Harpoon whose cooldown is still
	# running owns no range at all and the driver has nothing to close.
	var ranged := ChChariotRuntime.new()
	var only: Array[ChPartRuntime] = [harpoon]
	ranged.parts = only
	assert_true(is_inf(ai.reach(ranged)), "an unready Harpoon leaves the chariot with no range")
	assert_eq(ai.decide(60.0, 420.0, ai.reach(ranged)), 0.0, "so it stays put instead of charging")
	harpoon.cooldown_left = 0.0
	assert_near(ai.reach(ranged), 120.0, 0.001, "a ready Harpoon counts at its own 120 cells")
	assert_near(ai.reach(rig), 6.0, 0.001, "and the Mace is still the shortest reach")
	_complete()


# Review Focus 4: both chariots reaching 0 HP on the same tick (a Ring of Fire pays its own
# chassis as it expands, so one tick can end both) is a loss for the player, not a crash.
func test_simultaneous_death_is_loss() -> void:
	assert_eq(ChBattle.result_for(true, true), &"loss", "both dead: the player loses")
	assert_eq(ChBattle.result_for(true, false), &"loss", "a dead player alone loses")
	assert_eq(ChBattle.result_for(false, true), &"win", "a dead enemy alone wins")
	assert_eq(ChBattle.result_for(false, false), &"", "neither dead is not a result")
	_complete()


func test_battle_finishes() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "the fight announced exactly one result")
	assert_eq(results, [&"win"], "the fight ended with a win inside the 60 s ceiling")
	battle.free()
	_complete()


func _battle_scene() -> Node2D:
	# The scene itself, so the fight test drives the shipped scene rather than a copy of its loop.
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	return battle


# The end of a fight does not stop its ticks: ChBattle runs the fight to its tick budget whatever
# the result, so a second `finished` never arrives.
func test_finished_emitted_once() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "one finished across a whole budget of ticks")
	assert_eq(results, [&"win"], "and it is the win, not a second result")
	# The ticks ran past the end: the fight's clock reached the budget it was given, so this is
	# the second emit being refused rather than a loop that stopped at the result.
	assert_true(battle.ctx.time >= FIGHT_SECONDS - TICK, "ticks ran on past the result to the budget")
	battle.free()
	_complete()
