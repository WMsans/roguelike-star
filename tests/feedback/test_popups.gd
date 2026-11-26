extends ChTest

# Task 4: the pooled screen-space pop-up layer Feedback.play() fills when a profile (or an
# override) carries text. Motion is stepped by advance(), never by Tween, so a test can walk a
# pop-up's whole life deterministically.
# CONTRACT: every test_* ends with _complete().


func _fresh():
	# The manager owns one layer for the whole game, so every test shares it: run the clock past
	# LIFE first, which hides whatever an earlier test left behind.
	var layer = Feedback.popups
	layer.advance(0.9)
	assert_eq(layer.active().size(), 0, "the layer starts idle")
	return layer


func test_pop_shows_text() -> void:
	var layer = _fresh()
	var label: RicherTextLabel = layer.pop("-12", Color.RED, Vector2(100, 100))
	assert_eq(layer.layer, 50, "the layer draws above the battle HUD")
	assert_eq(layer.active().size(), 1, "one active popup")
	assert_true(label.visible, "the label is visible")
	# Screen-space placement is exact at birth: the manager hands over the target's canvas point.
	assert_true(label.position.distance_to(Vector2(100, 100)) < 1.0,
		"placed at (100, 100), got %s" % label.position)
	# The addon defers its bbcode parse by a frame (richer_text_label.gd set_bbcode), so read the
	# text after it has run instead of before.
	var ml = Engine.get_main_loop()
	for i in 2:
		await ml.process_frame
	assert_true(label.get_parsed_text().contains("-12"), "source text holds -12")
	_complete()


func test_pop_expires() -> void:
	var layer = _fresh()
	var label: RicherTextLabel = layer.pop("-12", Color.RED, Vector2(100, 100))
	# Small steps, the way _process delivers them.
	for i in 40:
		layer.advance(0.01)
	assert_eq(layer.active().size(), 1, "still alive at 0.4 s")
	for i in 45:
		layer.advance(0.01)
	assert_eq(layer.active().size(), 0, "nothing is active after 0.85 s")
	assert_true(not label.visible, "the label is hidden at rest")
	_complete()


func test_pool_recycles_oldest() -> void:
	var layer = _fresh()
	for i in 40:
		layer.pop(str(i), Color.WHITE, Vector2(100, 100))
	assert_eq(layer.active().size(), 32, "the pool holds 32")
	# However many pops happen, the layer never grows past its pool.
	var children := 0
	for child in layer.get_children():
		if child is RicherTextLabel:
			children += 1
	assert_eq(children, 32, "32 labels exist in total")
	var ml = Engine.get_main_loop()
	for i in 2:
		await ml.process_frame
	var live: Array[RicherTextLabel] = layer.active()
	assert_eq(live.size(), 32, "32 still active a frame later")
	# The 8 oldest lives were recycled, so the 32 newest texts are exactly the survivors.
	for i in 8:
		var kept := false
		for label in live:
			if label.get_parsed_text() == str(i):
				kept = true
		assert_true(not kept, "text %d was recycled" % i)
	for i in range(32, 40):
		var found := false
		for label in live:
			if label.get_parsed_text() == str(i):
				found = true
		assert_true(found, "text %d survived" % i)
	_complete()


func test_play_struck_pops_amount() -> void:
	var layer = _fresh()
	# In the tree: play() reads the target's canvas transform for the screen point.
	var target := _parent()
	target.global_position = Vector2(120, 80)
	Feedback.play(&"struck", target, {"amount": 12})
	assert_eq(layer.active().size(), 1, "struck pops one label")
	var ml = Engine.get_main_loop()
	for i in 2:
		await ml.process_frame
	assert_true(layer.active()[0].get_parsed_text().contains("-12"),
		"the struck profile's -%d became -12")
	# hover's profile has no text, so a hover beat adds nothing to the layer.
	var before: int = layer.active().size()
	Feedback.play(&"hover", target)
	assert_eq(layer.active().size(), before, "hover pops nothing")
	_complete()
