extends ChTest

# Task 13: ChMain runs the run. The loop is fight 1, a result, the shop between fights, the next
# fight, and a new run when one ends. The handlers are the seam a screen's signals reach, so these
# drive them directly rather than letting a real fight run to its result: the run only starts the
# fight, which is what `test_opens_in_fight` pins. Where a fight's own result would take a minute to
# arrive (a draw is the whole budget), the handler is handed the result instead.

const MAIN_SCENE := "res://game/main.tscn"


func _main() -> ChMain:
	# The shipped scene, so the test drives ChMain's own loop rather than restating it. main.tscn is
	# a plain Node, so it goes under the runner's root viewport like every other node these tests add.
	var scene: PackedScene = ResourceLoader.load(MAIN_SCENE)
	assert_true(scene != null, "main.tscn loads")
	var main: ChMain = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(main)
	_track(main)
	return main


func test_opens_in_fight() -> void:
	var main := _main()
	assert_eq(main.screen, &"fight", "the game opens in fight 1")
	assert_eq(main.run.fight_index, 0, "on fight 0")
	assert_true(main.battle != null, "with the fight in the tree")
	assert_eq(main.shop, null, "and no shop yet")
	_complete()


func test_win_goes_to_shop() -> void:
	var main := _main()
	main._on_finished(&"win", main.battle)
	assert_eq(main.screen, &"result", "a win opens the result panel")
	assert_eq(main.result_panel.title.text, "You win", "which names the win")
	# A contract-violating second `finished` would stack a second panel over the first: the handler
	# refuses once a panel exists.
	main._on_finished(&"loss", main.battle)
	assert_eq(main.result_panel.title.text, "You win", "a second finished leaves the panel as it was")
	assert_eq(main.find_children("*", "ChResultPanel", true, false).size(), 1, "the one panel")
	var back: Button = main.result_panel.back
	back.pressed.emit()
	assert_eq(main.screen, &"shop", "back goes to the shop")
	assert_eq(main.run.fight_index, 1, "the shop is for fight 1")
	assert_eq(main.run.gold, 25, "and it credited fight 0's 5 gold")
	assert_true(main.shop != null, "with the shop screen up")
	# The second press of the same frame: the panel is queue_free'd, not freed, so its signal is
	# still connected and the press still lands. It must be a no-op rather than a second shop,
	# which would throw away the screen the first press made.
	var shop: ChShopScreen = main.shop
	back.pressed.emit()
	assert_eq(main.screen, &"shop", "the second press left the loop on the shop")
	assert_true(main.shop == shop, "and did not rebuild the screen the first press made")
	assert_eq(main.find_children("*", "ChShopScreen", true, false).size(), 1,
		"exactly one shop is a child of main")
	_complete()


func test_new_run_resets() -> void:
	var main := _main()
	var run: ChRun = main.run
	run.gold = 3
	assert_true(run.inventory.add(&"wheel"), "a run can carry a bought part")
	run.hp_bonus = 100
	assert_true(run.layout.place(_typed_path([3]), &"cutter_rocket"), "and mount a bought weapon")
	main._on_finished(&"loss", main.battle)
	assert_eq(main.result_panel.title.text, "Run over", "a loss names the run over")
	main.result_panel.back.pressed.emit()
	assert_true(main.run != run, "back after a loss started a new run")
	assert_eq(main.run.gold, 20, "with the starting 20 gold")
	assert_eq(main.run.fight_index, 0, "on fight 0")
	assert_eq(main.run.hp_bonus, 0, "no HP bought in the last run")
	assert_eq(main.run.inventory.part_ids, [], "an empty inventory")
	assert_eq(main.run.layout.body_id, &"cutter", "the starting body")
	assert_eq(main.run.layout.all_paths().size(), 3, "and the starting kit: two wheels and a saw")
	assert_eq(main.screen, &"fight", "fight 1 of the new run is running")
	_complete()


func test_boss_win_ends_run() -> void:
	var main := _main()
	main.run.fight_index = ChRun.LAST_INDEX
	main._on_finished(&"win", main.battle)
	assert_eq(main.result_panel.title.text, "Run won", "a win on the last fight is the run won")
	assert_true(main.result_panel.ends_run, "and its button ends the run")
	var run: ChRun = main.run
	main.result_panel.back.pressed.emit()
	assert_true(main.run != run, "back started a new run")
	assert_eq(main.run.fight_index, 0, "on fight 0")
	assert_eq(main.run.gold, 20, "with the starting gold")
	assert_eq(main.screen, &"fight", "and fight 1 is running")
	_complete()


func test_shop_fight_starts_the_next_fight() -> void:
	# The shop's own Fight button, pressed where the player presses it: the button is the shop's child,
	# so this is also the leg where the screen is freed from inside its own button's signal.
	var main := _main()
	main._on_finished(&"win", main.battle)
	main.result_panel.back.pressed.emit()
	var shop: ChShopScreen = main.shop
	shop.phase.stage = 5  # stage 5 is the one that offers the fight instead of a card
	shop.next_button.pressed.emit()
	assert_eq(main.screen, &"fight", "the shop's Fight button started the next fight")
	assert_eq(main.shop, null, "and the shop screen left")
	assert_true(main.battle != null, "with the next fight in the tree")
	assert_eq(main.run.fight_index, 1, "which is fight 1")
	_complete()


func test_stale_finished_in_the_shop_is_inert() -> void:
	# The shop visit keeps the ended fight alive (it is freed only when the next fight starts), so a
	# contract-violating second `finished` from it can arrive while `screen` is the shop. Opening a
	# panel there would let its back button pay a second reward and skip a fight.
	var main := _main()
	main._on_finished(&"win", main.battle)
	main.result_panel.back.pressed.emit()
	var shop: ChShopScreen = main.shop
	var battle: ChBattle = main.battle
	var gold: int = main.run.gold
	var index: int = main.run.fight_index
	main._on_finished(&"win", battle)
	assert_eq(main.screen, &"shop", "a late finished leaves the shop up")
	assert_eq(main.result_panel, null, "and opens no result panel")
	# Back queue_freed the panel it pressed, so that one is still in the tree until the frame ends;
	# what must not appear is a live second one.
	var live := 0
	for node in main.find_children("*", "ChResultPanel", true, false):
		if not node.is_queued_for_deletion():
			live += 1
	assert_eq(live, 0, "no live result panel in the tree")
	assert_eq(main.run.gold, gold, "gold unchanged")
	assert_eq(main.run.fight_index, index, "and no fight was consumed")
	assert_true(main.shop == shop, "the shop shown is the one that was there")
	_complete()


func test_aborted_retries_the_same_fight() -> void:
	# A fight that could not start is not a loss: back retries it on the same fight, and no shop
	# opens (which is what would credit a reward for a fight nobody fought).
	var main := _main()
	main._on_finished(&"aborted", main.battle)
	assert_eq(main.result_panel.title.text, "No fight: the battle could not start",
		"the panel says the fight could not start")
	assert_true(not main.result_panel.ends_run, "and its button does not end the run")
	main.result_panel.back.pressed.emit()
	assert_eq(main.screen, &"fight", "back retried the fight")
	assert_eq(main.run.fight_index, 0, "on the same fight, not the next")
	assert_eq(main.run.gold, 20, "and nothing was paid for it")
	_complete()


func test_draw_ends_the_run() -> void:
	# Task 8's ruling: a timed-out fight is a draw, and a draw ends the run exactly like a loss.
	var main := _main()
	main._on_finished(&"draw", main.battle)
	assert_eq(main.result_panel.title.text, "Run over", "a draw names the run over")
	assert_true(main.result_panel.ends_run, "and its button ends the run")
	var run: ChRun = main.run
	main.result_panel.back.pressed.emit()
	assert_true(main.run != run, "back started a new run")
	assert_eq(main.run.fight_index, 0, "on fight 0")
	assert_eq(main.run.gold, 20, "with the starting gold")
	assert_eq(main.screen, &"fight", "and fight 1 is running")
	_complete()
