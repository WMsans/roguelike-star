class_name ChResultPanel extends PanelContainer

# Task 6: the screen a fight ends on. One panel, named for what the fight said, and the one thing the
# player can do about it. Built in code on ChUi's shared theme like the HUD, and centred on the
# viewport it is added to, so ChMain only has to set the result and hand it a signal to listen to.
# No hint line and no event feed: the title and the button are all this screen says.

signal back_pressed

# One row per thing the panel can be asked to say, as the player reads it: the title, the one
# button it offers, and whether pressing it ends the run rather than going on (ChMain branches on
# that). &"run_won" is the last fight's win; &"aborted" is the fight that could not start, which is
# not a loss - nothing was fought - so it offers a retry.
const ROWS := {
	&"win": {"title": "You win", "button": "Continue", "ends_run": false},
	&"run_won": {"title": "Run won", "button": "New run", "ends_run": true},
	&"loss": {"title": "Run over", "button": "New run", "ends_run": true},
	&"draw": {"title": "Run over", "button": "New run", "ends_run": true},
	&"aborted": {"title": "No fight: the battle could not start", "button": "Retry",
		"ends_run": false},
}
const ROW_GAP := 12  # between the title and the button
const FOCUS_DELAY := 0.5  # seconds before the button takes focus

var title: Label
var back: Button

# Set by show_result: true once this result ends the run, so what the player presses next can be
# decided without reading the button's text back.
var ends_run := false


func _init() -> void:
	theme = ChUi.theme()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	add_child(rows)
	title = Label.new()
	# The panel is as wide as its widest line, so a centred title is centred on the button under it.
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	back = Button.new()
	# No text here: show_result names the button, and the only caller (ChMain) always calls it before
	# the panel reaches the tree.
	back.pressed.connect(func() -> void: back_pressed.emit())
	Feedback.attach_button(back)
	rows.add_child(back)


func _ready() -> void:
	# Centred on the canvas rather than on a corner: ChMain is a plain Node, so this Control's anchors
	# resolve against the 1280x720 viewport (project.godot's, which canvas_items stretch keeps fixed
	# whatever the window), and the offsets are this panel's own content size - so the panel stays
	# centred whatever length the result's title is. A title set after this panel is already up changes
	# that size, which is the signal below.
	_center()
	minimum_size_changed.connect(_center)
	# The result screen is the only thing to press: Enter and Space work without reaching for the
	# pointer, which is how the rest of the game is played. Space is also the fire key, so focus
	# waits FOCUS_DELAY: a player still mashing fire as the enemy dies does not skip the result.
	# The timer's connection goes with this panel if it is freed first.
	get_tree().create_timer(FOCUS_DELAY).timeout.connect(back.grab_focus)


func show_result(result: StringName, last_fight := false) -> void:
	# Anything the fight does not name reads as the fight that could not start: result_for only makes
	# win/loss/draw, and &"aborted" is the one other result ChBattle emits. A win on the run's last
	# fight is the run itself won, which is the one row a bare result cannot name.
	var row: Dictionary = ROWS.get(result, ROWS[&"aborted"])
	if result == &"win" and last_fight:
		row = ROWS[&"run_won"]
	title.text = row["title"]
	back.text = row["button"]
	ends_run = row["ends_run"]


func _center() -> void:
	# PRESET_CENTER puts the anchors at the viewport's middle; the offsets then move the rect by half
	# its own content size, which is what lands the panel's centre on the viewport's.
	set_anchors_preset(Control.PRESET_CENTER)
	var wanted := get_combined_minimum_size()
	offset_left = -wanted.x * 0.5
	offset_right = wanted.x * 0.5
	offset_top = -wanted.y * 0.5
	offset_bottom = wanted.y * 0.5
