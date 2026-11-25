class_name ChUi

# The one theme the battle's HUD, the garage and the result panel are drawn with: the Noita-led dark
# pixel style of docs/superpowers/specs/2026-11-24-ui-visual-style-design.md. Built in code rather than
# kept as a .tres, so the colours below are the only place they live, and cached because every Control
# in every screen wants the same one.
# shortcut: the theme carries only what the screens built so far ask for; add a type here when a screen
# needs it rather than overriding on the node.

const INK := Color("#0d0709")
const PANEL := Color("#140912", 0.84)  # the translucent wine slab a label sits on
const PANEL_SOLID := Color("#140912")  # a tooltip's slab: it floats over buttons, so nothing may show through
const RIM := Color("#b8804f")
const TEXT := Color("#f2e2c2")
const LABEL := Color("#e0b88a")
const ACCENT := Color("#ffb53a")  # the gold: the energy the player has, a focused button's rim
const SOCKET := Color("#8a3445")
const SOCKET_EDGE := Color("#2e0f16")
const SOCKET_LINE := Color("#b2505f")
const SOCKET_EMPTY := Color("#4a1e28")
const SOCKET_EMPTY_LINE := Color("#6a2a36")
const PLAQUE := Color("#c0475a")
const SELL_RIM := Color("#d9465a")
const SELL_TEXT := Color("#ff6a7a")
const HP_PLAYER := Color("#62d64a")
const HP_ENEMY := Color("#ff4f5e")
const DUSK_CENTRE := Color("#7a3446")
const DUSK_EDGE := Color("#3a1622")
const GRID := Color(1.0, 0.667, 0.588, 0.10)
const VOLLEY := Color("#ffe08a")
const SHORT := Color("#7a2e2e")

const SMALL := 8
const BODY := 16
const BIG := 24
const FONT_SIZE := BODY

static var BODY_FONT: FontFile = font("res://game/ui/fonts/Tiny5.ttf")
static var HEAD_FONT: FontFile = font("res://game/ui/fonts/Silkscreen-Regular.ttf")  # draws capitals
static var PLAQUE_FONT: FontFile = font("res://game/ui/fonts/Silkscreen-Bold.ttf")

static var _shared: Theme = null


static func theme() -> Theme:
	# Cached: the HUD is rebuilt per fight and every Control in it asks for this, and Task 7's garage
	# and Task 6's result panel ask for the same one.
	if _shared == null:
		_shared = _build()
	return _shared


static func _build() -> Theme:
	var out := Theme.new()
	out.default_font = BODY_FONT
	out.default_font_size = BODY
	out.set_color("font_color", "Label", TEXT)
	out.set_stylebox("panel", "PanelContainer", panel())
	# A Button is drawn from these five states. Without them Godot's own look shows through on hover
	# and press, which is the one place a code-built theme leaks the default theme.
	out.set_font("font", "Button", HEAD_FONT)
	out.set_color("font_color", "Button", TEXT)
	out.set_stylebox("normal", "Button", panel())
	out.set_stylebox("hover", "Button", panel(ACCENT))
	out.set_stylebox("pressed", "Button", panel(ACCENT))
	out.set_stylebox("disabled", "Button", panel())
	out.set_color("font_disabled_color", "Button", Color(TEXT, 0.4))
	out.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT))
	out.set_type_variation(&"GoButton", &"Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		out.set_stylebox(state, &"GoButton", panel(ACCENT))
	out.set_stylebox("focus", &"GoButton", _box(Color(0, 0, 0, 0), ACCENT))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		out.set_color(c, &"GoButton", ACCENT)
	out.set_type_variation(&"Plaque", &"Label")
	out.set_font("font", &"Plaque", PLAQUE_FONT)
	out.set_font_size("font_size", &"Plaque", BIG)
	out.set_color("font_color", &"Plaque", TEXT)
	out.set_color("font_shadow_color", &"Plaque", INK)
	out.set_constant("shadow_offset_x", &"Plaque", 2)
	out.set_constant("shadow_offset_y", &"Plaque", 2)
	out.set_stylebox("normal", &"Plaque", plaque())
	return out


static func font(path: String) -> FontFile:
	# Pixel fonts: no smoothing, no hinting, whole-pixel glyph positions, so the edges stay square.
	var f := load(path) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func _box(fill: Color, rim: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2)
	box.set_content_margin_all(6)
	return box


static func panel(rim := RIM) -> StyleBoxFlat:
	return _box(PANEL, rim)


static func panel_solid(rim := RIM) -> StyleBoxFlat:
	return _box(PANEL_SOLID, rim)


static func socket(empty := false, hot := false) -> StyleBoxFlat:
	var box := _box(SOCKET_EMPTY if empty else SOCKET, SOCKET_EDGE)
	if hot:
		box.border_color = ACCENT
		box.shadow_color = Color(ACCENT, 0.5)
		box.shadow_size = 4
	return box


static func draw_socket(canvas: CanvasItem, rect: Rect2, empty := false, hot := false) -> void:
	canvas.draw_style_box(socket(empty, hot), rect)
	canvas.draw_rect(rect.grow(-2), SOCKET_EMPTY_LINE if empty else SOCKET_LINE, false, 1.0)


static func plaque() -> StyleBoxFlat:
	var box := _box(PLAQUE, TEXT)
	box.shadow_color = INK
	box.shadow_size = 1  # 0 draws no shadow at all; 1 keeps it a hard 3px drop
	box.shadow_offset = Vector2(3, 3)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


static func draw_pill(canvas: CanvasItem, bottom_centre: Vector2, text: String) -> void:
	var size := HEAD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL) + Vector2(8, 4)
	var rect := Rect2(bottom_centre - size / 2.0, size)
	canvas.draw_rect(rect, INK)
	canvas.draw_rect(rect, RIM, false, 1.0)
	canvas.draw_string(HEAD_FONT, Vector2(rect.position.x + 4, rect.position.y + 2 + HEAD_FONT.get_ascent(SMALL)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, ACCENT)


static func draw_plaque(canvas: CanvasItem, centre: Vector2, text: String) -> Rect2:
	var box := plaque()
	var size := PLAQUE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG) + box.get_minimum_size()
	var rect := Rect2(centre - size / 2.0, size)
	canvas.draw_style_box(box, rect)
	var at := rect.position + Vector2(box.content_margin_left, box.content_margin_top + PLAQUE_FONT.get_ascent(BIG))
	canvas.draw_string(PLAQUE_FONT, at + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG, INK)
	canvas.draw_string(PLAQUE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, BIG, TEXT)
	return rect


static func draw_group_label(canvas: CanvasItem, bottom_left: Vector2, text: String) -> void:
	canvas.draw_string(HEAD_FONT, bottom_left, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, LABEL)

