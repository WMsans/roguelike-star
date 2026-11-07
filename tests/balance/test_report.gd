extends ChTest

func _fight(result: String, seconds: float, dealt: int) -> Dictionary:
	var side := {"hp_left": 0, "damage_dealt": dealt, "unattributed_damage": 0, "dps_dealt": dealt / maxf(seconds, 0.001),
		"energy_spent": 10.0, "energy_starved_seconds": 0.0, "flipped_seconds": 0.0, "rams": 0,
		"parts": {"cutter_rocket@[2]": {"part": "cutter_rocket", "path": [2], "firings": 4, "hits": 2, "misses": 2,
			"damage_dealt": dealt, "energy_spent": 8.0, "damage_per_energy": dealt / 8.0,
			"seconds_waiting": 0.0, "broke_at_seconds": -1.0}}}
	return {"seed": 1, "result": result, "fight_seconds": seconds, "sides": [side, side.duplicate(true)]}

func test_draws_count_and_aborts_do_not() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100), _fight("draw", 60.0, 50),
		_fight("aborted", 0.0, 0)])
	assert_eq(agg.fights, 3)
	assert_eq(agg.aborted, 1)
	assert_near(agg.win_rate, 0.5, 0.0001, "1 win of 2 real fights")
	assert_near(agg.mean_fight_seconds, 35.0, 0.0001, "draw counted as 60, abort excluded")
	assert_eq(agg.draw_seeds, [1])
	_complete()

func test_expect_passes_fails_and_flags_unknown_paths() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100)])
	assert_eq(ChBalanceReport.check_expect(agg, {"win_rate": [0.9, 1.0]}).size(), 0)
	assert_eq(ChBalanceReport.check_expect(agg, {"player.parts.cutter_rocket@[2].damage_per_energy": [20, 30]}).size(), 1)
	var unknown := ChBalanceReport.check_expect(agg, {"player.nope": [0, 1]})
	assert_eq(unknown.size(), 1)
	assert_true(unknown[0].contains("no such metric"), unknown[0])
	_complete()

func test_all_aborted_gives_zero_win_rate() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("aborted", 0.0, 0)])
	assert_eq(agg.win_rate, 0.0)
	_complete()

func test_result_line_is_one_parseable_line() -> void:
	var agg := ChBalanceReport.aggregate("x", [_fight("win", 10.0, 100)])
	var line := ChBalanceReport.result_line([agg], PackedStringArray())
	assert_true(line.begins_with("RESULT "))
	assert_true(not line.contains("\n"))
	var parsed = JSON.parse_string(line.substr(7))
	assert_eq(parsed.ok, true)
	assert_eq(parsed.scenarios[0].name, "x")
	_complete()
