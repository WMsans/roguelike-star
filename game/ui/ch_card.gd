class_name ChCard extends Control

# One card as its own Control (spec "Card feel", option A): the rect stays exactly where the layout
# container placed it and only the drawing moves. The face is drawn under a transform the card owns
# (ChJuice with writes_parent = false), so the follow spring, the tilt, the hover lift, the idle
# sway and a juice beat never fight the container for scale/rotation the way a ChJuice write would.
# The input entry points (press/move/release/hover) hold all the logic; _gui_input and _input are
# thin adapters over them, which is also the seam the headless tests drive.

signal clicked
signal drag_started
signal dropped(at: Vector2)
signal hover_changed(entered: bool)

# A press moves this many px from the grab point before it becomes a drag instead of a click.
const DRAG_THRESHOLD := 6.0
const MAX_TILT := deg_to_rad(12.0)
# Tilt target per px/s of drawn motion.
const TILT_PER_SPEED := 0.0006
const HOVER_LIFT := 6.0
const HOVER_SCALE := 1.06
const DRAG_SCALE := 1.1
# Idle sway: about +/- 1 degree on a slow sine, so a row of cards never breathes in lockstep.
const SWAY := deg_to_rad(1.0)
const SWAY_HZ := 0.4
const FOLLOW_STIFFNESS := 500.0
const FOLLOW_DAMPING := 42.0
const DRAG_Z := 50
# The hover lean reaches this at the card's edge (the cursor a half-width off centre).
const HOVER_LEAN := deg_to_rad(4.0)

var draggable := true
# The drawn displacement from the rect's position; it springs toward _target_offset().
var offset := Vector2.ZERO
var tilt := 0.0
var dragging := false
var hovered := false

var _pointer := Vector2.ZERO
var _pressed := false
var _press_at := Vector2.ZERO
var _grab := Vector2.ZERO
var _last_global := Vector2.ZERO
var _follow_x := ChSpring.new(0.0)
var _follow_y := ChSpring.new(0.0)
var _follow_tilt := ChSpring.new(0.0)
# The time base for the sway; offset by _sway_phase so a row of cards is never in lockstep.
var _time := 0.0
var _sway_phase := 0.0


func _init() -> void:
	# The rect's own motion rides these springs near critical damping: a reorder eases, it never
	# rings. The bound is lifted: these chase a slot hundreds of px away, which the juice default
	# of 2.0 would flatten to an instant jump (that clamp is what test_drag_follows_with_lag caught).
	for spring in [_follow_x, _follow_y, _follow_tilt]:
		spring.stiffness = FOLLOW_STIFFNESS
		spring.damping = FOLLOW_DAMPING
		spring.max_offset = INF
	# The beats land on this card's own Juice, which must not write the node's transform: _draw
	# reads scale_value()/rotation_value() and composes them with the follow and sway itself.
	var juice := ChJuice.attach(self)
	juice.writes_parent = false
	_sway_phase = randf() * TAU


func _ready() -> void:
	_last_global = global_position


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_time += delta
	# A reorder or a container move teleports the rect; adding the old position minus the new one
	# to the drawn offset keeps the drawing where it was, and the spring eases it to the new slot.
	# It lands on the springs' current values (offset mirrors them a few lines below) with the
	# velocity left alone: a layout move must not kick the tilt as if the card itself had flown.
	# That runs while a drag runs too: Tasks 4/5/7 drop into strips that reorder, and a reorder that
	# lands mid-drag has to be absorbed as it happens, or the whole shift fires at the drawing on the
	# first frame after release (test_mid_drag_reorder_keeps_the_drawn_card_in_place).
	if _last_global != global_position:
		var shift := _last_global - global_position
		_follow_x.value += shift.x
		_follow_y.value += shift.y
		_last_global = global_position
	var target := _target_offset()
	_follow_x.rest = target.x
	_follow_y.rest = target.y
	# offset is assigned, never mutated in place: it carries the teleport compensation above, which
	# is a move of the spring's current position, not of its velocity.
	_follow_x.step(delta)
	_follow_y.step(delta)
	offset = Vector2(_follow_x.value, _follow_y.value)
	# The tilt chases the drawn velocity plus a lean toward the cursor while hovered, eased by the
	# same near-critical springs as the follow so it eases in and out without ringing. The MAX_TILT
	# clamp covers the sum: the pinned 12 deg is the card's limit, not the velocity term's alone.
	var lean := 0.0
	if hovered:
		lean = clampf((_pointer.x - global_position.x - size.x * 0.5) / maxf(size.x, 1.0),
			-0.5, 0.5) * HOVER_LEAN
	var tilt_target := clampf(_follow_x.velocity * TILT_PER_SPEED + lean, -MAX_TILT, MAX_TILT)
	_follow_tilt.rest = tilt_target
	_follow_tilt.step(delta)
	tilt = _follow_tilt.value
	queue_redraw()


func _target_offset() -> Vector2:
	if dragging:
		return _pointer - _press_at
	if hovered:
		return Vector2(0, -HOVER_LIFT)
	return Vector2.ZERO


# The scale the face is drawn at right now: the juice beat times the hover/drag pop.
func _drawn_scale() -> float:
	var juice := ChJuice.of(self)
	var beat := 1.0 if juice == null else juice.scale_value()
	var pop := DRAG_SCALE if dragging else (HOVER_SCALE if hovered else 1.0)
	return beat * pop


func press(at: Vector2) -> void:
	if _pressed or not draggable:
		return
	_pressed = true
	_press_at = at
	_pointer = at
	# The grab point is the press relative to the rect's global position; while dragging, the card
	# chases pointer - grab, so it never snaps in the hand.
	_grab = at - global_position


func move(at: Vector2) -> void:
	_pointer = at
	if _pressed and not dragging and draggable \
			and at.distance_to(_press_at) > DRAG_THRESHOLD:
		dragging = true
		z_index = DRAG_Z
		# The card was picked up: the beat runs on the card's own Juice.
		Feedback.play(&"placed", self)
		drag_started.emit()


func release(at: Vector2) -> void:
	_pointer = at
	if not _pressed:
		return
	_pressed = false
	if dragging:
		dragging = false
		z_index = 0
		# Any drop the owner does not accept needs no extra call: the target offset falls back to
		# zero and the card glides home (test_drop_rejected_glides_home).
		dropped.emit(at)
	else:
		Feedback.play(&"activate", self)
		clicked.emit()


func hover(entered: bool) -> void:
	if hovered == entered:
		return
	hovered = entered
	hover_changed.emit(entered)
	if entered:
		Feedback.play(&"hover", self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		accept_event()
		press(get_global_mouse_position())


func _input(event: InputEvent) -> void:
	# While pressed, motion and release are taken here rather than through the gui: Godot keeps the
	# mouse focus while a button is down, so a release outside the card — or outside the window —
	# reaches no other control's _gui_input. Taking it here means a drag can never wedge stuck.
	if event is InputEventMouseMotion:
		# A mouse event's own global position is the cursor, and it is the only one a headless test can
		# supply: get_global_mouse_position() stays frozen when there is no pointer device.
		if _pressed:
			move(event.global_position)
		elif hovered:
			# A merely-hovered card needs the cursor too: the hover lean reads _pointer, and only
			# press/move/release wrote it, so a card that got no press kept a lean from a pointer it
			# never had. Not move(): motion without a press must never start a drag.
			_pointer = event.global_position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		release(get_global_mouse_position())


# A "no" shake: rotation only, so the card wobbles without popping. The follow spring is already
# pulling it back to its slot.
func refuse() -> void:
	# 8 degrees is the `placed` profile's rotation amplitude: enough to read as a shake next to
	# the hover beat's 3.
	var juice := ChJuice.of(self)
	if juice != null:
		juice.juice_up(0.0, deg_to_rad(8.0))


# Subclasses draw the face as if its top-left were the origin; _draw has already moved the drawing
# origin there and spun/scaled it about the card's centre.
func _paint_face() -> void:
	var rim := ChUi.ACCENT if hovered else Color(0, 0, 0, 0)
	draw_style_box(ChUi.flat(ChUi.BUTTON, rim), Rect2(Vector2.ZERO, size))


func _draw() -> void:
	# The face is drawn under a transform that (a) shifts it by `offset`, (b) rotates and scales it
	# about the face's centre, and (c) leaves _paint_face's origin at the face's top-left. Godot
	# draws a point p at `position + R*S*p`, so folding the -size/2 in means the position below is
	# the face centre (plus offset) minus the rotated/scaled centre; p = size/2 then lands exactly
	# at size/2 + offset, which is how a still card draws the rect in place.
	var centre := size * 0.5
	var rot := tilt + _draw_rotation()
	var s := Vector2.ONE * _drawn_scale()
	draw_set_transform(offset + centre - (centre * s.x).rotated(rot), rot, s)
	_paint_face()


func _draw_rotation() -> float:
	# The beat's rotation and the idle sway ride on top of the tilt.
	var juice := ChJuice.of(self)
	var beat := 0.0 if juice == null else juice.rotation_value()
	return beat + sin(TAU * SWAY_HZ * _time + _sway_phase) * SWAY
