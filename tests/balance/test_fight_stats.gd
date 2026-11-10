extends ChTest

func test_stats_invariants_on_a_won_fight() -> void:
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	battle.pressers[0] = ChBalanceDrivers.make_press("mash")
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


func test_never_pressing_leaves_every_triggered_part_ready_and_unfired() -> void:
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	battle.pressers = [ChBalanceDrivers.make_press("never"), ChBalanceDrivers.make_press("never")]
	var stats := ChFightStats.new()
	stats.bind(battle)
	var results: Array[StringName] = []
	battle.finished.connect(func(r): results.append(r))
	var catalog := _fight_catalog(100000, 100000)
	await battle.start(_player_layout(), _enemy_layout(), catalog, 12345)
	var f := stats.fight(12345, results[0])
	var checked := 0
	for side in 2:
		for key in f.sides[side].parts:
			var p: Dictionary = f.sides[side].parts[key]
			var cooldown := catalog.part(StringName(p.part)).cooldown
			if cooldown <= 0.0:
				continue
			checked += 1
			assert_eq(p.firings, 0, key)
			assert_true(p.seconds_ready_unfired >= f.fight_seconds - cooldown - 0.05, "%s %s" % [key, p.seconds_ready_unfired])
	assert_true(checked > 0, "at least one triggered part")
	battle.free()
	_complete()


func test_aborted_fight_has_zeroed_sides() -> void:
	var stats := ChFightStats.new()
	var f := stats.fight(7, &"aborted")
	assert_eq(f.result, "aborted")
	assert_eq(f.fight_seconds, 0.0)
	assert_eq(f.sides.size(), 2)
	assert_eq(f.sides[0].damage_dealt, 0)
	assert_eq(f.sides[0].energy_gained, 0.0)
	assert_eq(f.sides[0].caught_fire, 0)
	assert_eq(f.sides[0].frozen, 0)
	_complete()


func test_hits_on_own_chariot_are_not_damage_dealt() -> void:
	# Reaches into the bus callback: a real self-hit needs a 60 s Ring of Fire fight.
	var stats := ChFightStats.new()
	var ring := ChPartRuntime.new()
	ring.side = 0
	for target_side in [0, 1]:
		var hit := ChEvent.new()
		hit.type = ChEvent.HIT
		hit.source = ring
		hit.data = {"target_part": null, "hp_damage": 10, "target_side": target_side}
		stats._on_hit(hit)
	assert_eq(stats._part(ring).hits, 1, "only the hit on the enemy counts")
	assert_eq(stats._part(ring).damage, 10)
	_complete()
