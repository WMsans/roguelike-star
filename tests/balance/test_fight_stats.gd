extends ChTest

func test_stats_invariants_on_a_won_fight() -> void:
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	var stats := ChFightStats.new()
	stats.bind(battle)
	var results: Array[StringName] = []
	battle.finished.connect(func(r): results.append(r))
	await battle.start(_player_layout(), _enemy_layout(), _fight_catalog(30), 12345)
	var f := stats.fight(12345, results[0])
	assert_eq(f.result, "win")
	var me: Dictionary = f.sides[0]
	assert_eq(me.damage_dealt, 30, "won against a 30 HP enemy: all of it dealt")
	var part_sum := 0
	for key in me.parts:
		var p: Dictionary = me.parts[key]
		part_sum += p.damage_dealt
		assert_true(p.firings >= 0 and p.hits >= 0, "counts are non-negative")
		assert_eq(p.misses, maxi(0, p.firings - p.hits))
	assert_eq(me.unattributed_damage, me.damage_dealt - part_sum)
	assert_eq(f.sides[1].hp_left, 0)
	assert_near(f.fight_seconds, battle.ctx.time, 0.0001)
	assert_true(me.energy_spent > 0.0, "the winner paid for its shots")
	battle.free()
	_complete()


func test_aborted_fight_has_zeroed_sides() -> void:
	var stats := ChFightStats.new()
	var f := stats.fight(7, &"aborted")
	assert_eq(f.result, "aborted")
	assert_eq(f.fight_seconds, 0.0)
	assert_eq(f.sides.size(), 2)
	assert_eq(f.sides[0].damage_dealt, 0)
	_complete()
