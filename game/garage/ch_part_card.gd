class_name ChPartCard extends ChCard

# Task 3: one part in the garage's strip, drawn as a ChCard: the rect stays exactly where the strip's
# container put it and only the face moves (follow spring, tilt, hover lift, sway, beats). The card is
# the whole part at the pit's own zoom, its name, its cost and how many the kit carries, and a click on
# it is the pick that puts a part in hand. A card with a count of 0 stays in the strip but cannot be
# taken: ChCard ignores a press while draggable is false, so what is left is read off the cards, which
# is why the screen needs no hint line.
# Nothing here reads the garage: the pick is one Callable handed in, so a card is the same widget
# whichever screen builds the strip (the garage today; the inventory bar and the shop later). A ChCard
# plays its own beats on its own Juice, so there is no Feedback.attach_button here.

const ZOOM := ChGarage.ZOOM  # the pit's zoom, so a card and the hull show a part at one scale
const MIN_WIDTH := 88.0
const HEIGHT := 132.0
const PAD := 8.0
const FONT := 12  # the card's own size: the theme's 20 would not fit a name in 88 pixels
const LINE := 16.0  # one text row
const NAME_LINES := 2  # a name wraps to two rows before it would run into the cost
static var _looks := {}  # def.texture -> its ringed look, built once per sprite

var part_id: StringName = &""
var def: ChPartDef = null
var count := 0
# When it is 0 or more, the cost row reads a gold price instead of the energy cost (the shop's shelf).
var price := -1
# When false, the "×n" count is hidden (a strip that shows one part per card has no count to read).
var show_count := true


func _init(def_in: ChPartDef, on_click: Callable) -> void:
	# ChCard's _init attaches the Juice that carries this card's beats and tunes the follow springs;
	# a child _init does not chain it, so this calls it explicitly.
	super()
	def = def_in
	part_id = def_in.id
	# The box is the part's own width at ZOOM plus the padding, so a wheel's card is as wide as the
	# wheel it shows at the pit's scale.
	custom_minimum_size = Vector2(maxf(MIN_WIDTH, def.size.x * ZOOM + 16.0), HEIGHT)
	# Mouse only, as the garage's buttons are: these are not in a focus chain.
	focus_mode = Control.FOCUS_NONE
	# The card's own click is the pick: ChCard emits clicked only after a press that was not ignored,
	# and a count-0 card is not draggable, so a card carrying none never reaches this.
	clicked.connect(on_click)


func set_count(carried: int) -> void:
	# The inventory's count is the card's whole state: a part the player owns none of is greyed out and
	# unpickable rather than hidden, so the strip keeps its one shape whatever the build. draggable is
	# the ChCard seam for "cannot be pressed": press() ignores it while false.
	count = carried
	draggable = carried > 0
	modulate = Color(1, 1, 1, 0.45 if carried <= 0 else 1.0)
	queue_redraw()


func _paint_face() -> void:
	if def == null:
		return
	# The base face: the flat BUTTON slab with an ACCENT rim while hovered, which is the slab the
	# Button's theme style used to draw under all of this.
	super()
	var font := get_theme_default_font()
	var inner := size.x - PAD * 2.0
	# The name, wrapped over the rows an 88 pixel card has room for, then the cost under it with the
	# count at its right end. The count shares the cost's row rather than the name's because a wrapped
	# name can reach the right edge, and the two would be drawn over each other (measured in the shot).
	var at := PAD
	for line in _wrap(font, def.display_name, inner):
		at += LINE
		draw_string(font, Vector2(PAD, at), line, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT, ChUi.TEXT)
	at += LINE
	var cost := "$%d" % price if price >= 0 else "Cost %d" % def.energy_cost
	draw_string(font, Vector2(PAD, at), cost, HORIZONTAL_ALIGNMENT_LEFT, inner - 24.0, FONT, ChUi.TEXT)
	if show_count:
		draw_string(font, Vector2(PAD, at), "×%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, inner, FONT,
			ChUi.ACCENT if count > 0 else ChUi.TEXT)
	# The part itself, on a dark slab: a wheel's colour is the button's own grey, so without something
	# behind it the card would look empty. The slab is the theme's panel, not part art.
	var top := at + 8.0
	draw_rect(Rect2(Vector2(4.0, top - 6.0), Vector2(size.x - 8.0, size.y - top + 2.0)), ChUi.PANEL)
	ChPartCard.paint(self, Vector2(size.x * 0.5, (top + size.y) * 0.5), def, ZOOM)


func _wrap(font: Font, text: String, width: float) -> PackedStringArray:
	# The name in the rows a card has: every slice part fits in two, and a longer one is cut there
	# rather than drawn over the cost.
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x > width:
			lines.append(line)
			if lines.size() == NAME_LINES:
				return lines
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return lines


static func paint(canvas: CanvasItem, centre: Vector2, def: ChPartDef, zoom: float, flipped := false) -> void:
	# The one place a part's placeholder art is drawn: the card, the held layer and the pit all show
	# the same shape at the same zoom, so a wheel is a disc everywhere it appears and no screen grows a
	# second copy of the rule.
	var box := Vector2(maxi(1, def.size.x), maxi(1, def.size.y)) * zoom
	if def.texture != null:
		# A hand sprite gets the battle's navy rim outside its shape (see ChChariotBuilder), so it is
		# drawn 1 px larger on every side; the wheel is model-made and outlined already.
		var look := def.texture
		if def.id != &"wheel":
			if not _looks.has(def.texture):
				_looks[def.texture] = ChTextures.ringed(def.texture.get_image())
			look = _looks[def.texture]
			box += Vector2(2, 2) * zoom
		# A negative width mirrors the art, which faces +x, for a flipped part.
		var w := -box.x if flipped else box.x
		canvas.draw_texture_rect(look, Rect2(centre + Vector2(-w * 0.5, -box.y * 0.5), Vector2(w, box.y)), false)
		return
	if def.id == &"wheel":
		canvas.draw_circle(centre, box.x * 0.5, def.color)
		return
	canvas.draw_rect(Rect2(centre - box * 0.5, box), def.color)
