extends ChTest

func test_wash_drifts_in_whole_texels() -> void:
	assert_eq(ChWash.drift_at(0.0), Vector2.ZERO)
	assert_eq(ChWash.drift_at(1.6), Vector2(3, 3), "2 px/s for 1.6 s is 3.2, floored")
	_complete()

func test_decoration_ignores_the_mouse() -> void:
	var screen := ChShopScreen.new()
	_track(screen)
	assert_true(screen.get_child(0) is ChBackdrop, "the backdrop is the bottom layer")
	assert_true(screen.get_child(1) is ChWash, "the wash is over it")
	for i in 2:
		assert_eq((screen.get_child(i) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"a click goes through to the pit and the cards")
	_complete()

func test_battle_wash_sits_under_the_hud() -> void:
	var battle: Node = load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	_track(battle)
	battle._build_hud()
	var kids: Array = battle.get_node("HUD").get_children()
	assert_true(kids[0] is ChWash, "wash first")
	assert_true(kids[1] is ChBackdrop, "backdrop second")
	assert_true(kids[2] is ChBattleHud, "HUD on top")
	for i in 2:
		assert_eq((kids[i] as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var wash: ChWash = kids[0]
	wash._process(0.0)
	var view: Vector2 = wash.get_viewport_rect().size
	var drawn: Vector2 = wash.size * wash.scale
	assert_true(drawn.x > view.x and drawn.y > view.y, "the wash is grown past the viewport under a CanvasLayer")
	_complete()
