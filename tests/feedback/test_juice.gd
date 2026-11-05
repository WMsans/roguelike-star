extends ChTest

# Task 2: the motion primitives every feedback beat is built from. ChSpring is one damped spring
# per scalar; ChJuice holds a scale and a rotation spring and writes both to its parent each frame.
# The numbers are the brief's: stiffness 320, damping 14, offset bound 2.0, squash 0.6.
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


func test_spring_overshoots() -> void:
	# Damping 14 under critical (~35.8), so the kick swings past rest instead of easing into it.
	var spring := ChSpring.new(1.0)
	spring.velocity = 8.0
	var low := spring.value
	for i in 60:
		spring.step(DT)
		low = minf(low, spring.value)
	assert_true(low < 1.0, "value undercut rest (min %s): the spring is bouncy, not overdamped" % low)
	_complete()


func test_kicks_stack() -> void:
	var single := Node2D.new()
	_track(single)
	var single_juice := ChJuice.attach(single)
	single_juice.kick(6.0, 0.0)
	var single_peak := _peak_scale(single_juice, 60)
	var double := Node2D.new()
	_track(double)
	var double_juice := ChJuice.attach(double)
	double_juice.kick(6.0, 0.0)
	double_juice.advance(DT)
	double_juice.kick(6.0, 0.0)
	var double_peak := _peak_scale(double_juice, 59)
	assert_true(single_peak < double_peak,
		"two kicks 1 frame apart peak at %s, above one kick's %s" % [double_peak, single_peak])
	_complete()


func test_spring_bounded_under_spam() -> void:
	# A Flamethrower burst's worth of kicks, one per frame.
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	for i in 135:
		juice.kick(6.0, 3.0)
		juice.advance(DT)
		for spring in [juice.scale_spring, juice.rotation_spring]:
			assert_true(is_finite(spring.value), "value %s stays finite" % spring.value)
			assert_true(absf(spring.value - spring.rest) <= MAX_OFFSET,
				"value %s stays within %s +/- %s" % [spring.value, spring.rest, MAX_OFFSET])
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
	juice.kick(5.0, 2.0)
	juice.advance(DT)
	assert_true(target.scale.x != 1.0, "scale.x moved (%s)" % target.scale.x)
	assert_true(target.rotation != 0.0, "rotation moved")
	# The pop is wider than tall: y follows x at 0.6, so a scale of 1.5 reads y = 1.3.
	assert_near(target.scale.y, 1.0 + (juice.scale_spring.value - 1.0) * 0.6, 0.0001,
		"squash shrinks the vertical scale by 0.6")
	_complete()


func test_juice_applies_to_control() -> void:
	var target := Control.new()
	target.size = Vector2(100, 40)
	_track(target)
	var juice := ChJuice.attach(target)
	juice.kick(5.0, 2.0)
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


func _peak_scale(juice: ChJuice, frames: int) -> float:
	var peak := juice.scale_spring.value
	for i in frames:
		juice.advance(DT)
		peak = maxf(peak, juice.scale_spring.value)
	return peak
