extends ChTest

# Task 6: ChRun, the run state and the fight sequence. The pinned numbers are the plan's: 10 fights
# (0..9) with elites at 2, 5, 8 and a boss at 9, start gold 20, elite HP x1.25, boss HP x1.5, reward
# 5 normal / 10 elite / 0 boss, inventory capacity 5.


func _new_run(run_seed: int = 7) -> ChRun:
	return ChRun.start(run_seed, ChCatalog.load_default())


func _saw_slot(layout: ChChariotLayout) -> int:
	# Which slot the start kit's saw ended up on, so no test below hard-codes an index.
	for path in layout.all_paths():
		if layout.get_node(_typed_path(path)).part_id == &"cutter_chainsaw":
			return path[0]
	return -1


func test_sequence() -> void:
	var run := _new_run()
	var kinds: Array[StringName] = []
	for i in 10:
		kinds.append(run.kind(i))
	assert_eq(kinds, [&"normal", &"normal", &"elite", &"normal", &"normal", &"elite", &"normal",
		&"normal", &"elite", &"boss"], "10 fights, elites at 2/5/8, boss at 9")
	_complete()


func test_start_kit() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	assert_eq(run.gold, 20, "a run starts with 20 gold")
	assert_eq(run.fight_index, 0, "a run starts at fight 0")
	assert_eq(run.inventory.capacity, ChInventory.CAPACITY, "the run carries five parts")
	assert_eq(run.inventory.part_ids, [], "and it starts carrying none")
	assert_eq(run.layout.body_id, &"cutter", "the run starts on the Cutter")

	var body: ChBodyDef = catalog.body(&"cutter")
	# Read the mounts off the build the run made, and check them against the body rule rather than
	# against the rule ChRun.start used to pick them (ch_body_def.gd's header): +y is down, so a wheel
	# mount is a slot on the hull's bottom edge, y = size.y / 2, where the tyre hangs below the hull.
	var wheels: Array[int] = []
	var saws: Array[int] = []
	for path in run.layout.all_paths():
		var node: ChSlotNode = run.layout.get_node(_typed_path(path))
		if node.part_id == &"wheel":
			wheels.append(path[0])
		elif node.part_id == &"cutter_chainsaw":
			saws.append(path[0])
		else:
			assert_true(false, "the start kit holds only wheels and a saw, not %s" % node.part_id)
	assert_eq(wheels.size(), 2, "exactly two wheels")
	assert_eq(saws.size(), 1, "exactly one chainsaw")
	for slot in wheels:
		assert_true(slot < body.slots.size(), "the wheel mount %d is one of the Cutter's slots" % slot)
		assert_eq(body.slots[slot].y, body.size.y / 2.0,
			"wheel mount %d sits on the hull's bottom edge, where the wheels carry the chariot" % slot)
	var first_free := -1
	for i in body.slots.size():
		if not wheels.has(i):
			first_free = i
			break
	assert_eq(saws, [first_free], "the saw takes the first non-wheel slot")
	_complete()


func test_hp_curve() -> void:
	var run := _new_run()
	# LAST_HP is the plan's number, not a tuning knob like FIRST_HP, so it stays pinned here.
	assert_eq(ChRun.LAST_HP, 1500, "the ramp tops out at 1500")
	assert_eq(run.enemy_hp(0), ChRun.FIRST_HP, "fight 0 is FIRST_HP")
	# The midpoint of the 0..8 interpolation, on a normal fight so no multiplier is involved.
	assert_eq(run.enemy_hp(4), roundi((ChRun.FIRST_HP + ChRun.LAST_HP) / 2.0), "fight 4 sits halfway")
	var previous := 0
	for i in [0, 1, 3, 4, 6, 7]:
		var hp := run.enemy_hp(i)
		assert_true(hp >= previous, "normal fight %d does not fall below %d" % [i, previous])
		previous = hp
	assert_eq(run.enemy_hp(8), roundi(ChRun.LAST_HP * 1.25), "the last elite is LAST_HP x 1.25")
	assert_eq(run.enemy_hp(9), roundi(ChRun.LAST_HP * 1.5), "the boss is LAST_HP x 1.5")
	_complete()


func test_modifiers_drawn_for_elites_and_boss() -> void:
	var run := _new_run()
	for i in 10:
		var drawn: bool = run.modifiers.has(i)
		assert_eq(drawn, i in [2, 5, 8, 9], "fight %d draws a modifier only when it is an elite or the boss" % i)
		if drawn:
			assert_true(ChRun.MODIFIERS.has(run.modifiers[i]), "fight %d draws a real modifier" % i)
	# The draws come off the run's own seeded rng, so a seed replays the same run.
	assert_eq(_new_run().modifiers, run.modifiers, "the same seed draws the same modifiers")
	_complete()


func test_hp_bonus_applies() -> void:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(7, catalog)
	var cutter: ChBodyDef = catalog.body(&"cutter")
	assert_eq(run.player_layout().max_hp, cutter.hp, "with no bonus the body's own HP is the max")
	run.hp_bonus = 100
	assert_eq(run.player_layout().max_hp, cutter.hp + 100, "hp_bonus adds to the body's HP")
	# A body swap re-derives the HP: the new body's def is what player_layout reads.
	run.layout.swap_body(catalog.body(&"dozer"), catalog)
	assert_eq(run.player_layout().max_hp, catalog.body(&"dozer").hp + 100, "the swap's body sizes the HP")
	_complete()


func test_enemy_layout_is_a_copy() -> void:
	# ResourceLoader.load returns one cached instance for the whole process, so the run's enemy has to
	# be a real copy: writing max_hp on the loaded .tres would change every other user's cook.
	var source: ChChariotLayout = ResourceLoader.load("res://game/data/enemies/dozer_cook.tres")
	var file_hp: int = source.max_hp
	var run := _new_run()
	var first: ChChariotLayout = run.enemy_layout(0)
	var third: ChChariotLayout = run.enemy_layout(3)
	assert_true(first != source, "the fight gets its own layout, not the shared resource")
	assert_true(first != third, "and each fight its own")
	assert_true(first.get_node([0]) != third.get_node([0]), "down to the mounted nodes")
	assert_eq(first.max_hp, run.enemy_hp(0), "max_hp is this fight's HP")
	assert_eq(third.max_hp, run.enemy_hp(3), "and it follows the index")
	assert_eq(source.max_hp, file_hp, "the shared resource keeps the HP its file gives it")
	# ChBattle mirrors the enemy itself, so what the run hands out is unmirrored.
	for path in source.all_paths():
		var steps := _typed_path(path)
		assert_eq(first.get_node(steps).part_id, source.get_node(steps).part_id, "%s survives the copy" % [steps])
		assert_eq(first.get_node(steps).flipped, source.get_node(steps).flipped, "%s keeps its facing" % [steps])
	_complete()


func test_player_layout_is_a_copy() -> void:
	var run := _new_run()
	var player: ChChariotLayout = run.player_layout()
	var saw := _saw_slot(run.layout)
	assert_true(saw >= 0, "the start kit has a saw to lift off")
	assert_true(player != run.layout, "the fight gets its own copy of the build")
	assert_true(player.remove(_typed_path([saw])) != null, "the saw lifts off the copy")
	assert_true(run.layout.get_node(_typed_path([saw])) != null, "and the run's own build keeps it")
	assert_eq(run.layout.all_paths().size(), 3, "the start kit is 2 wheels + a saw")
	_complete()


func test_fight_seed_reward_and_last() -> void:
	var run := ChRun.start(7, ChCatalog.load_default())
	assert_eq(run.fight_seed(3), hash([7, 3]), "the fight seed is the run seed and the index")
	assert_true(run.fight_seed(3) != run.fight_seed(4), "two fights do not share a seed")
	assert_eq(run.reward(1), 5, "a normal fight pays 5")
	assert_eq(run.reward(5), 10, "an elite pays 10")
	assert_eq(run.reward(9), 0, "the boss pays nothing")
	assert_true(run.is_last(9), "fight 9 is the last")
	assert_true(not run.is_last(8), "fight 8 is not")
	_complete()
