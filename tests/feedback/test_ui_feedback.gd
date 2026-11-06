extends ChTest

# Task 10: the garage and the result screen through the one feedback manager. Every press in the
# garage and the screen a fight ends on goes through Feedback, so the wiring lives in the screens
# themselves: a card and a top-bar button carry a Juice and press it, a drop kicks the piece it just
# built, a lift kicks the card the part goes home to, and a body swap kicks the hull. A beat on a
# garage that is gone mid-wobble must be skipped rather than raise, which is the round trip below.
# shortcut: the tests build their own inventory/layout/garage the way test_garage's helpers do, rather
# than sharing them: those helpers live on that file's test class, not on ChTest.

const GARAGE_SCENE := "res://game/garage/garage.tscn"
const MAIN_SCENE := "res://game/main.tscn"
# A fight is frame-driven, so the cap is in frames (the same bound test_garage uses): a screen that
# never changes fails its own assertion instead of hanging the run.
const SCREEN_FRAMES := 6000


func _catalog() -> ChCatalog:
	var catalog := ChCatalog.load_default()
	assert_true(catalog != null, "the slice's defs load")
	if catalog == null:
		return ChCatalog.new()
	return catalog


func _inventory(ids: Array) -> ChInventory:
	var inventory := ChInventory.new()
	for id in ids:
		assert_true(inventory.add(id), "the starter id fits")
	return inventory


func _layout(body_id: StringName) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	return layout


func _garage_scene(inventory: ChInventory, layout: ChChariotLayout,
	catalog: ChCatalog) -> ChGarage:
	# setup() before add_child, the order ChMain uses: _enter_tree is what builds the strip and the
	# top bar, so a card only exists once the scene is in the tree.
	var scene: PackedScene = ResourceLoader.load(GARAGE_SCENE)
	assert_true(scene != null, "garage.tscn loads")
	var garage: ChGarage = scene.instantiate()
	garage.setup(inventory, layout, catalog)
	Engine.get_main_loop().get_root().add_child(garage)
	_track(garage)
	return garage


func _card_of(garage: ChGarage, id: StringName) -> ChPartCard:
	var found: ChPartCard = null
	for node in garage.find_children("*", "ChPartCard", true, false):
		if node.part_id == id:
			found = node
	return found


func _main_scene() -> ChMain:
	var scene: PackedScene = ResourceLoader.load(MAIN_SCENE)
	assert_true(scene != null, "main.tscn loads")
	var main: ChMain = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(main)
	_track(main)
	return main


func _wait_screen(main: ChMain, want: StringName) -> void:
	var frames := 0
	while main.screen != want and frames < SCREEN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1


func _bursts() -> int:
	# The screen-space particle bursts the manager hangs on its pop-up layer. Counted as a delta
	# because the layer is an autoload that earlier tests have already used.
	var count := 0
	if Feedback.popups == null:
		return count
	for child in Feedback.popups.get_children():
		if child is CPUParticles2D:
			count += 1
	return count


func test_card_press_and_hover_kick() -> void:
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	var card := _card_of(garage, &"wheel")
	assert_true(card != null, "the strip has a wheel card")
	if card == null:
		_complete()
		return
	var juice := ChJuice.of(card)
	assert_true(juice != null, "the card carries a Juice child")
	if juice == null:
		_complete()
		return
	assert_eq(juice.scale_spring.velocity, 0.0, "a card at rest is still")
	card.pressed.emit()
	var pressed_velocity := juice.scale_spring.velocity
	assert_true(pressed_velocity > 0.0, "pressing the card kicks its juice")
	# The pick ran too: feedback rides on the screen's own rule, it does not stand in for it.
	assert_eq(garage.held_id, &"wheel", "and the press still picked the part up")
	card.mouse_entered.emit()
	assert_true(juice.scale_spring.velocity > pressed_velocity, "hover kicks it again, on top")
	_complete()


func test_drop_pops_the_new_piece() -> void:
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	var bursts_before := _bursts()
	assert_true(garage.drop_part(&"wheel", [0]), "the wheel mounts in body slot 0")
	var piece := garage.piece_at(_typed_path([0]))
	assert_true(piece != null, "the drop left a piece to kick")
	if piece == null:
		_complete()
		return
	var juice := ChJuice.of(piece)
	assert_true(juice != null, "the piece carries a Juice child")
	if juice == null:
		_complete()
		return
	assert_true(juice.scale_spring.velocity > 0.0, "placing kicks the piece that just appeared")
	assert_eq(_bursts(), bursts_before + 1, "and the placed burst landed on the popup layer")
	_complete()


func test_lift_pops_the_card() -> void:
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "the wheel mounts in body slot 0")
	var card := _card_of(garage, &"wheel")
	assert_true(card != null, "the wheel has a card to go home to")
	if card == null:
		_complete()
		return
	var juice := ChJuice.of(card)
	assert_true(juice != null, "the card carries a Juice child")
	if juice == null:
		_complete()
		return
	assert_eq(juice.scale_spring.velocity, 0.0, "the drop kicked the piece, not the card")
	assert_true(garage.lift([0]), "lifting the wheel takes it off the hull")
	assert_true(juice.scale_spring.velocity > 0.0, "so the lift kicks the card it went back to")
	assert_eq(garage.card_counts()[&"wheel"], 1, "and the card really did get the part back")
	_complete()


func test_cycle_pops_the_hull() -> void:
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), layout, _catalog())
	var hull := garage.hull_piece()
	assert_true(hull != null, "the pit has a hull piece")
	if hull == null:
		_complete()
		return
	var juice := ChJuice.of(hull)
	assert_true(juice != null, "the hull carries a Juice child")
	if juice == null:
		_complete()
		return
	assert_eq(juice.scale_spring.velocity, 0.0, "the hull rests until the body changes")
	garage.cycle_body(1)
	assert_eq(layout.body_id, &"dozer", "the cycle walked to the next body")
	assert_true(juice.scale_spring.velocity > 0.0, "and kicked the hull the new body shows on")
	assert_true(garage.hull_piece() == hull, "on the piece the pit kept, not a rebuilt one")
	_complete()


func test_top_bar_and_back_buttons_juiced() -> void:
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	for path in ["TopBar/PrevBody", "TopBar/NextBody", "TopBar/FightButton"]:
		var button: Button = garage.get_node(path)
		assert_true(button != null, "%s exists" % path)
		if button == null:
			continue
		var juice := ChJuice.of(button)
		assert_true(juice != null, "%s carries a Juice child" % path)
		if juice == null:
			continue
		var juice_children := 0
		for child in button.get_children():
			if child is ChJuice:
				juice_children += 1
		assert_eq(juice_children, 1, "%s has exactly one Juice child" % path)
		button.pressed.emit()
		assert_true(juice.scale_spring.velocity > 0.0, "%s kicks on press" % path)
	# The result screen's one control, built in code the way the HUD is.
	var panel := ChResultPanel.new()
	_track(panel)
	var back_juice := ChJuice.of(panel.back)
	assert_true(back_juice != null, "the result panel's back button carries a Juice child")
	if back_juice == null:
		_complete()
		return
	panel.back.pressed.emit()
	assert_true(back_juice.scale_spring.velocity > 0.0, "and kicks when it is pressed")
	_complete()


func test_round_trip_with_feedback() -> void:
	# The round trip test_garage pins. A part is still wobbling when Fight is asked for, so the
	# garage leaves with a live spring in it; ChMain hides the garage for the fight and frees it on
	# the way back. This proves the frames after that free raise no beat on the old garage and the
	# hand-back state is intact — the piece-freed-mid-kick case lives in tests/test_garage.gd.
	var main: ChMain = _main_scene()
	assert_true(main.garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	assert_true(main.garage.drop_part(&"wheel", [1]), "as the other")
	assert_true(main.garage.drop_part(&"cutter_rocket", [3]), "and the Rocket")
	var build_id := main.layout.get_instance_id()
	var carried := main.inventory.part_ids.size()
	var piece := main.garage.piece_at(_typed_path([3]))
	assert_true(piece != null, "the Rocket has a piece")
	var piece_juice := ChJuice.of(piece) if piece != null else null
	assert_true(piece_juice != null and piece_juice.scale_spring.velocity > 0.0,
		"and the placement left it wobbling")
	# The fight is asked for on the same frame as that kick, the way a player who just placed a
	# part and hits Fight does.
	main.garage.request_fight()
	assert_eq(main.screen, &"fight", "the fight started from the garage")
	var frames := 0
	while main.battle == null and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	if main.battle == null:
		assert_true(false, "the fight reached the tree")
		_complete()
		return
	frames = 0
	while main.battle.enemy == null and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	if main.battle.enemy != null:
		main.battle.enemy.hp = 1
	await _wait_screen(main, &"result")
	assert_eq(main.screen, &"result", "the fight reached the result screen")
	if main.result_panel == null:
		assert_true(false, "the result panel is up")
		_complete()
		return
	main.result_panel.back.pressed.emit()
	assert_eq(main.screen, &"garage", "back went to the garage")
	assert_true(main.garage != null and main.garage.is_visible_in_tree(), "as a live screen again")
	# The frames after the hand-back are the ones a beat aimed at the old garage would raise on;
	# the state the two halves hold is the check that nothing crossed over.
	for _frame in 4:
		await Engine.get_main_loop().process_frame
	assert_eq(main.layout.get_instance_id(), build_id, "the SAME layout instance, not a rebuilt one")
	assert_eq(main.layout.slots.size(), 3, "the build came back as it was left")
	var rocket := main.layout.get_node([3])
	assert_true(rocket != null and rocket.part_id == &"cutter_rocket", "the Rocket in the same slot")
	assert_eq(main.inventory.part_ids.size(), carried, "and the same parts carried")
	assert_eq(main.garage.find_children("*", "ChPartCard", true, false).size(),
		main.garage.STRIP_ORDER.size(), "the fresh garage built its own strip")
	_complete()
