extends ChTest

const BOUNDS := Rect2(0, 0, 1280, 720)

func _tooltip() -> ChPartTooltip:
	var holder := Control.new()
	holder.size = BOUNDS.size
	Engine.get_main_loop().get_root().add_child(_track(holder))
	var tip := ChPartTooltip.new()
	holder.add_child(tip)
	return tip

func _def(id: StringName) -> ChPartDef:
	return ChCatalog.load_default().part(id)

func _frames(n := 2) -> void:
	for i in n:
		await Engine.get_main_loop().process_frame

func test_place_above_centres() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 600, 88, 132), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE), Vector2(494, 392))
	_complete()

func test_place_above_clamps_left_edge() -> void:
	assert_eq(ChPartTooltip.place(Rect2(0, 600, 88, 132), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE).x, 8.0)
	_complete()

func test_place_above_flips_below_at_top() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 20, 88, 40), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.ABOVE).y, 68.0)
	_complete()

func test_place_right_and_flip_left() -> void:
	assert_eq(ChPartTooltip.place(Rect2(600, 280, 48, 24), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.RIGHT), Vector2(656, 192))
	assert_eq(ChPartTooltip.place(Rect2(1200, 280, 48, 24), Vector2(300, 200), BOUNDS,
		ChPartTooltip.Side.RIGHT).x, 892.0)
	assert_eq(ChPartTooltip.place(Rect2(600, 10, 48, 24), Vector2(300, 400), BOUNDS,
		ChPartTooltip.Side.RIGHT).y, 8.0)
	_complete()

func test_show_builds_main_and_keyword_boxes() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"flamethrower"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	assert_true(tip.visible)
	assert_eq(tip.name_label().text, "Flamethrower")
	assert_eq(tip.line_label().text, "Cost 2 · Cooldown 3.0s")
	assert_eq(tip.keyword_keys(), [&"press", &"burn"])
	assert_eq(tip.boxes().size(), 3, "main + Press + Burning")
	var style := tip.boxes()[2].get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, ChKeywords.color_of(&"burn"), "the keyword box wears its colour")
	_complete()

func test_passive_hides_cost_line() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	assert_true(not tip.line_label().visible)
	assert_eq(tip.keyword_keys(), [&"passive", &"burn", &"energy"])
	_complete()

func test_switch_def_reuses_boxes_and_hide() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	# boxes()[1] is the Passive box for both parts, so the reuse is read on [2]: the ember's second
	# keyword box, which the freeze charge must refill rather than rebuild.
	var second_kw := tip.boxes()[2]
	tip.show_part(_def(&"freeze_charge"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.keyword_keys(), [&"passive", &"proximity", &"freeze"])
	assert_eq(tip.boxes()[2], second_kw, "pooled box reused")
	tip.show_part(_def(&"wheel"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.boxes().size(), 2, "extra keyword boxes hidden")
	tip.hide_tooltip()
	assert_true(not tip.visible and tip.def == null)
	_complete()

func test_pop_in_from_hidden_but_not_on_switch() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"flamethrower"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	var juice := ChJuice.of(tip.boxes()[0])
	assert_true(juice != null, "every box carries a Juice")
	assert_true(juice.scale_spring.value < 1.0, "a fresh show pops in from small")
	juice.scale_spring.value = 1.0
	juice.scale_spring.velocity = 0.0
	tip.show_part(_def(&"hearth"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(juice.scale_spring.value, 1.0, "a switch does not reset the spring")
	juice.advance(PEAK_STEP)
	# Two tooltip beats at the same age: the first show's (box 0 plays at once) and the switch's,
	# each tooltip's 0.05.
	assert_near(juice.scale_value() - 1.0, _wigged(0.05) * 2.0, 0.001, "it beats on top instead")
	_complete()

func test_boxes_stack_without_overlap() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ember_battery"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames(3)
	var boxes := tip.boxes()
	for i in boxes.size() - 1:
		assert_true(boxes[i + 1].position.y >= boxes[i].position.y + boxes[i].size.y)
	assert_true(Rect2(tip.position, tip.size).end.y <= 600.0 - ChPartTooltip.GAP + 0.5, "above the card")
	_complete()

func test_ignores_mouse_everywhere() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"freeze_charge"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	assert_eq(tip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node in tip.find_children("*", "Control", true, false):
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % node.name)
	_complete()

func test_keyword_bbcode_renders_clean() -> void:
	var tip := _tooltip()
	tip.show_part(_def(&"ice_cream_mace"), Rect2(600, 600, 88, 132), ChPartTooltip.Side.ABOVE, BOUNDS)
	await _frames()
	var shown := tip.bullets_label().get_parsed_text()
	assert_true(shown.contains("frozen"), "the keyword's word shows")
	assert_true(shown.contains("×3"), "the multiplier survives")
	for junk in ["0x", "sin", "{", "}", "[", "]"]:
		assert_true(not shown.contains(junk), "no %s leaks into the text" % junk)
	_complete()

func test_tooltip_profile_loads() -> void:
	assert_true(Feedback.profile(&"tooltip") != null)
	_complete()

func test_every_line_is_press_or_passive() -> void:
	var catalog := ChCatalog.load_default()
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		var presses := 0
		for line in def.description:
			var is_press := line.begins_with("{press}")
			assert_true(is_press or line.begins_with("{passive}"), "%s: '%s' is tagged" % [id, line])
			presses += int(is_press)
		assert_eq(presses > 0, def.cooldown > 0.0, "%s: press lines iff triggered" % id)
	_complete()
