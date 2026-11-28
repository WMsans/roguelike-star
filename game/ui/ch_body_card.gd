class_name ChBodyCard extends ChCard

# A body as a card: its name, its hull and, on the shop's shelf, its price. One class serves the
# shelf and the inventory bar, the way ChPartCard serves the bar and the garage, so a carried body
# reads as the same thing as the body on the counter.
# The hull is fitted into the card's socket rather than always drawn at ChGarage.ZOOM: a Cutter is
# 34 cells long and a Dozer 30 tall, and neither fits a 124x132 card at 6 px a cell. A larger rect
# (the shelf's) still gets the pit's zoom, because the fit only shrinks what would overhang.

const PAD := 8.0
const NAME_H := 32.0  # the name's row, and the top edge of the socket under it

var body_id: StringName = &""
var body_def: ChBodyDef = null
# When it is 0 or more, the card reads a gold price under the hull (the shop's shelf).
var price := -1


func _init(def_in: ChBodyDef, on_click: Callable) -> void:
	# ChCard's _init attaches the Juice that carries this card's beats and tunes the follow springs;
	# a child _init does not chain it, so this calls it explicitly.
	super()
	body_def = def_in
	body_id = def_in.id
	custom_minimum_size = Vector2(ChPartCard.MIN_WIDTH, ChPartCard.HEIGHT)
	focus_mode = Control.FOCUS_NONE
	clicked.connect(on_click)


func _paint_face() -> void:
	if body_def == null:
		return
	super()
	var inner := size.x - PAD * 2.0
	draw_string(ChUi.FONT, Vector2(PAD, 24.0), body_def.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, inner, ChUi.FONT_SIZE, ChUi.TEXT)
	var socket := Vector2(size.x - 8.0, size.y - NAME_H - 4.0)
	ChUi.draw_socket(self, Rect2(Vector2(4.0, NAME_H), socket))
	var cells := Vector2(maxi(1, body_def.size.x), maxi(1, body_def.size.y))
	var zoom := minf(ChGarage.ZOOM, minf(socket.x / cells.x, socket.y / cells.y))
	paint_hull(self, Vector2(size.x * 0.5, NAME_H + socket.y * 0.5), body_def, zoom)
	# After the hull: a tall hull overhangs the socket's foot, and the price is what the player reads.
	if price >= 0:
		ChUi.draw_pill(self, Vector2(size.x * 0.5, size.y), "$%d" % price)


static func paint_hull(canvas: CanvasItem, centre: Vector2, def: ChBodyDef, zoom: float) -> void:
	# The one place a body's art is drawn: the card, the pit's hull piece and the held layer show the
	# same shape, so a body looks the same wherever it appears and no screen grows its own copy.
	var hull := Vector2(maxi(1, def.size.x), maxi(1, def.size.y)) * zoom
	if def.texture != null:
		canvas.draw_texture_rect(def.texture, Rect2(ChUi.snap(centre - hull * 0.5), hull), false)
		return
	if def.outline.size() >= 3:
		# A Transform2D scales the whole polygon; PackedVector2Array has no * float.
		var shape: PackedVector2Array = Transform2D().scaled(Vector2.ONE * zoom) * def.outline
		# The outline is body-local around the centre, so it is shifted onto the card's own centre.
		for at in shape.size():
			shape[at] += ChUi.snap(centre)
		canvas.draw_colored_polygon(shape, def.color)
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]),
			def.color.darkened(0.3), ChUi.PX)
		return
	canvas.draw_rect(Rect2(ChUi.snap(centre - hull * 0.5), hull), def.color)
