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


func _chariot(body: ChBodyDef, hp: int, cap := 20.0, value := 0.0, waiting := 0) -> ChChariotRuntime:
	# A runtime with the fields the HUD reads and nothing else: no world, no parts, no joint.
	var rig := ChChariotRuntime.new()
	rig.body_def = body
	rig.hp = hp
	rig.energy = ChEnergy.new(cap, 0.0)
	rig.energy.value = value
	for _at in waiting:
		rig.energy.request(RefCounted.new(), 1.0)
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
	assert_eq(lit, 3, "round(3.2) of them lit, the rest left as sockets")
	_complete()


func test_hud_waiting_hidden_when_empty() -> void:
	var hud := _hud()
	hud.show_state(_chariot(_body("Cutter", 100), 100, 20.0, 20.0), _chariot(_body("Dozer", 200), 200))
	assert_true(not hud.waiting.visible, "nothing queued: nothing to say about it")
	hud.show_state(_chariot(_body("Cutter", 100), 100, 20.0, 20.0, 2),
		_chariot(_body("Dozer", 200), 200))
	assert_true(hud.waiting.visible, "a queue is shown")
	assert_eq(hud.waiting.text, "2 parts waiting", "and counted")
	_complete()


# --- The pin on the removed ticker ---------------------------------------------------------------
# The brief forbids hint and instruction lines, and the ticker was a feed of event type names
# (part_fired, hit, caught_fire, ...) scrolling in the corner. This starts the shipped scene for real
# and spends the fight, then reads every Label the HUD holds: none may name an event. The fight's own
# bus is counted as well, so the test cannot pass by the fight never having had an event to show.
# The fixtures it starts with are ChTest's, shared with test_battle.gd: the brief's kit, the Dozer
# with its HP overridden so one Rocket hit ends it, and the same three-field catalog override.
const FIGHT_FRAMES := 4000  # start()'s 3600-tick budget plus the frames the arena takes to stream
const DOZER_HP := 30


func test_battle_has_no_ticker() -> void:
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
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
