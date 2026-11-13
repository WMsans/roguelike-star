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
const PIP_OFF := ChUi.BUTTON  # an unlit pip: the theme's button grey, so it reads as a socket
const ROW_GAP := 6  # between a block's rows
const VOLLEY := Color("#ffd166")  # the lit pips a press would spend right now
const SHORT := Color("#7a2e2e")  # the unlit pips a ready volley would need but the pool lacks
const BANNER_SECONDS := 2.0  # the spec's banner: named at fight start, then gone
const COUNTDOWN_OFF := 44.0  # how far below the banner the countdown sits, so neither covers the other

var player_name: Label
var player_hp: Label
var player_bar: ProgressBar
var energy_pips: Array[ColorRect] = []  # one per energy unit of cap, lit up to the pool's value
var enemy_name: Label
var enemy_hp: Label
var enemy_bar: ProgressBar

# The modifier's two readouts, both made on demand so a fight that has no modifier never shows either:
# the banner names it for the spec's 2 s at the start, and the countdown counts the seconds a time-limit
# fight has left. Neither touches the two blocks, and neither writes anything the fight reads.
var banner: Label = null
var countdown: Label = null

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
	# Name, then the HP bar, then the pips.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	player_name = Label.new()
	player_hp = Label.new()
	player_bar = _bar(ChUi.HP_PLAYER)
	_pips_row = HBoxContainer.new()
	_pips_row.add_theme_constant_override("separation", PIP_GAP)
	for piece in [player_name, player_hp, player_bar]:
		rows.add_child(piece)
	rows.add_child(_pips_row)
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


func show_banner(text: String) -> void:
	# The modifier's name, up for the spec's 2 s and then freed: a banner the player has read stops taking
	# room on the HUD. The tree's own timer keeps that clock, not the fight's ticks — show_state belongs to
	# the fight, and the banner was never part of it.
	if banner == null:
		banner = _top_label(MARGIN)
		add_child(banner)
	banner.text = text
	banner.visible = true
	get_tree().create_timer(BANNER_SECONDS).timeout.connect(_banner_over)


func _banner_over() -> void:
	# A battle freed inside those 2 s took the label with it, so the field is cleared rather than trusted.
	if banner != null and is_instance_valid(banner):
		banner.queue_free()
	banner = null


func show_countdown(seconds_left: int) -> void:
	# Only a time-limit fight calls this (ChBattle.start), which is what keeps a timer off every other
	# fight's HUD. The label is made on the first call and written in place after that.
	if countdown == null:
		countdown = _top_label(MARGIN + COUNTDOWN_OFF)
		add_child(countdown)
	countdown.text = "%d s" % seconds_left


func _top_label(top: float) -> Label:
	# A centred label across the top of the viewport, in the same pixels the two blocks lay out in, so the
	# banner and the countdown sit between them instead of moving either one.
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + 28.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


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


func show_state(player: ChChariotRuntime, enemy: ChChariotRuntime, volley_cost: int = 0) -> void:
	# The whole HUD, off the fight's own numbers: both bodies' names and HP, the player's energy pool
	# as pips, with the top `volley_cost` lit ones marked as what a press would spend (see _energy).
	player_name.text = player.body_def.display_name
	player_hp.text = _hp_text(player)
	player_bar.value = _hp_percent(player)
	_energy(player.energy, volley_cost)
	enemy_name.text = enemy.body_def.display_name
	enemy_hp.text = _hp_text(enemy)
	enemy_bar.value = _hp_percent(enemy)


static func _hp_text(rig: ChChariotRuntime) -> String:
	# Current of the chariot's max: 78 of 100 reads "78 / 100".
	return "%d / %d" % [rig.hp, rig.max_hp]


static func _hp_percent(rig: ChChariotRuntime) -> float:
	# The bar's own scale, clamped so a hit that took HP past zero cannot draw past the frame.
	return clampf(100.0 * float(rig.hp) / maxf(1.0, float(rig.max_hp)), 0.0, 100.0)


func _energy(pool: ChEnergy, volley_cost: int) -> void:
	# One pip per unit of cap, floor(pool.value) of them lit: a lit pip is a unit try_pay can spend.
	# The volley a press would spend is painted on the top of the lit run, where the pool drains
	# from, and what it needs past the pool is painted SHORT on the unlit pips above, so the player
	# sees whether a press would pay for all of it.
	while energy_pips.size() < roundi(pool.cap):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP
		pip.color = PIP_OFF
		_pips_row.add_child(pip)
		energy_pips.append(pip)
	var lit := floori(pool.value)
	for at in energy_pips.size():
		if at >= lit:
			energy_pips[at].color = SHORT if at < volley_cost else PIP_OFF
		else:
			energy_pips[at].color = VOLLEY if at >= lit - volley_cost else ChUi.ACCENT
