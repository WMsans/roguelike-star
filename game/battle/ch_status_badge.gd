class_name ChStatusBadge extends RefCounted

# The stack numbers drawn over a holder: only the statuses it has, in the fixed list order.

static func entries(statuses: ChStatuses) -> Array:
	var out := []
	for s in ChStatuses.ALL:
		if statuses.count(s) > 0:
			out.append([s, statuses.count(s)])
	return out


static func draw(canvas: CanvasItem, statuses: ChStatuses, box: Rect2) -> void:
	# One left-to-right row of numbers just above the box, each in its keyword's colour.
	var x := box.position.x
	for e in entries(statuses):
		var text := str(e[1])
		canvas.draw_string(ChUi.FONT, Vector2(x, box.position.y - 1.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE, ChKeywords.color_of(e[0]))
		x += ChUi.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ChUi.FONT_SIZE).x + 2.0
