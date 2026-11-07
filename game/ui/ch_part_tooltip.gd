class_name ChPartTooltip extends Control

# The one part tooltip: a main box (name, cost line, bullets with coloured, waving keywords) and one
# box per keyword under it in that keyword's colour. Boxes are direct children stacked by hand, not
# a VBox, so a container never resets the scale and rotation each box's ChJuice springs. It knows
# nothing about the garage: a caller hands it a def, an anchor rect and the bounds to stay inside.

enum Side { ABOVE, RIGHT }

const WIDTH := 300.0
const GAP := 8.0  # between the anchor and the tooltip
const EDGE := 8.0  # screen margin the tooltip keeps
const POP_FROM := 0.5  # scale a fresh show pops in from
const STAGGER := 0.04  # seconds between boxes popping in
const STACK_GAP := 4.0

var def: ChPartDef = null

var _main: PanelContainer
var _name: Label
var _line: Label
var _bullets: RicherTextLabel
var _pool: Array[PanelContainer] = []  # keyword boxes, reused by index
var _keys: Array[StringName] = []
var _anchor := Rect2()
var _bounds := Rect2()
var _side := ChPartTooltip.Side.ABOVE


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 10
	visible = false
	var rows := _box(ChUi.PANEL)
	_main = rows.get_parent() as PanelContainer
	_name = _label(rows, 20, ChUi.TEXT)
	_line = _label(rows, 14, ChUi.TEXT.darkened(0.25))
	_bullets = RicherTextLabel.new()
	rows.add_child(_bullets)
	# After add_child, the order ChPopups uses: the addon's setters queue a parse.
	_bullets.context_enabled = false  # it would read {…} as context expressions
	_bullets.markdown_enabled = false  # and *, _, ~ as markdown
	_bullets.autostyle_emojis = false
	_bullets.autostyle_numbers = true
	_bullets.autostyle_numbers_tag = "[0x%s]%%s[]" % ChUi.ACCENT.to_html(false)
	_bullets.autostyle_numbers_pad_decimals = false
	_bullets.fit_content = true
	_bullets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bullets.font_size = 16
	_bullets.alignment = HORIZONTAL_ALIGNMENT_LEFT  # the addon centres by default
	_bullets.color = ChUi.TEXT
	_bullets.mouse_filter = MOUSE_FILTER_IGNORE
	_bullets.scroll_active = false
	# The label's own internal scrollbar would otherwise still catch the wheel and hover.
	_bullets.get_v_scroll_bar().mouse_filter = MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# The RicherTextLabel parses and fits a frame late, so the stack is re-measured while shown.
	if visible:
		restack()


func show_part(def_in: ChPartDef, anchor: Rect2, side: ChPartTooltip.Side, bounds: Rect2) -> void:
	var was_hidden := not visible
	def = def_in
	_anchor = anchor
	_side = side
	_bounds = bounds
	_name.text = def.display_name
	_line.text = "Cost %d · Cooldown %.1fs" % [def.energy_cost, def.cooldown]
	_line.visible = not (def.energy_cost == 0 and def.cooldown == 0.0)
	var lines := PackedStringArray()
	for line in def.description:
		lines.append("• " + ChKeywords.parse(line).bbcode)
	_bullets.bbcode = "\n".join(lines)
	_keys = ChKeywords.keys_of(def.description)
	for i in _keys.size():
		_fill_keyword(i, _keys[i])
	for i in range(_keys.size(), _pool.size()):
		_pool[i].visible = false
	visible = true
	restack()
	var shown := boxes()
	for i in shown.size():
		var box := shown[i]
		if not was_hidden:
			# Already up: kick on top of whatever the springs are doing, no restart.
			Feedback.play(&"tooltip", box)
			continue
		var juice := ChJuice.of(box)
		juice.scale_spring.value = POP_FROM
		juice.scale_spring.velocity = 0.0
		if i == 0:
			Feedback.play(&"tooltip", box)
		else:
			# Bound to the autoload, not this node, so a tooltip freed mid-stagger leaves a no-op.
			get_tree().create_timer(i * STAGGER).timeout.connect(Feedback.play.bind(&"tooltip", box))


func hide_tooltip() -> void:
	visible = false
	def = null


func boxes() -> Array[PanelContainer]:
	var out: Array[PanelContainer] = [_main]
	for i in _keys.size():
		out.append(_pool[i])
	return out


func keyword_keys() -> Array[StringName]:
	return _keys.duplicate()


func name_label() -> Label:
	return _name


func line_label() -> Label:
	return _line


func bullets_label() -> RicherTextLabel:
	return _bullets


func restack() -> void:
	var y := 0.0
	for box in boxes():
		# A Control clamps size up to its minimum, so 0 height means "as tall as the content".
		box.size = Vector2(WIDTH, 0)
		box.position = Vector2(0, y)
		y += box.size.y + STACK_GAP
	size = Vector2(WIDTH, maxf(0.0, y - STACK_GAP))
	position = place(_anchor, size, _bounds, _side)


static func place(anchor: Rect2, box_size: Vector2, bounds: Rect2, side: ChPartTooltip.Side) -> Vector2:
	var at := Vector2.ZERO
	if side == ChPartTooltip.Side.ABOVE:
		at = Vector2(anchor.get_center().x - box_size.x / 2, anchor.position.y - GAP - box_size.y)
		if at.y < bounds.position.y + EDGE:
			at.y = anchor.end.y + GAP
	else:
		at = Vector2(anchor.end.x + GAP, anchor.get_center().y - box_size.y / 2)
		if at.x + box_size.x > bounds.end.x - EDGE:
			at.x = anchor.position.x - GAP - box_size.x
	# max before min: a tooltip taller than the bounds pins to the top edge rather than off it.
	at.x = maxf(bounds.position.x + EDGE, minf(at.x, bounds.end.x - EDGE - box_size.x))
	at.y = maxf(bounds.position.y + EDGE, minf(at.y, bounds.end.y - EDGE - box_size.y))
	return at


func _fill_keyword(i: int, key: StringName) -> void:
	if i == _pool.size():
		var rows := _box(ChKeywords.color_of(key))
		_label(rows, 16, ChUi.TEXT)
		_label(rows, 14, ChUi.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pool.append(rows.get_parent() as PanelContainer)
	var box := _pool[i]
	var color := ChKeywords.color_of(key)
	box.add_theme_stylebox_override("panel", ChUi.flat(color))
	var labels := box.get_child(0).get_children()
	labels[0].text = ChKeywords.name_of(key)
	labels[1].text = ChKeywords.text_of(key)
	for label in labels:
		label.add_theme_color_override("font_color", ChKeywords.text_color_on(color))
	box.visible = true


# A box: a PanelContainer straight under the root with its own Juice, and a VBox for its labels.
func _box(fill: Color) -> VBoxContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size.x = WIDTH
	box.add_theme_stylebox_override("panel", ChUi.flat(fill))
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	var rows := VBoxContainer.new()
	rows.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(rows)
	# After the VBox, so the VBox stays child 0 (_fill_keyword reads it there).
	ChJuice.attach(box)
	return rows


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
