extends ChTest

# Task 8: the part runtime and its status, from sand sampling (spec §5.7). Pure logic, so no
# make_world here: the runtime only reads global_position and global_rotation off its body, so a
# fake body stands in for the PixelRigidBody Task 9 attaches.
# The counts dicts stand in for PixelWorld.count_materials over sample_rect (Task 10's tick).
# shortcut: thresholds/numbers are literals per test; the tuning lives in ChPartDef and the
# behaviours (Tasks 12-14), not here.
# One 60 fps frame: the delta the live game ticks at, and what ChBattleContext.tick (Task 10)
# hands apply_sample each frame.
const LAVA_TICK := 1.0 / 60.0


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
# `integrity` seeds the runtime field, which is what lava wear reads back; `flipped` is the slot's
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


# Subscribe `part` to each of `types` and hand back the list the callbacks fill as the bus delivers.
# Array is a reference type, so the test reads the same list the lambdas hold. Callers unsubscribe
# at the end: a callback that holds the bus is a reference cycle (the event bus tests do the same,
# and Task 10's break_part unsubscribes on that seam).
func _hears(bus: ChEventBus, part: ChPartRuntime, types: Array[StringName]) -> Array[StringName]:
	var heard: Array[StringName] = []
	for type in types:
		bus.subscribe(part, type, func(event: ChEvent): heard.append(event.type))
	return heard


func test_catches_fire_emits_once() -> void:
	var bus := ChEventBus.new()
	var part := _runtime(0, 1.0, Vector2(10, 20), 100)
	var heard: Array[ChEvent] = []
	# A proximity subscription keyed on the part itself: ChPartRuntime carries `side` and
	# anchor_world(), which is exactly what ChEventBus's proximity filter reads duck-typed, so this
	# closes the seam Task 6 left provisional. Unsubscribed at the end to break the bus<->callback
	# cycle (Task 10's break_part unsubscribes on the same seam).
	bus.subscribe(part, ChEvent.CAUGHT_FIRE, func(event: ChEvent): heard.append(event), part, 24.0)
	# Under the threshold first: 2 fire cells is not burning and emits nothing.
	part.apply_sample({&"fire": 2}, 1.0, bus)
	assert_true(not part.burning, "2 fire cells is under the 3-cell burning threshold")
	assert_eq(heard.size(), 0, "nothing caught, so nothing emitted")
	# Crossing the threshold burns and emits once.
	part.apply_sample({&"fire": 3}, 1.0, bus)
	assert_true(part.burning, "3 fire cells is burning")
	assert_eq(heard.size(), 1, "the not-burning -> burning transition emits")
	assert_eq(heard[0].type, ChEvent.CAUGHT_FIRE, "the transition the brief names")
	assert_eq(heard[0].side, part.side, "the event carries the part's own side")
	assert_eq(heard[0].source, part, "the event's source is the part that caught")
	assert_eq(heard[0].position, part.anchor_world(), "the event is positioned at the part")
	# Still in fire the next tick: burning is a state, so the transition already fired.
	part.apply_sample({&"fire": 5}, 1.0, bus)
	assert_eq(heard.size(), 1, "an already burning part does not re-emit")
	assert_true(part.burning, "fire keeps the part burning")
	# sample_rect and facing are the other accessors the later tasks hang on; no listed test names
	# them, so this pins the box for a 1-cell part: the body's box is def.size cells centred on its
	# position, grown by 2 cells. The wheel-sized footprint is the next test's job.
	assert_eq(part.sample_rect(), Rect2i(7, 17, 6, 6), "the 1-cell box centred on the anchor, grown by 2 cells")
	assert_eq(part.facing(), Vector2.RIGHT, "unflipped at rotation 0 faces +x")
	# A flipped slot faces back (spec §5.4 facing), and a body rotation turns that direction. The
	# quarter turn is only near exact: cos(PI/2) leaves a float residue in x.
	var flipped_part := _runtime(0, 1.0, Vector2(0, 0), 100, true)
	assert_eq(flipped_part.facing(), Vector2.LEFT, "a flipped slot faces back")
	var turned := _runtime(0, 1.0, Vector2(0, 0), 100, false, PI / 2.0)
	assert_near(turned.facing().x, 0.0, 0.001, "a quarter turn drops the x component")
	assert_near(turned.facing().y, 1.0, 0.001, "a quarter turn faces +y")
	bus.unsubscribe_all(part)
	_complete()


func test_water_extinguishes() -> void:
	var bus := ChEventBus.new()
	# No listener: this test reads the burning flag, not the events.
	var part := _runtime(1, 0.0, Vector2(30, 40), 100)
	part.apply_sample({&"fire": 4}, 1.0, bus)
	assert_true(part.burning, "4 fire cells: burning before the water arrives")
	# Water wins over the fire rule: 6 cells put the part out even while it stands in fire.
	part.apply_sample({&"fire": 4, &"water": 6}, 1.0, bus)
	assert_true(not part.burning, "6 water cells put the burning out")
	# 5 cells is contact, not enough to douse, so the fire re-catches the same tick.
	part.apply_sample({&"fire": 4, &"water": 5}, 1.0, bus)
	assert_true(part.burning, "5 water cells do not extinguish")
	# Deep water with no fire leaves it out: burning is a state, not a sticky burn.
	part.apply_sample({&"water": 8}, 1.0, bus)
	assert_true(not part.burning, "deep water with no fire leaves the part unburning")
	_complete()


func test_freeze_builds_and_emits_frozen() -> void:
	var bus := ChEventBus.new()
	var part := _runtime(0, 2.0, Vector2(50, 60), 100)
	# A global subscription (no proximity_of): the proximity seam is the fire test's job, so the type
	# alone is enough. No fire in these samples, so heard stays about freeze.
	var heard := _hears(bus, part, [ChEvent.FROZEN])
	# 3 frost cells is under a group of 4, so the build stays at 0: the brief's rule counts whole
	# groups of 4 cells, and "none present" only means nothing cold at all.
	part.apply_sample({&"frost": 3}, 1.0, bus)
	assert_near(part.freeze, 0.0, 0.001, "under one group of 4 frost cells builds nothing")
	assert_true(not part.is_frozen(), "nothing built, so nothing frozen")
	assert_eq(heard, [], "freeze has not reached 1.0, so no FROZEN event")
	# 8 cells is two groups, so 2 x 0.6 x 1 s = 1.2, capped at 1.0: that reaches frozen and emits.
	part.apply_sample({&"frost": 8}, 1.0, bus)
	assert_near(part.freeze, 1.0, 0.001, "the build caps at 1.0 instead of overshooting")
	assert_true(part.is_frozen(), "freeze at 1.0 is frozen")
	assert_eq(heard, [ChEvent.FROZEN], "reaching 1.0 emits FROZEN")
	# ice counts the same way as frost, and an already frozen part does not re-emit.
	part.apply_sample({&"ice": 8}, 1.0, bus)
	assert_near(part.freeze, 1.0, 0.001, "still capped at 1.0")
	assert_eq(heard, [ChEvent.FROZEN], "a frozen part does not re-emit FROZEN")
	bus.unsubscribe_all(part)
	_complete()


func test_thaw_emits() -> void:
	var bus := ChEventBus.new()
	var part := _runtime(1, 0.0, Vector2(70, 80), 100)
	var heard := _hears(bus, part, [ChEvent.THAWED])
	# Seeded straight at frozen: this test reads the decay rule, so it starts from the state a frost
	# sample would have left (freeze capped at 1.0).
	part.freeze = 1.0
	assert_true(part.is_frozen(), "the part starts frozen")
	# Nothing cold touches it, so freeze decays at 0.25/s: 1.0 -> 0.75, and the part stays frozen
	# while the meter decays (spec §5.7), so a full meter holds for 4 s rather than one tick.
	part.apply_sample({}, 1.0, bus)
	assert_near(part.freeze, 0.75, 0.001, "the 0.25/s decay over a 1 s tick")
	assert_true(part.is_frozen(), "a decaying meter keeps the part frozen")
	assert_eq(heard, [], "so nothing thawed yet")
	# Decay clamps at 0, and reaching 0 is the thaw.
	part.apply_sample({}, 10.0, bus)
	assert_near(part.freeze, 0.0, 0.001, "decay clamps at 0 instead of going negative")
	assert_true(not part.is_frozen(), "at 0 the part is no longer frozen")
	assert_eq(heard, [ChEvent.THAWED], "leaving frozen emits THAWED")
	part.apply_sample({}, 1.0, bus)
	assert_eq(heard, [ChEvent.THAWED], "an already thawed part does not re-emit THAWED")
	# A frost touch that does not reach 1.0 re-builds freeze without freezing: one group for half a
	# second is 0.3, so neither FROZEN nor THAWED fires.
	part.apply_sample({&"frost": 4}, 0.5, bus)
	assert_near(part.freeze, 0.3, 0.001, "one group of 4 frost cells for 0.5 s builds 0.3")
	assert_true(not part.is_frozen(), "0.3 is not frozen")
	assert_eq(heard, [ChEvent.THAWED], "a partial build emits nothing")
	bus.unsubscribe_all(part)
	_complete()


func test_frozen_pauses_cooldown() -> void:
	# A weapon with a 2 s cooldown, frozen: the countdown has to hold while frozen and run once it
	# thaws. This is spec §5.7's "a weapon's cooldown pauses"; the wheel motor is Task 9's.
	var part := _runtime(0, 2.0, Vector2(0, 0), 100)
	part.freeze = 1.0
	part.cooldown_left = 2.0
	# The paused tick: still 2 s, and a frozen part is never ready.
	assert_eq(part.tick_cooldown(0.5), false, "a frozen part's cooldown does not advance")
	assert_eq(part.cooldown_left, 2.0, "the cooldown stayed at 2 s across a frozen tick")
	# Decay alone keeps it frozen until the meter is empty: 1 s leaves 0.75, still paused.
	var bus := ChEventBus.new()
	part.apply_sample({}, 1.0, bus)
	assert_true(part.is_frozen(), "a decaying meter is still frozen")
	assert_eq(part.tick_cooldown(0.5), false, "so the countdown still holds")
	assert_eq(part.cooldown_left, 2.0, "at 2 s")
	# 3 more seconds empty the meter (0.25/s), which is the thaw (nothing cold in the sample).
	part.apply_sample({}, 3.0, bus)
	assert_true(not part.is_frozen(), "an empty meter leaves the frozen state")
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


func test_lava_wears_at_a_live_delta():
	# The reviewer's finding: at the real 60 fps delta one lava tick is 20 * 0.0167 = 0.33 integrity,
	# which used to round to nothing, so lava never wore anything. Wear accrues in a float instead.
	var bus := ChEventBus.new()
	var part := _runtime(0, 0.0, Vector2(20, 150), 100)
	# 3 lava cells is also the burning threshold, so this shows both rules the brief puts in one method.
	part.apply_sample({&"lava": 3}, LAVA_TICK, bus)
	assert_true(part.burning, "3 lava cells still catch the part alight")
	assert_eq(part.integrity, 100, "one 60 fps tick pays no whole point yet")
	assert_near(part.lava_wear_left, 20.0 * LAVA_TICK, 0.0001, "the tick's 0.33 integrity is held back")
	# One 60 fps tick wears nothing on its own, which is why this test has to repeat the tick: 60 more
	# of them are 1.0167 s of lava = 20.33 integrity, so 20 points get paid and a third of a point
	# stays held back. The old round-per-tick rule paid 0 for every one of these 61 ticks.
	for _tick in 60:
		part.apply_sample({&"lava": 3}, LAVA_TICK, bus)
	assert_eq(part.integrity, 80, "61 ticks of 60 fps lava paid 20 whole integrity points")
	assert_near(part.lava_wear_left, 20.0 * LAVA_TICK, 0.01, "the unpaid fraction stays for the next tick")
	assert_true(part.burning, "the part has stayed burning throughout")
	_complete()


func test_lava_wears_integrity() -> void:
	var bus := ChEventBus.new()
	var part := _runtime(0, 0.0, Vector2(20, 150), 100)
	# Deep lava is both the burning threshold and the wear source, so one sample shows both rules the
	# brief puts in one method.
	part.apply_sample({&"lava": 3}, 1.0, bus)
	assert_true(part.burning, "lava counts toward burning")
	assert_eq(part.integrity, 80, "lava wears 20 integrity per second")
	part.apply_sample({&"lava": 3}, 1.0, bus)
	assert_eq(part.integrity, 60, "wear is per tick, not a one-shot transition")
	# A short tick pays a short wear: 20 * 0.1 = 2.
	part.apply_sample({&"lava": 3}, 0.1, bus)
	assert_eq(part.integrity, 58, "a 0.1 s tick wears 2")
	# Fire alone does not wear: only lava does.
	part.apply_sample({&"fire": 4}, 1.0, bus)
	assert_eq(part.integrity, 58, "fire burns but does not wear integrity")
	# Wear clamps at 0; reaching 0 breaks the part, which is Task 10's break_part rule, not this one.
	part.apply_sample({&"lava": 20}, 100.0, bus)
	assert_eq(part.integrity, 0, "wear clamps at 0 instead of going negative")
	_complete()
