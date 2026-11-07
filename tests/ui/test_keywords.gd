extends ChTest

func _tag(key: StringName, shown: String) -> String:
	return "[0x%s;sin]%s[]" % [ChKeywords.color_of(key).to_html(false), shown]

func test_parse_plain_text_unchanged() -> void:
	var out := ChKeywords.parse("Drives your chariot.")
	assert_eq(out.bbcode, "Drives your chariot.")
	assert_eq(out.keys, [])
	assert_eq(out.unknown, [])
	_complete()

func test_parse_tag_with_shown_text() -> void:
	var out := ChKeywords.parse("Sprays {burn:fire} ahead.")
	assert_eq(out.bbcode, "Sprays %s ahead." % _tag(&"burn", "fire"))
	assert_eq(out.keys, [&"burn"])
	_complete()

func test_parse_bare_tag_uses_entry_name() -> void:
	assert_eq(ChKeywords.parse("{freeze}").bbcode, _tag(&"freeze", "Frozen"))
	_complete()

func test_parse_unknown_key_renders_plain() -> void:
	var out := ChKeywords.parse("a {nope:thing} b {gone}")
	assert_eq(out.bbcode, "a thing b gone")
	assert_eq(out.keys, [])
	assert_eq(out.unknown, [&"nope", &"gone"])
	_complete()

func test_keys_of_dedupes_in_first_order() -> void:
	var lines := PackedStringArray(["{burn:a} then {freeze}", "{burn:b} {nope}", "{energy}"])
	assert_eq(ChKeywords.keys_of(lines), [&"burn", &"freeze", &"energy"])
	_complete()

func test_every_entry_complete() -> void:
	for key in ChKeywords.ENTRIES:
		assert_true(ChKeywords.name_of(key) != "" and ChKeywords.text_of(key) != "", "%s filled" % key)
	assert_eq(ChKeywords.text_color_on(Color.WHITE), Color(0.08, 0.08, 0.1), "dark text on light")
	assert_eq(ChKeywords.text_color_on(Color.BLACK), ChUi.TEXT, "light text on dark")
	_complete()
