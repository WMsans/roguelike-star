class_name ChUi

# The one theme the battle's HUD, the garage and the result panel are drawn with: flat placeholder
# art, no textures (spec: every visual is a colour off the defs). Built in code rather than kept as a
# .tres, so the colours below are the only place they live, and cached because every Control in
# every screen wants the same one.
# shortcut: the theme carries only what the screens built so far ask for (a font size, Label text
# colour, a dark panel, and a Button in its five states); add a type here when a screen needs it
# rather than overriding on the node.

const ACCENT := Color("#e8c35a")  # the energy the player has, a focused button's rim
const GO := Color("#b5532d")  # the garage's Fight button: the one action that starts a fight
const HP_PLAYER := Color("#4fbf5a")
const HP_ENEMY := Color("#d9594d")
const PANEL := Color("#1d1d22")  # the dark slab a label sits on, so text reads over sand
const BUTTON := Color("#3c3c46")
const TEXT := Color("#e8e8ec")  # Godot's default label grey is too dim against the arena
const FONT_SIZE := 20

static var _shared: Theme = null


static func theme() -> Theme:
	# Cached: the HUD is rebuilt per fight and every Control in it asks for this, and Task 7's garage
	# and Task 6's result panel ask for the same one.
	if _shared == null:
		_shared = _build()
	return _shared


static func _build() -> Theme:
	var out := Theme.new()
	out.default_font_size = FONT_SIZE
	out.set_color("font_color", "Label", TEXT)
	out.set_stylebox("panel", "PanelContainer", flat(PANEL))
	# A Button is drawn from these five states. Without them Godot's own look shows through on hover
	# and press, which is the one place a code-built theme leaks the default theme; the accent is what
	# marks the hovered and the focused one.
	out.set_stylebox("normal", "Button", flat(BUTTON))
	out.set_stylebox("hover", "Button", flat(BUTTON.lightened(0.08), ACCENT))
	out.set_stylebox("pressed", "Button", flat(PANEL, ACCENT))
	out.set_stylebox("disabled", "Button", flat(PANEL))
	out.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), ACCENT))
	return out


static func flat(fill: Color, rim := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	# Every slab in the game is this: one flat colour, a 1px rim, a small corner, and enough content
	# margin that a label never touches the edge.
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(6)
	return box
