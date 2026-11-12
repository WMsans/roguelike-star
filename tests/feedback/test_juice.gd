extends ChTest

# Task 2: the motion primitives every feedback beat is built from. ChSpring is one damped spring
# per scalar; ChJuice holds a scale and a rotation spring plus a list of short wiggle beats, and
# writes spring + beats to its parent each frame.
# The numbers are the brief's: spring stiffness 400, damping 38, offset bound 2.0, squash 0.6,
# beat 0.3 s at omegas 50/42, offsets bounded by 0.35 scale and 25 degrees.
# CONTRACT: every test_* ends with _complete() because the runner counts that as the
# completion marker (a body that aborts mid-way would otherwise pass silently).

const DT := 1.0 / 60.0
# Deliberately the literal 2.0 instead of ChSpring.MAX_OFFSET: a wrong constant in the class must
# fail this test, not silently widen the bound it is checking.
const MAX_OFFSET := 2.0


func test_spring_rests() -> void:
	var spring := ChSpring.new(1.0)
	for i in 60:
		spring.step(DT)
	assert_eq(spring.value, 1.0, "a spring with no energy does not move")
	_complete()


func test_spring_returns_after_kick() -> void:
	var spring := ChSpring.new(1.0)
	spring.velocity = 8.0
	for i in 120:
		spring.step(DT)
	assert_true(absf(spring.value - 1.0) < 0.01, "value %s is back at rest after 2 s" % spring.value)
	assert_true(absf(spring.velocity) < 0.05, "velocity %s is back to zero after 2 s" % spring.velocity)
	_complete()


func test_spring_settles_without_ringing() -> void:
	var spring := ChSpring.new(1.0)
	spring.velocity = 8.0
	var crossings := 0
	var above := spring.value > 1.0
	for i in 60:
		spring.step(DT)
		if (spring.value > 1.0) != above:
			crossings += 1
			above = spring.value > 1.0
	assert_true(crossings <= 1, "near-critical spring crosses rest at most once, got %d" % crossings)
	_complete()


func test_juice_up_is_short() -> void:
	var juice := ChJuice.new()
	juice.juice_up(0.2, 0.1)
	var peak := 0.0
	for i in 18:  # 0.3 s
		juice.advance(DT)
		peak = maxf(peak, absf(juice.scale_value() - 1.0))
	assert_true(peak > 0.08, "a beat visibly pops, peak %s" % peak)
	juice.advance(DT)
	assert_true(absf(juice.scale_value() - 1.0) < 0.01, "and is over after BEAT_TIME")
	assert_true(absf(juice.rotation_value()) < 0.01, "rotation too")
	_complete()


func test_juice_up_starts_at_rest() -> void:
	var juice := ChJuice.new()
	juice.juice_up(0.2, 0.1)
	juice.advance(0.0)
	assert_eq(juice.scale_value(), 1.0, "sin(0) start: no snap on the first frame")
	_complete()


func test_beats_stack_but_clamp() -> void:
	var juice := ChJuice.new()
	for i in 20:
		juice.juice_up(0.2, 0.2)
	var peak := 0.0
	for i in 18:
		juice.advance(DT)
		peak = maxf(peak, absf(juice.scale_value() - 1.0))
	assert_true(peak > 0.2, "stacked beats grow past one beat")
	assert_true(peak <= ChJuice.MAX_SCALE_OFFSET + 0.0001, "but stay bounded")
	_complete()


func test_beats_age_by_exactly_the_time_they_are_given() -> void:
	# A beat's clock moves by the delta it is stepped with, nothing more: one whole beat lands on its
	# end (wiggle over, beat dropped), and 0.03 s lands on the scale wiggle's largest excursion.
	var whole := ChJuice.new()
	whole.juice_up(0.2, 0.1)
	whole.advance(ChJuice.BEAT_TIME)
	assert_near(whole.scale_value(), 1.0, 0.0001, "one whole beat later the scale is back at rest")
	assert_near(whole.rotation_value(), 0.0, 0.0001, "and the rotation is too")
	var peak := ChJuice.new()
	peak.juice_up(0.2, 0.1)
	peak.advance(0.03)
	# 0.2 * sin(50 * 0.03) * (1 - 0.1)^3, and the same for the rotation at its own omega.
	assert_near(peak.scale_value() - 1.0, 0.1454, 0.0001, "0.03 s in, the scale is at its peak")
	assert_near(peak.rotation_value(), 0.0694, 0.0001, "and the rotation is close to its own")
	_complete()


func test_beats_stay_bounded_under_spam() -> void:
	# A Flamethrower burst's worth of beats, one per frame, read through the parent the juice writes.
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	for i in 135:
		juice.juice_up(0.2, 0.2)
		juice.advance(DT)
		assert_true(is_finite(juice.scale_value()), "scale %s stays finite" % juice.scale_value())
		assert_true(absf(juice.scale_value() - 1.0) <= ChJuice.MAX_SCALE_OFFSET,
			"scale %s stays within +/- %s of rest" % [juice.scale_value(), ChJuice.MAX_SCALE_OFFSET])
		assert_true(absf(juice.rotation_value()) <= ChJuice.MAX_ROTATION_OFFSET,
			"rotation %s stays within +/- %s" % [juice.rotation_value(), ChJuice.MAX_ROTATION_OFFSET])
		assert_true(absf(target.scale.x - 1.0) <= ChJuice.MAX_SCALE_OFFSET,
			"what the parent holds matches (%s)" % target.scale.x)
		assert_true(absf(target.rotation) <= ChJuice.MAX_ROTATION_OFFSET,
			"and its rotation (%s)" % target.rotation)
	_complete()


func test_long_frame_stable() -> void:
	# One 0.5 s frame is 30x the substep cap; stepping it whole would blow the spring up.
	var spring := ChSpring.new(1.0)
	spring.velocity = 8.0
	spring.step(0.5)
	assert_true(is_finite(spring.value), "a 0.5 s frame keeps the value finite")
	assert_true(absf(spring.value - spring.rest) <= MAX_OFFSET,
		"value %s stays within %s +/- %s" % [spring.value, spring.rest, MAX_OFFSET])
	_complete()


func test_juice_applies_to_node2d() -> void:
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	juice.juice_up(0.2, 0.1)
	juice.advance(DT)
	assert_true(target.scale.x != 1.0, "scale.x moved (%s)" % target.scale.x)
	assert_true(target.rotation != 0.0, "rotation moved")
	# The pop is wider than tall: y follows x at 0.6, so a scale of 1.5 reads y = 1.3.
	assert_near(target.scale.y, 1.0 + (juice.scale_value() - 1.0) * 0.6, 0.0001,
		"squash shrinks the vertical scale by 0.6")
	_complete()


func test_writes_parent_false_leaves_the_target_alone() -> void:
	# ChCard composes its own transform from scale_value()/rotation_value(), so the flag has to
	# gate only the write: the beats still age, or the values it reads would never move.
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	juice.writes_parent = false
	juice.juice_up(0.2, 0.1)
	for i in 10:  # 0.167 s: still inside the beat at the end of the loop
		juice.advance(DT)
		assert_eq(target.scale, Vector2.ONE, "the target's scale is never written (%s)" % target.scale)
		assert_eq(target.rotation, 0.0, "nor its rotation")
	assert_true(juice.scale_value() != 1.0, "but the beat ran, so scale_value() moved")
	assert_true(juice.rotation_value() != 0.0, "and rotation_value() did too")
	_complete()


func test_juice_applies_to_control() -> void:
	var target := Control.new()
	target.size = Vector2(100, 40)
	_track(target)
	var juice := ChJuice.attach(target)
	juice.juice_up(0.2, 0.1)
	juice.advance(DT)
	assert_eq(target.pivot_offset, Vector2(50, 20), "pivot is the control's centre")
	assert_true(target.scale.x != 1.0, "scale.x moved (%s)" % target.scale.x)
	assert_true(target.rotation != 0.0, "rotation moved")
	_complete()


func test_attach_is_idempotent() -> void:
	var target := Node2D.new()
	_track(target)
	assert_true(ChJuice.of(target) == null, "of() is null on a target with no Juice")
	var first := ChJuice.attach(target)
	var second := ChJuice.attach(target)
	assert_true(first == second, "attach returns the existing Juice the second time")
	assert_eq(target.get_children().size(), 1, "the target still has one child")
	assert_eq(first.name, "Juice", "the node is named Juice")
	assert_true(ChJuice.of(target) == first, "of() finds the attached Juice")
	_complete()
