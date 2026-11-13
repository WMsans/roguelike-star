extends ChTest

# Task 2: ChCard, one Control that draws its face under its own transform, so a layout container
# keeps placing the rect and only the drawing moves. The input entry points (press/move/release/
# hover) are the tested seam: the headless runner has no pointer, and _gui_input/_input are thin
# adapters over them. Motion is driven by explicit advance(DT) calls, never by awaiting frames:
# a card in the tree also steps in _process, and awaiting would double-step the springs.
# CONTRACT: every test_* ends with _complete() because the runner counts that as the completion
# marker (a body that aborts mid-way would otherwise pass silently).

const DT := 1.0 / 60.0
const CARD_SIZE := Vector2(80, 120)


func _card() -> ChCard:
	var card := ChCard.new()
	card.size = CARD_SIZE
	_parent().add_child(card)
	return card


func test_click_under_threshold() -> void:
	# GDScript lambdas capture locals by value, so signal evidence is collected in sink arrays
	# (captured by reference), the pattern test_garage uses.
	var card := _card()
	var clicks: Array = []
	var drops: Array = []
	card.clicked.connect(func() -> void: clicks.append(1))
	card.dropped.connect(func(_at: Vector2) -> void: drops.append(1))
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(3, 0))
	card.release(p + Vector2(3, 0))
	assert_eq(clicks.size(), 1, "a press that never passes the threshold is one click")
	assert_eq(drops.size(), 0, "and never a drop")
	assert_true(not card.dragging, "it never entered a drag")
	_complete()


func test_drag_past_threshold() -> void:
	var card := _card()
	var clicks: Array = []
	var started: Array = []
	var drops: Array = []
	card.clicked.connect(func() -> void: clicks.append(1))
	card.drag_started.connect(func() -> void: started.append(1))
	card.dropped.connect(func(at: Vector2) -> void: drops.append(at))
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(10, 0))
	assert_true(card.dragging, "10 px past the grab is a drag")
	assert_eq(started.size(), 1, "drag_started fired")
	assert_eq(card.z_index, ChCard.DRAG_Z, "the dragged card rides above the strip")
	var q := p + Vector2(10, 40)
	card.release(q)
	assert_eq(drops.size(), 1, "dropped fires once on release")
	assert_eq(drops[0], q, "with the global pointer it ended on")
	assert_true(not card.dragging, "release ends the drag")
	assert_eq(card.z_index, 0, "and puts the card back a layer down")
	assert_eq(clicks.size(), 0, "a drag never also clicks")
	_complete()


func test_drag_follows_with_lag() -> void:
	var card := _card()
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(200, 0))
	card.advance(DT)
	assert_true(card.offset.x > 0.0, "the card starts after the pointer (%s)" % card.offset.x)
	# The pointer moved 200, so the drawn card travels 200 too: the 40 px grab point stays under
	# the cursor, which means the offset itself never carries that 40.
	assert_true(card.offset.x < 100.0, "and has not caught up in one frame (%s)" % card.offset.x)
	for i in 60:
		card.advance(DT)
	assert_true(absf(card.offset.x - 200.0) < 2.0,
		"it settles where the grab point sits under the pointer (%s)" % card.offset.x)
	assert_near(card.offset.y, 0.0, 0.01, "a horizontal drag does not move y")
	_complete()


func test_tilt_follows_velocity() -> void:
	var card := _card()
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(200, 0))
	var leaned := false
	for i in 60:
		card.advance(DT)
		if card.tilt > 0.0:
			leaned = true
		assert_true(card.tilt <= ChCard.MAX_TILT + 0.0001,
			"the lean into the motion stays under MAX_TILT (%s)" % card.tilt)
	assert_true(leaned, "the card leans with the offset as it moves right")
	card.release(p + Vector2(200, 0))
	for i in 60:
		card.advance(DT)
		assert_true(absf(card.tilt) <= ChCard.MAX_TILT + 0.0001,
			"and stays under it through the glide home (%s)" % card.tilt)
	assert_true(absf(card.tilt) < 0.01, "still for 1 s and it is upright again (%s)" % card.tilt)
	_complete()


func test_drop_rejected_glides_home() -> void:
	# Review focus 1: a release over nothing — no owner acting on `dropped` at all — still returns
	# the card to its slot. Nothing is ever lost.
	var card := _card()
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(150, 0))
	for i in 10:
		card.advance(DT)
	card.release(p + Vector2(150, 0))
	assert_true(card.offset.x > 1.0, "the card is away from home when the drop is refused (%s)" % card.offset.x)
	for i in 60:
		card.advance(DT)
	assert_true(card.offset.length() < 1.0, "the card glides back to its slot (%s)" % card.offset)
	assert_eq(card.z_index, 0, "and drops back off the drag layer")
	_complete()


func test_layout_move_is_eased() -> void:
	var card := _card()
	var drawn_before := card.global_position + card.offset
	card.position += Vector2(100, 0)  # what a container reorder does to the rect
	card.advance(DT)
	var moved := card.global_position + card.offset - drawn_before
	assert_true(moved.x < 100.0, "the drawn card does not teleport with the rect (%s)" % moved)
	assert_true(moved.x > 0.0, "and it does start toward the new slot (%s)" % moved)
	for i in 60:
		card.advance(DT)
	assert_near((card.global_position + card.offset).x, card.global_position.x, 2.0,
		"within 1 s the drawing reaches the new position")
	_complete()


func test_hover_lifts() -> void:
	var card := _card()
	var flips: Array = []
	card.hover_changed.connect(func(entered: bool) -> void: flips.append(entered))
	card.hover(true)
	assert_eq(flips, [true], "hover_changed(true) fired once")
	assert_true(card.hovered, "and the card knows it")
	for i in 30:
		card.advance(DT)
	assert_near(card.offset.y, -ChCard.HOVER_LIFT, 0.5, "the card lifted off the strip")
	assert_near(card._drawn_scale(), ChCard.HOVER_SCALE, 0.01, "and drew bigger")
	card.hover(false)
	assert_eq(flips, [true, false], "hover_changed(false) fired on exit")
	for i in 60:
		card.advance(DT)
	assert_near(card.offset.y, 0.0, 0.5, "the lift comes back down")
	assert_near(card._drawn_scale(), 1.0, 0.01, "and so does the scale")
	_complete()


func test_mouse_signals_drive_the_hover() -> void:
	# The shipped game has no pointer seam to drive: only the Control's own mouse signals fire, so
	# hover() alone left every card flat and unrimmed. This drives the signals, not the seam.
	var card := _card()
	var flips: Array = []
	card.hover_changed.connect(func(entered: bool) -> void: flips.append(entered))
	card.mouse_entered.emit()
	assert_true(card.hovered, "the mouse entering a card hovers it")
	assert_eq(flips, [true], "and announces it once")
	for i in 30:
		card.advance(DT)
	assert_near(card.offset.y, -ChCard.HOVER_LIFT, 0.5, "the drawn card lifted off the strip")
	card.mouse_exited.emit()
	assert_true(not card.hovered, "the mouse leaving puts it back")
	assert_eq(flips, [true, false], "and announces the exit")
	for i in 60:
		card.advance(DT)
	assert_near(card.offset.y, 0.0, 0.5, "the lift comes back down")
	_complete()


func test_mid_drag_reorder_keeps_the_drawn_card_in_place() -> void:
	# Review focus 1 (finding 1): Tasks 4/5/7 drop cards into strips that reorder, and a reorder can
	# land while the card is still in the hand. A container moving the rect must never teleport the
	# drawing, and must not fire the accumulated shift at the drawing on the first frame after
	# release either: the card glides, it never snaps.
	var card := _card()
	var p := card.global_position + Vector2(40, 60)
	card.press(p)
	card.move(p + Vector2(120, 0))
	for i in 5:
		card.advance(DT)
	assert_true(card.dragging, "the card is in the hand before the reorder")
	var drawn := card.global_position + card.offset
	# One frame of a live drag is a few px of follow at most, so anything near the reorder distance
	# is a jump.
	card.position += Vector2(100, 0)
	card.advance(DT)
	var step := (card.global_position + card.offset) - drawn
	assert_true(step.length() < 30.0, "the drawing does not jump with the rect (%s)" % step)
	# Absorbing the reorder must not cost the drag: the card keeps chasing the pointer it was chasing.
	for i in 60:
		card.advance(DT)
	assert_near(card.offset.x, 120.0, 2.0, "and the drag still follows the pointer (%s)" % card.offset)
	card.release(p + Vector2(120, 0))
	var at_release := card.global_position + card.offset
	card.advance(DT)
	step = (card.global_position + card.offset) - at_release
	assert_true(step.length() < 30.0, "nor when the drop lands (%s)" % step)
	for i in 60:
		card.advance(DT)
	assert_true(card.offset.length() < 1.0, "and it glides back to the strip it landed in (%s)" % card.offset)
	_complete()


func test_hover_lean_tracks_the_pointer_and_stays_under_max_tilt() -> void:
	# Findings 3 and 2 in one seam: the hover lean reads _pointer, which only press/move/release
	# updated, and it is added after MAX_TILT was already applied to the velocity term.
	# _input is the real game's entry point for a hovered card's motion, so the test drives it with
	# an InputEventMouseMotion — a hovered, unpressed card must learn where the cursor is without
	# that motion starting a drag.
	var card := _card()
	card.hover(true)
	for i in 30:
		card.advance(DT)
	var centre := card.global_position + Vector2(40, 60)
	card._input(_motion(centre + Vector2(40, 0)))  # the cursor at the card's right edge
	for i in 30:
		card.advance(DT)
	assert_near(card.tilt, _lean_at(card, centre.x + 40.0), 0.005,
		"a hovered card leans toward the cursor at its right edge (%s)" % card.tilt)
	card._input(_motion(centre - Vector2(40, 0)))  # and now the left edge
	for i in 30:
		card.advance(DT)
	assert_near(card.tilt, _lean_at(card, centre.x - 40.0), 0.005,
		"and the lean follows the cursor across the card (%s)" % card.tilt)
	assert_true(not card.dragging, "a motion while only hovered never starts a drag")
	# Finding 2: that lean on top of a drag fast enough that the velocity term alone is past MAX_TILT.
	# With the clamp on the velocity term only, the sum reads as 14 deg past the pinned 12.
	card.press(centre - Vector2(40, 0))
	card.move(centre + Vector2(320, 0))
	var kicked := 0.0
	for i in 24:
		card.advance(DT)
		kicked = maxf(kicked, absf(card._follow_x.velocity) * ChCard.TILT_PER_SPEED)
		assert_true(absf(card.tilt) <= ChCard.MAX_TILT + 0.0001,
			"the lean never pushes the tilt past MAX_TILT (%s)" % card.tilt)
	assert_true(kicked > ChCard.MAX_TILT,
		"the drag kicked the velocity term past MAX_TILT on its own, so the sum is exercised (%s)" % kicked)
	_complete()


# A global-position mouse motion, which is what _input sees in the real game.
func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	# global_position is a virtual method on InputEvent: it only reads back what was set.
	event.set_global_position(at)
	return event


# The lean the pinned hover formula asks for at a given global cursor x. It is written from the cursor
# the test put there, not from the card's own pointer, so a card that never learned the cursor fails.
func _lean_at(card: ChCard, cursor_x: float) -> float:
	return clampf((cursor_x - card.global_position.x - card.size.x * 0.5) / maxf(card.size.x, 1.0),
		-0.5, 0.5) * ChCard.HOVER_LEAN
