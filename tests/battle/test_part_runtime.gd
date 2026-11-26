extends ChTest

# Task 8: the part runtime: its box, facing, cooldown and the status reads. Pure logic, so no
# make_world here: the runtime only reads global_position and global_rotation off its body, so a
# fake body stands in for the PixelRigidBody Task 9 attaches. The status second itself is
# tests/battle/test_status_second.gd's.


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


# A body standing in for the PixelRigidBody Task 9 attaches: the runtime reads position/rotation
# only. The fake has no collision shape, so sample_rect takes its 1-cell fallback box.
func _body(at: Vector2, rotation: float = 0.0) -> FakeBody:
	var body := FakeBody.new()
	body.global_position = at
	body.global_rotation = rotation
	return body


# A part with a real ChPartDef (only `cooldown` matters here: 0 = passive) and a fake body at `at`.
# `integrity` seeds the runtime field; `flipped` is the slot's
# left/right flip. charges_left -1 is unlimited, and path/joint stay default: no listed test walks
# the tree or pulls a joint.
func _runtime(side: int, cooldown: float, at: Vector2, integrity: int, flipped := false,
	rotation := 0.0) -> ChPartRuntime:
	var runtime := ChPartRuntime.new()
	var part_def := ChPartDef.new()
	part_def.cooldown = cooldown
	runtime.def = part_def
	runtime.side = side
	runtime.flipped = flipped
	runtime.integrity = integrity
	runtime.charges_left = -1
	# body: Object is loose on purpose: a PixelRigidBody-typed var rejects these fakes (verified
	# parse error), so Task 9 is the one that attaches the real body.
	# rotation is radians: facing() is the body's +x turned by it, mirrored when flipped.
	runtime.body = _body(at, rotation)
	return runtime


func test_sample_rect_and_facing() -> void:
	var part := _runtime(0, 1.0, Vector2(10, 20), 100)
	# The body's box is def.size cells centred on its position, grown by 2 cells.
	assert_eq(part.sample_rect(), Rect2i(7, 17, 6, 6), "the 1-cell box centred on the anchor, grown by 2 cells")
	assert_eq(part.facing(), Vector2.RIGHT, "unflipped at rotation 0 faces +x")
	# A flipped slot faces back (spec §5.4 facing), and a body rotation turns that direction. The
	# quarter turn is only near exact: cos(PI/2) leaves a float residue in x.
	var flipped_part := _runtime(0, 1.0, Vector2(0, 0), 100, true)
	assert_eq(flipped_part.facing(), Vector2.LEFT, "a flipped slot faces back")
	var turned := _runtime(0, 1.0, Vector2(0, 0), 100, false, PI / 2.0)
	assert_near(turned.facing().x, 0.0, 0.001, "a quarter turn drops the x component")
	assert_near(turned.facing().y, 1.0, 0.001, "a quarter turn faces +y")
	_complete()


func test_frozen_and_burning_read_the_stacks() -> void:
	var part := _runtime(0, 2.0, Vector2(0, 0), 100)
	assert_true(not part.is_frozen() and not part.is_burning(), "no stacks, neither")
	part.statuses.stacks[ChStatuses.FREEZE] = 1
	part.statuses.stacks[ChStatuses.FLAME] = 1
	assert_true(part.is_frozen() and part.is_burning(), "one stack each is enough")
	assert_true(not part.is_ready(), "a frozen part is never ready")
	_complete()


func test_frozen_pauses_cooldown() -> void:
	# A weapon with a 2 s cooldown, frozen: the countdown holds while frozen and runs once it thaws.
	var part := _runtime(0, 2.0, Vector2(0, 0), 100)
	part.statuses.stacks[ChStatuses.FREEZE] = 2
	part.cooldown_left = 2.0
	assert_eq(part.tick_cooldown(0.5), false, "a frozen part's cooldown does not advance")
	assert_eq(part.cooldown_left, 2.0, "the cooldown stayed at 2 s across a frozen tick")
	part.statuses.clear(ChStatuses.FREEZE)
	assert_eq(part.tick_cooldown(1.0), false, "1.0 of a 2 s cooldown is not ready yet")
	assert_eq(part.cooldown_left, 1.0, "thawed, the countdown runs")
	assert_eq(part.tick_cooldown(1.0), true, "reaching 0 reports ready")
	assert_eq(part.cooldown_left, 0.0, "the countdown clamps at 0")
	# Ready is one-sided: past 0 it stays ready, so the caller (Task 10's tick) owns the reset.
	assert_eq(part.tick_cooldown(1.0), true, "already at 0 stays ready")
	# A passive part has no cooldown to count, so it never reports ready: nothing to gate on energy.
	var passive := _runtime(0, 0.0, Vector2(0, 0), 100)
	assert_eq(passive.tick_cooldown(1.0), false, "a part with cooldown 0 never becomes ready")
	assert_eq(passive.cooldown_left, 0.0, "a passive part has no cooldown to count down")
	_complete()


func test_sample_rect_covers_a_wheel() -> void:
	# The reviewer's finding: a wheel-sized def (game/data/parts/wheel.tres is 12x12 cells) sampled
	# with a box anchored at the anchor sits up to 11 cells off the body. The body's box is def.size
	# cells centred on its position, turned by its rotation and mirrored by the slot flip.
	# The real wheel def (game/data/parts/wheel.tres is 12x12 cells), handed to a part instead of the
	# 1x1 default ChPartDef._runtime builds.
	var wheel: ChPartDef = load("res://game/data/parts/wheel.tres")
	assert_eq(wheel.size, Vector2i(12, 12), "the wheel is 12 cells across")
	var part := _runtime(0, 0.0, Vector2(100, 200), 100)
	part.def = wheel
	var rect := part.sample_rect()
	# Unrotated: x covers cells 94..105, y covers 194..205, so grown by 2 cells the rect is
	# (92, 192, 16, 16). It covers the anchor cell itself, which an anchor-cornered box does not.
	assert_eq(rect, Rect2i(92, 192, 16, 16), "the 12-cell box centred on the anchor, grown by 2 cells")
	assert_true(rect.has_point(Vector2i(100, 200)), "the rect covers the part's own anchor cell")
	# A quarter turn: the box swaps its axes, so the footprint stays the same size and still covers
	# the body.
	var turned := _runtime(0, 0.0, Vector2(100, 200), 100)
	turned.def = wheel
	turned.body = _body(Vector2(100, 200), PI / 2.0)
	# The quarter turn's box edges land exactly on cell borders, where a float residue could move
	# the rect one cell, so this pins the cells the rect covers rather than its numbers.
	assert_true(turned.sample_rect().has_point(Vector2i(100, 200)), "the turned rect covers the anchor")
	assert_true(turned.sample_rect().has_point(Vector2i(93, 200))
		and turned.sample_rect().has_point(Vector2i(106, 200)),
		"the turned rect reaches the body's own cells at both ends")
	# A diagonal turn is where the AABB grows: an unrotated box would stay 12 cells wide and miss the
	# corners the body actually reaches.
	var angled := _runtime(0, 0.0, Vector2(100, 200), 100)
	angled.def = wheel
	angled.body = _body(Vector2(100, 200), PI / 4.0)
	# 12 * sqrt(2) ~= 16.97 cells across, which touches cells 91..108 (18 cells), grown to 22.
	assert_eq(angled.sample_rect(), Rect2i(89, 189, 22, 22), "a 45° turn grows the AABB to 18 cells")
	assert_true(angled.sample_rect().has_point(Vector2i(100, 200)), "the angled rect still covers the anchor")
	# A flip mirrors the footprint's x axis; a square centred on the anchor lands back on itself, so
	# the rect stays where the unflipped part put it.
	var flipped := _runtime(0, 0.0, Vector2(100, 200), 100, true)
	flipped.def = wheel
	assert_eq(flipped.sample_rect(), rect, "a flip leaves the centred square footprint on the same cells")
	_complete()
