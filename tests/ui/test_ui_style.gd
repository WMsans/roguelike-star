extends ChTest

func test_fonts_are_crisp() -> void:
	for f in [ChUi.BODY_FONT, ChUi.HEAD_FONT, ChUi.PLAQUE_FONT]:
		assert_eq(f.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "pixel fonts draw unsmoothed")
		assert_eq(f.hinting, TextServer.HINTING_NONE)
	assert_eq(ChUi.theme().default_font, ChUi.BODY_FONT, "body text is Tiny5")
	assert_eq(ChUi.theme().get_font(&"font", &"Button"), ChUi.HEAD_FONT, "buttons read in capitals")
	_complete()

func test_socket_states() -> void:
	assert_eq(ChUi.socket().bg_color, ChUi.SOCKET, "a filled socket")
	assert_eq(ChUi.socket(true).bg_color, ChUi.SOCKET_EMPTY, "an empty one is darker")
	assert_eq(ChUi.socket(false, true).border_color, ChUi.ACCENT, "hot gets the gold rim")
	assert_true(ChUi.socket(false, true).shadow_size > 0, "and the glow")
	assert_eq(ChUi.socket().shadow_size, 0, "a cold socket has no glow")
	_complete()
