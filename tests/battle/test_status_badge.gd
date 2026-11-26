extends ChTest

func test_entries_order_and_zero_skip() -> void:
	var st := ChStatuses.new()
	st.stacks[&"shock"] = 2
	st.stacks[&"flame"] = 3
	st.stacks[&"block"] = 0
	assert_eq(ChStatusBadge.entries(st), [[&"flame", 3], [&"shock", 2]])
	_complete()

func test_row_is_centred_and_hull_row_clears_part_rows() -> void:
	var st := ChStatuses.new()
	st.stacks[&"flame"] = 3
	var box := Rect2(Vector2(100, 200), Vector2(30, 20))
	var w := ChStatusBadge.row_width(st)
	assert_true(w > 0.0, "a row has width")
	assert_true(ChStatusBadge.part_baseline(box) < box.position.y, "the part row sits above its box")
	var hull_y := ChStatusBadge.hull_baseline(box.position.y)
	assert_true(hull_y + ChStatusBadge.GAP <= ChStatusBadge.part_baseline(box) - ChUi.FONT_SIZE, "hull row clears the part row")
	_complete()
