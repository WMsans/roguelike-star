extends ChTest


func test_passes() -> void:
	assert_eq(1 + 1, 2)
	_complete()


# The committed suite had no `await` before, so the coroutine path (the runner awaiting a
# test method, and ChTest.make_world waiting for its world) was unproven. This covers it.
func test_awaits_two_frames() -> void:
	var ml = Engine.get_main_loop()
	await ml.process_frame
	await ml.process_frame
	assert_true(Engine.get_process_frames() >= 2, "the runner resumed the coroutine after two frames")
	_complete()
