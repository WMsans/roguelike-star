extends ChTest

# Task 10: the garage and the result screen through the one feedback manager. Every press in the
# garage and the screen a fight ends on goes through Feedback, so the wiring lives in the screens
# themselves: a drop kicks the piece it just built, and the result panel's back button carries a Juice
# and presses it. A beat on a garage that is gone mid-wobble must be skipped rather than raise; the
# manager's own test pins that (tests/feedback/test_feedback_manager.gd). The strip's cards and the top
# bar are the bar's and the shop's now, so the beats they played went with them.
# shortcut: the tests build their own inventory/layout/garage the way test_garage's helpers do, rather
# than sharing them: those helpers live on that file's test class, not on ChTest.

const GARAGE_SCENE := "res://game/garage/garage.tscn"


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
	# setup() before add_child, the order ChMain uses: _enter_tree is what builds the pit, so a piece
	# only exists once the scene is in the tree.
	var scene: PackedScene = ResourceLoader.load(GARAGE_SCENE)
	assert_true(scene != null, "garage.tscn loads")
	var garage: ChGarage = scene.instantiate()
	garage.setup(inventory, layout, catalog)
	Engine.get_main_loop().get_root().add_child(garage)
	_track(garage)
	return garage


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
	juice.advance(PEAK_STEP)
	assert_near(juice.scale_value() - 1.0, _wigged(0.15), 0.001,
		"placing beats the piece that just appeared (placed's 0.15)")
	assert_eq(_bursts(), bursts_before + 1, "and the placed burst landed on the popup layer")
	_complete()


func test_result_back_button_juiced() -> void:
	# The result screen's one control, built in code the way the HUD is.
	var panel := ChResultPanel.new()
	_track(panel)
	var back_juice := ChJuice.of(panel.back)
	assert_true(back_juice != null, "the result panel's back button carries a Juice child")
	if back_juice == null:
		_complete()
		return
	panel.back.pressed.emit()
	back_juice.advance(PEAK_STEP)
	assert_near(back_juice.scale_value() - 1.0, _wigged(0.10), 0.001, "and beats when it is pressed")
	_complete()


# Space is both the fire key and ui_accept, so a player mashing fire as the enemy dies would press
# the result's Back button the frame it took focus. The button takes focus only after
# ChResultPanel.FOCUS_DELAY, so the result stays up long enough to be read.
func test_result_panel_takes_focus_late() -> void:
	var panel := ChResultPanel.new()
	Engine.get_main_loop().get_root().add_child(panel)
	_track(panel)
	await Engine.get_main_loop().process_frame
	assert_true(not panel.back.has_focus(), "Back has no focus as the panel shows")
	await Engine.get_main_loop().create_timer(ChResultPanel.FOCUS_DELAY + 0.1).timeout
	assert_true(panel.back.has_focus(), "and takes it once the delay has passed")
	_complete()
