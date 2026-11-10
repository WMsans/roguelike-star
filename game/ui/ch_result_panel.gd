class_name ChResultPanel extends PanelContainer

# Task 6: the screen a fight ends on. One panel, named for what the fight said, and the one thing the
# player can do about it. Built in code on ChUi's shared theme like the HUD, and centred on the
# viewport it is added to, so ChMain only has to set the result and hand it a signal to listen to.
# No hint line and no event feed: the title and the button are all this screen says.

signal back_pressed

# The fight's four results (ChBattle.finished), as the player reads them. &"aborted" is the fight
# that could not start, which is not a loss - nothing was fought.
const TITLES := {
	&"win": "You win",
	&"loss": "You lose",
	&"draw": "Draw: time ran out",
	&"aborted": "No fight: the battle could not start",
}
const ROW_GAP := 12  # between the title and the button
const FOCUS_DELAY := 0.5  # seconds before Back takes focus

var title: Label
var back: Button


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
	back.text = "Back to garage"
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


func show_result(result: StringName) -> void:
	# Anything the fight does not name reads as the fight that could not start: result_for only makes
	# win/loss/draw, and &"aborted" is the one other result ChBattle emits.
	title.text = TITLES.get(result, TITLES[&"aborted"])


func _center() -> void:
	# PRESET_CENTER puts the anchors at the viewport's middle; the offsets then move the rect by half
	# its own content size, which is what lands the panel's centre on the viewport's.
	set_anchors_preset(Control.PRESET_CENTER)
	var wanted := get_combined_minimum_size()
	offset_left = -wanted.x * 0.5
	offset_right = wanted.x * 0.5
	offset_top = -wanted.y * 0.5
	offset_bottom = wanted.y * 0.5
