extends ChTest

# Task 3: the profile table behind every beat and the one entry point the rest of the game calls,
# Feedback.play(). Only the juice kick exists here; text, particles and shake land in later tasks.
# CONTRACT: every test_* ends with _complete() because the runner counts that as the
# completion marker (a body that aborts mid-way would otherwise pass silently).


func test_every_kind_has_a_profile() -> void:
	for kind in ChFeedbackManager.KINDS:
		assert_true(Feedback.profile(kind) != null, "%s has a profile" % kind)
	_complete()


func test_play_kicks_juice() -> void:
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	# The sign of the rotation kick is randomised per play, so only its size is fixed.
	Feedback.play(&"fired", target)
	assert_eq(juice.scale_spring.velocity, 6.0, "fired kicks scale by 6")
	assert_eq(absf(juice.rotation_spring.velocity), deg_to_rad(8), "fired kicks rotation by 8 degrees")
	_complete()


func test_play_without_juice_is_safe() -> void:
	var target := Node2D.new()
	_track(target)
	Feedback.play(&"fired", target)
	# Attaching belongs to the target's owner (buttons here, battle visuals and the garage later),
	# so play must leave a Juice-less target alone instead of adding one.
	assert_true(ChJuice.of(target) == null, "play does not attach a Juice of its own")
	_complete()


func test_play_on_freed_target_is_safe() -> void:
	var target := Node2D.new()
	_track(target)
	ChJuice.attach(target)
	target.free()
	Feedback.play(&"fired", target)
	assert_true(not is_instance_valid(target), "the freed target stays freed")
	_complete()


func test_unknown_kind_is_ignored() -> void:
	var target := Node2D.new()
	_track(target)
	var juice := ChJuice.attach(target)
	var failures_before := failures.size()
	Feedback.play(&"nope", target)
	assert_eq(juice.scale_spring.velocity, 0.0, "an unknown kind leaves the scale at rest")
	assert_eq(juice.rotation_spring.velocity, 0.0, "an unknown kind leaves the rotation at rest")
	assert_eq(failures.size(), failures_before, "an unknown kind is a warning, not a failed play")
	_complete()


func test_attach_button_wires_press_and_hover() -> void:
	var button := Button.new()
	_track(button)
	# Twice: wiring is idempotent, so the second call adds no Juice and no connection.
	Feedback.attach_button(button)
	Feedback.attach_button(button)
	var juice := ChJuice.of(button)
	assert_true(juice != null, "the button has a Juice")
	var juice_children := 0
	for child in button.get_children():
		if child is ChJuice:
			juice_children += 1
	assert_eq(juice_children, 1, "the button has exactly one Juice child")
	assert_eq(button.pressed.get_connections().size(), 1, "one pressed connection")
	assert_eq(button.mouse_entered.get_connections().size(), 1, "one mouse_entered connection")
	button.pressed.emit()
	assert_eq(juice.scale_spring.velocity, 5.0, "pressing kicks the activate profile's 5")
	button.mouse_entered.emit()
	assert_eq(juice.scale_spring.velocity, 7.0, "hover adds its 2 on top")
	_complete()
