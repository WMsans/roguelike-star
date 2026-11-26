class_name ChStatusBadge extends RefCounted

# The stack numbers drawn over a holder: only the statuses it has, in the fixed list order.

static func entries(statuses: ChStatuses) -> Array:
	var out := []
	for s in ChStatuses.ALL:
		if statuses.count(s) > 0:
			out.append([s, statuses.count(s)])
	return out


const GAP := 2.0 * ChUi.PX


static func row_width(statuses: ChStatuses) -> float:
	var w := 0.0
	for e in entries(statuses):
		w += ChUi.FONT.get_string_size(str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE).x + GAP
	return maxf(0.0, w - GAP)


static func part_baseline(box: Rect2) -> float:
	# Screen y of a part's row: just above its box.
	return box.position.y - GAP


static func hull_baseline(topmost: float) -> float:
	# The hull's row sits one row above the topmost point of the whole chariot, clear of every part row.
	return topmost - GAP - ChUi.FONT_SIZE - GAP


static func draw(canvas: CanvasItem, statuses: ChStatuses, center_x: float, baseline: float) -> void:
	# Screen pixels: one row of numbers centred on center_x, each a keyword colour over a dark outline.
	var x := center_x - row_width(statuses) * 0.5
	for e in entries(statuses):
		var text := str(e[1])
		var at := Vector2(x, baseline)
		canvas.draw_string_outline(ChUi.FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE,
			ChUi.PX * 2, ChKeywords.DARK_TEXT)
		canvas.draw_string(ChUi.FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE,
			ChKeywords.color_of(e[0]))
		x += ChUi.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE).x + GAP
