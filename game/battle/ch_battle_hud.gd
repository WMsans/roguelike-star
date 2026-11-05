class_name ChBattleHud extends Control

# The battle's HUD: the player's block at the top left, the enemy's at the top right, laid out in the
# viewport's own pixels under the scene's CanvasLayer (which ignores the camera, so a 60-cell zoom
# cannot move the HUD). Everything here is a Control drawn with ChUi's flat StyleBoxes — no textures,
# no per-frame node churn beyond the energy pips a bigger pool asks for.
# The reader is show_state, called once per fight tick by ChBattle._hud_tick; nothing else writes it.

const MARGIN := 20.0  # the gap from the viewport's top corners
const BAR := Vector2(320, 20)  # the HP bar, the brief's 320x20
const PIP := Vector2(10, 12)  # one energy unit
const PIP_GAP := 4
const PIP_OFF := Color("#3c3c46")  # an unlit pip: the theme's button grey, so it reads as a socket
const ROW_GAP := 6  # between a block's rows
const STATUS_GAP := 12  # between the pips and the waiting count

var player_name: Label
var player_hp: Label
var player_bar: ProgressBar
var energy_pips: Array[ColorRect] = []  # one per energy unit of cap, lit up to the pool's value
var waiting: Label
var enemy_name: Label
var enemy_hp: Label
var enemy_bar: ProgressBar

var _pips_row: HBoxContainer = null  # where energy_pips are made


func _init() -> void:
	theme = ChUi.theme()
	# The HUD fills the viewport and holds nothing clickable, so it takes no presses: a press aimed at
	# anything drawn under it is none of the HUD's business, and MOUSE_FILTER_STOP (Godot's default for
	# a Control) would swallow it. The result panel is on a higher CanvasLayer, so it was never at risk.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The two blocks sit in one full-width row with an expanding spacer between them, so the enemy's
	# block lands against the right edge without this node doing the arithmetic.
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = MARGIN
	row.offset_right = -MARGIN
	row.offset_top = MARGIN
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	row.add_child(_player_block())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_enemy_block())


func _ready() -> void:
	# A Control's anchors resolve against its parent Control, or against the viewport when its parent
	# is not one — and $HUD is a CanvasLayer, so this fills the 1280x720 canvas the layer draws on.
	# Offsets as well as anchors: set_anchors_preset alone keeps the current (zero) rect, and a row
	# anchored to a zero-width parent clamps to its own content and its two blocks end up touching.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _player_block() -> PanelContainer:
	# Name, then the HP bar, then the pips and how many parts are queued behind the pool.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	player_name = Label.new()
	player_hp = Label.new()
	player_bar = _bar(ChUi.HP_PLAYER)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", STATUS_GAP)
	_pips_row = HBoxContainer.new()
	_pips_row.add_theme_constant_override("separation", PIP_GAP)
	waiting = Label.new()
	waiting.visible = false
	for piece in [player_name, player_hp, player_bar]:
		rows.add_child(piece)
	status.add_child(_pips_row)
	status.add_child(waiting)
	rows.add_child(status)
	var panel := PanelContainer.new()
	panel.add_child(rows)
	return panel


func _enemy_block() -> PanelContainer:
	# The enemy's block is the short one: the brief gives it a name and its HP, nothing else.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	enemy_name = Label.new()
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_hp = Label.new()
	enemy_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_bar = _bar(ChUi.HP_ENEMY)
	for piece in [enemy_name, enemy_hp, enemy_bar]:
		rows.add_child(piece)
	var panel := PanelContainer.new()
	panel.add_child(rows)
	return panel


func _bar(fill: Color) -> ProgressBar:
	# A ProgressBar draws from two theme boxes; the flat pair is what makes it a bar rather than a
	# system-looking widget, and 0-100 is the range its value is set on.
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.add_theme_stylebox_override("background", ChUi.flat(ChUi.PANEL))
	bar.add_theme_stylebox_override("fill", ChUi.flat(fill))
	return bar


func show_state(player: ChChariotRuntime, enemy: ChChariotRuntime) -> void:
	# The whole HUD, off the fight's own numbers: both bodies' names and HP, the player's energy pool
	# as pips, and the parts queued behind it.
	player_name.text = player.body_def.display_name
	player_hp.text = _hp_text(player)
	player_bar.value = _hp_percent(player)
	_energy(player.energy)
	waiting.text = "%d parts waiting" % player.energy.queue_size()
	waiting.visible = player.energy.queue_size() > 0
	enemy_name.text = enemy.body_def.display_name
	enemy_hp.text = _hp_text(enemy)
	enemy_bar.value = _hp_percent(enemy)


static func _hp_text(rig: ChChariotRuntime) -> String:
	# Current of the body's own max: 78 of 100 reads "78 / 100".
	return "%d / %d" % [rig.hp, rig.body_def.hp]


static func _hp_percent(rig: ChChariotRuntime) -> float:
	# The bar's own scale, clamped so a hit that took HP past zero cannot draw past the frame.
	return clampf(100.0 * float(rig.hp) / maxf(1.0, float(rig.body_def.hp)), 0.0, 100.0)


func _energy(pool: ChEnergy) -> void:
	# One pip per unit of cap, round(pool.value) of them lit: the queue is what makes a part visibly
	# wait, and the pips are what show the pool it is waiting on.
	while energy_pips.size() < roundi(pool.cap):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP
		pip.color = PIP_OFF
		_pips_row.add_child(pip)
		energy_pips.append(pip)
	var lit := roundi(pool.value)
	for at in energy_pips.size():
		energy_pips[at].color = ChUi.ACCENT if at < lit else PIP_OFF
