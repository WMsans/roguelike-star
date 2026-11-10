extends ChTest

# Task 5: the battle HUD. The first three tests hand ChBattleHud.show_state a fake runtime built the
# way test_battle.gd builds one — a ChChariotRuntime carrying only a body_def and a ChEnergy — so the
# HUD is read off the same fields the fight fills. The last test is the pin on the removed ticker: it
# drives the shipped scene for real and reads every Label the HUD holds.
# Seam: show_state is the whole HUD update, ChBattle owns the screen and calls it once per fight tick.


func _body(display_name: String, hp: int) -> ChBodyDef:
	var body := ChBodyDef.new()
	body.display_name = display_name
	body.hp = hp
	return body


func _chariot(body: ChBodyDef, hp: int, cap := 20.0, value := 0.0) -> ChChariotRuntime:
	# A runtime with the fields the HUD reads and nothing else: no world, no parts, no joint.
	var rig := ChChariotRuntime.new()
	rig.body_def = body
	rig.hp = hp
	rig.energy = ChEnergy.new(cap, 0.0)
	rig.energy.value = value
	return rig


func _hud() -> ChBattleHud:
	# Not in the tree: the HUD only has to answer what show_state told it, and nothing it draws needs
	# a viewport to be read back.
	var hud := ChBattleHud.new()
	_track(hud)
	return hud


func test_hud_shows_hp() -> void:
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 78, 20.0, 20.0),
		_chariot(_body("Dozer", 200), 30, 20.0, 20.0))
	assert_eq(hud.player_name.text, "Cutter", "the player's block names its body")
	assert_eq(hud.player_hp.text, "78 / 100", "HP reads as current of the body's own max")
	assert_near(hud.player_bar.value, 78.0, 0.001, "and the player's bar fills to 78 of 100")
	assert_eq(hud.enemy_name.text, "Dozer", "the enemy's block names its body too")
	assert_eq(hud.enemy_hp.text, "30 / 200", "and reads its own HP against its own max")
	assert_near(hud.enemy_bar.value, 15.0, 0.001, "so the enemy bar fills to its own 15 of 100")
	_complete()


func test_hud_energy_pips() -> void:
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 100, 6.0, 3.2), _chariot(_body("Dozer", 200), 200))
	assert_eq(hud.energy_pips.size(), 6, "one pip per energy unit of cap")
	var lit := 0
	for pip in hud.energy_pips:
		if pip.color == ChUi.ACCENT:
			lit += 1
	assert_eq(lit, 3, "floor(3.2) of them lit, the rest left as sockets")
	_complete()


func test_hud_marks_the_volley_on_the_pips() -> void:
	# The queue line is gone: the pool shows what a press would spend instead, painted on the top of
	# the lit run (pips 3-6 of 6 lit for a volley of 4), the rest of the lit pips staying ACCENT.
	var hud := _hud()
	assert_true(hud.get("waiting") == null, "the HUD has no waiting label")
	hud.show_state(_chariot(_body("Cutter", 100), 100, 8.0, 6.0), _chariot(_body("Dozer", 200), 200), 4)
	for at in 8:
		var want := ChUi.ACCENT if at < 2 else (ChBattleHud.VOLLEY if at < 6 else ChBattleHud.PIP_OFF)
		assert_eq(hud.energy_pips[at].color, want, "pip %d of the 6 lit, volley 4" % (at + 1))
	_complete()


func test_hud_lights_only_whole_energy() -> void:
	# try_pay(3) fails at 2.6, so 2.6 lights two pips, not three: a lit pip is a unit a press can spend.
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 100, 6.0, 2.6), _chariot(_body("Dozer", 200), 200))
	var lit := 0
	for pip in hud.energy_pips:
		if pip.color != ChBattleHud.PIP_OFF:
			lit += 1
	assert_eq(lit, 2, "floor(2.6) pips lit")
	_complete()


func test_hud_shows_the_volley_shortfall() -> void:
	# A volley of 4 on a pool of 2 of 8: both lit pips are what the press would spend, and the two
	# unlit pips above them are the shortfall, in their own colour, so the player sees it would not
	# all pay.
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 100, 8.0, 2.0), _chariot(_body("Dozer", 200), 200), 4)
	for at in 8:
		var want := ChBattleHud.VOLLEY if at < 2 else (ChBattleHud.SHORT if at < 4 else ChBattleHud.PIP_OFF)
		assert_eq(hud.energy_pips[at].color, want, "pip %d of 8, 2 lit, volley 4" % (at + 1))
	assert_true(ChBattleHud.SHORT != ChBattleHud.VOLLEY and ChBattleHud.SHORT != ChBattleHud.PIP_OFF,
		"the shortfall has a colour of its own")
	_complete()


# --- The pin on the removed ticker ---------------------------------------------------------------
# The brief forbids hint and instruction lines, and the ticker was a feed of event type names
# (part_fired, hit, caught_fire, ...) scrolling in the corner. This starts the shipped scene for real
# and spends the fight, then reads every Label the HUD holds: none may name an event. The fight's own
# bus is counted as well, so the test cannot pass by the fight never having had an event to show.
# The fixtures it starts with are ChTest's, shared with test_battle.gd: the brief's kit, the cook (a Corsair)
# with its HP overridden so one Rocket hit ends it, and the same three-field catalog override.
const FIGHT_FRAMES := 4000  # start()'s 3600-tick budget plus the frames the arena takes to stream
const DOZER_HP := 30


func test_battle_has_no_ticker() -> void:
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	battle.pressers[0] = func(b, s): return b.ai_press(s)  # no Space key headless
	battle.start(_player_layout(), _enemy_layout(), _fight_catalog(DOZER_HP), 12345)
	# start() builds the HUD before its arena streams, so the HUD exists from the first tick on; the
	# bus is read from ctx, which is the resume that ran tick 1, so the subscription sees everything
	# after it.
	var frames := 0
	while battle.ctx == null and frames < 600:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(battle.ctx != null, "the fight started")
	var fired: Array = []
	var listener := RefCounted.new()
	battle.ctx.bus.subscribe(listener, ChEvent.PART_FIRED, func(event: ChEvent): fired.append(event))
	while battle.ticking and frames < FIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(not battle.ticking, "the fight spent its own loop")
	assert_true(not fired.is_empty(), "the fight fired a part, so a ticker would have had a line")
	# The HUD's numbers are the tick's: every other HUD test hands show_state its own fixture, so
	# deleting _hud_tick's call would leave them all green with a permanently blank HUD.
	assert_eq(battle.hud.enemy_name.text, "Corsair", "the fight's own tick filled the enemy's name (the cook drives a Corsair)")
	assert_eq(battle.hud.enemy_hp.text, "0 / 30", "and the HP it reads off the enemy it just killed")
	var names: Array[StringName] = [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.CAUGHT_FIRE,
		ChEvent.FROZEN, ChEvent.THAWED, ChEvent.PART_BROKEN, ChEvent.CELLS_CUT,
		ChEvent.ENERGY_GAINED]
	for label in battle.hud.find_children("*", "Label", true, false):
		# Contained rather than equal, so a feed that printed "part_fired x2" or "hit: 12" is caught
		# by the same pin.
		for name in names:
			assert_true(not label.text.contains(String(name)),
				"no Label on the HUD names a battle event (found %s)" % [label.text])
	battle.free()
	_complete()
