extends ChTest

# The four rows the result panel can show: what the title says, what the one button offers, and
# whether the panel ends the run (what ChMain's back handler branches on). The panel is built but never
# added to the tree here, the way tests/feedback/test_ui_feedback.gd uses it: show_result only writes
# to the title and the button, both of which _init already made.
func _panel(result: StringName, last_fight := false) -> ChResultPanel:
	var panel := ChResultPanel.new()
	_track(panel)
	panel.show_result(result, last_fight)
	return panel

func test_titles() -> void:
	var won := _panel(&"win")
	assert_eq(won.title.text, "You win", "a fight that is not the last one")
	assert_eq(won.back.text, "Continue")
	assert_true(not won.ends_run, "and the run goes on")

	var last := _panel(&"win", true)
	assert_eq(last.title.text, "Run won", "the last fight's win is the run ending")
	assert_eq(last.back.text, "New run")
	assert_true(last.ends_run)

	var lost := _panel(&"loss")
	assert_eq(lost.title.text, "Run over")
	assert_eq(lost.back.text, "New run")
	assert_true(lost.ends_run)

	var drew := _panel(&"draw")
	assert_eq(drew.title.text, "Run over")
	assert_eq(drew.back.text, "New run")
	assert_true(drew.ends_run)

	var aborted := _panel(&"aborted")
	assert_eq(aborted.title.text, "No fight: the battle could not start", "nothing was fought")
	assert_eq(aborted.back.text, "Retry")
	assert_true(not aborted.ends_run, "a fight that could not start is not a lost run")
	_complete()
