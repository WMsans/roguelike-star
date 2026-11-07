extends ChTest

func _base() -> ChCatalog:
	return ChCatalog.load_default()

func _side() -> Dictionary:
	return {"body_id": "cutter", "parts": [{"slot": [0], "part": "wheel"}, {"slot": [1], "part": "wheel"},
		{"slot": [2], "part": "cutter_rocket"}]}

func test_valid_scenario_builds_one_matchup() -> void:
	var out := ChBalanceScenario.parse({"name": "s", "player": _side(),
		"enemy": {"layout": "res://game/data/enemies/dozer_cook.tres"}}, _base(), "s.json")
	assert_true(out.ok, str(out.errors))
	assert_eq(out.matchups.size(), 1)
	var m: ChBalanceMatchup = out.matchups[0]
	assert_eq(m.seeds, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "default seeds")
	assert_eq(Array(m.drive), ["ai", "ai"], "default drive")
	assert_eq(m.player.get_node([2]).part_id, &"cutter_rocket")
	_complete()

func test_unknown_part_names_field_and_known_ids() -> void:
	var side := _side()
	side.parts[2].part = "rocket"
	var out := ChBalanceScenario.parse({"name": "s", "player": side, "enemy": _side()}, _base(), "s.json")
	assert_true(not out.ok)
	assert_true(out.errors[0].begins_with("s.json: player.parts[2].part: unknown part 'rocket'"), out.errors[0])
	assert_true(out.errors[0].contains("cutter_rocket"), "lists the known ids")
	_complete()

func test_slot_the_body_lacks_is_an_error() -> void:
	var side := _side()
	side.parts[2].slot = [9]
	var out := ChBalanceScenario.parse({"name": "s", "player": side, "enemy": _side()}, _base(), "s.json")
	assert_true(not out.ok)
	assert_true(out.errors[0].contains("player.parts[2].slot"), out.errors[0])
	_complete()

func test_missing_name_and_bad_drive_are_both_reported() -> void:
	var out := ChBalanceScenario.parse({"player": _side(), "enemy": _side(), "drive": {"player": "zoom"}},
		_base(), "s.json")
	assert_true(not out.ok)
	assert_eq(out.errors.size(), 2, str(out.errors))
	_complete()

func test_matrix_expands_every_pair() -> void:
	var out := ChBalanceScenario.parse({"name": "m", "player": [_side(), _side()],
		"enemy": [_side(), _side(), _side()]}, _base(), "m.json")
	assert_true(out.ok, str(out.errors))
	assert_eq(out.matchups.size(), 6)
	assert_eq(out.matchups[5].name, "m/1x2")
	_complete()

func test_same_body_different_hp_overrides_do_not_clash() -> void:
	var a := _side(); a.hp = 100
	var b := _side(); b.hp = 900
	var out := ChBalanceScenario.parse({"name": "s", "player": a, "enemy": b}, _base(), "s.json")
	assert_true(out.ok, str(out.errors))
	var m: ChBalanceMatchup = out.matchups[0]
	assert_eq(m.catalog.body(m.player.body_id).hp, 100)
	assert_eq(m.catalog.body(m.enemy.body_id).hp, 900)
	_complete()

func test_charge_driver_points_at_the_enemy() -> void:
	# Pure check of the sign rule, with stand-in chassis positions.
	assert_eq(ChBalanceDrivers.charge_toward(10.0, 50.0), 1.0)
	assert_eq(ChBalanceDrivers.charge_toward(50.0, 10.0), -1.0)
	_complete()
