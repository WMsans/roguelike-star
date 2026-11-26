extends ChTest

func test_fonts_are_crisp() -> void:
	assert_eq(ChUi.FONT.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "the pixel font draws unsmoothed")
	assert_eq(ChUi.FONT.hinting, TextServer.HINTING_NONE)
	assert_eq(ChUi.theme().default_font, ChUi.FONT, "every Control reads in the one font")
	assert_eq(ChUi.theme().get_font(&"font", &"Button"), ChUi.FONT, "buttons too")
	assert_eq(ChUi.theme().get_font(&"font", &"Plaque"), ChUi.FONT, "and the plaque")
	assert_eq(ChUi.FONT_SIZE % 8, 0, "Tiny5's 8-pixel em at a whole number of screen pixels")
	assert_eq(ChUi.FONT_SIZE / 8, ChUi.PX, "one font pixel is one UI pixel")
	assert_true(not ChUi.panel().anti_aliasing, "a smoothed rim edge is a half pixel")
	assert_eq(ChUi.theme().get_color(&"font_focus_color", &"GoButton"), ChUi.ACCENT, "a focused GoButton stays gold")
	assert_eq(ChUi.theme().get_color(&"font_focus_color", &"Button"), ChUi.TEXT, "a focused Button stays parchment")
	_complete()

func test_socket_states() -> void:
	assert_eq(ChUi.socket().bg_color, ChUi.SOCKET, "a filled socket")
	assert_eq(ChUi.socket(true).bg_color, ChUi.SOCKET_EMPTY, "an empty one is darker")
	assert_eq(ChUi.socket(false, true).border_color, ChUi.ACCENT, "hot gets the gold rim")
	assert_true(ChUi.socket(false, true).shadow_size > 0, "and the glow")
	assert_eq(ChUi.socket().shadow_size, 0, "a cold socket has no glow")
	_complete()

func test_plaque_has_hard_drop_shadow() -> void:
	assert_true(ChUi.plaque().shadow_size > 0, "size 0 would draw no shadow")
	assert_eq(ChUi.plaque().shadow_offset, Vector2(ChUi.PX, ChUi.PX))
	_complete()

func test_tooltip_panel_is_opaque() -> void:
	assert_eq(ChUi.panel_solid().bg_color.a, 1.0, "a tooltip hides what it floats over")
	assert_true(ChUi.panel().bg_color.a < 1.0, "cards and the stage panel stay see-through")
	_complete()
