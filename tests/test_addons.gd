extends ChTest


# The rig both Phantom Camera tests use: the addon's host only drives the Camera2D it is a child
# of (phantom_camera_host.gd: "Needs to be a child of a Camera2D"), and a pcam has to be live in
# the tree for the manager to hand it to the host.
func _camera_rig() -> Array:
	var parent := _parent()
	var camera := Camera2D.new()
	camera.add_child(PhantomCameraHost.new())
	parent.add_child(camera)
	var pcam := PhantomCamera2D.new()
	pcam.priority = 1
	pcam.follow_mode = PhantomCamera2D.FollowMode.NONE
	# The addon's default tween_on_load ramps the camera's zoom from its current value over
	# tween_resource.duration (1 s), so asking for the documented snap keeps the rig's assertions
	# about where the camera lands instead of how fast it got there.
	pcam.tween_on_load = false
	parent.add_child(pcam)
	pcam.global_position = Vector2(100, 50)
	pcam.zoom = Vector2(4, 4)
	return [camera, pcam]


func test_phantom_camera_loads() -> void:
	var rig := _camera_rig()
	var camera: Camera2D = rig[0]
	var ml = Engine.get_main_loop()
	for i in 5:
		await ml.process_frame
	assert_near(camera.global_position.x, 100.0, 0.5)
	assert_near(camera.zoom.x, 4.0, 0.01)
	_complete()


func test_noise_emitter_moves_camera() -> void:
	var rig := _camera_rig()
	var camera: Camera2D = rig[0]
	var pcam: PhantomCamera2D = rig[1]
	# The emitter's default layer is 1, and a pcam ignores noise unless a layer matches, so the
	# rig asks for it explicitly instead of relying on the addon's default of 0.
	pcam.noise_emitter_layer = 1
	var emitter := PhantomCameraNoiseEmitter2D.new()
	var noise := PhantomCameraNoise2D.new()
	noise.amplitude = 10.0
	emitter.noise = noise
	emitter.duration = 0.3
	camera.get_parent().add_child(emitter)
	var ml = Engine.get_main_loop()
	for i in 5:
		await ml.process_frame
	emitter.emit()
	var moved := false
	for i in 10:
		await ml.process_frame
		assert_true(emitter.is_emitting(), "emitting on frame %d" % i)
		# The noise ramps from Perlin's zero at the noise field's origin, so 10 headless frames
		# (~1/150 s each) move the camera by about a pixel; a sub-pixel epsilon still proves the
		# emitter reached the camera through the manager rather than nothing having happened.
		if camera.get_screen_center_position().distance_to(Vector2(100, 50)) > 0.01:
			moved = true
	assert_true(moved, "noise pushed the camera off (100, 50)")
	for i in 40:
		await ml.process_frame
	assert_true(not emitter.is_emitting(), "the 0.3 s emission stopped")
	_complete()


func test_richer_text_label_loads() -> void:
	var layer := CanvasLayer.new()
	Engine.get_main_loop().get_root().add_child(_track(layer))
	var label := RicherTextLabel.new()
	layer.add_child(label)
	label.bbcode = "[jump]-12[]"
	var ml = Engine.get_main_loop()
	for i in 2:
		await ml.process_frame
	assert_true(label.get_parsed_text().contains("-12"))
	_complete()
