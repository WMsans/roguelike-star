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
