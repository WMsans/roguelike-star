extends ChTest

# Task 6: the event bus (spec §5.5). Pure logic, so no make_world here.
# Sources are fakes standing in for ChPartRuntime (Task 8): a proximity subscription reads `side`
# and anchor_world() off both the event source and its proximity_of, duck-typed.
# shortcut: duck-typed until ChPartRuntime gains `side`; these fakes carry both.
# Callbacks are lambdas: they capture `heard`/`order`/`bus` by reference (Array/Object are
# reference types), so a delivery can grow the record the test reads back.


class FakeSource extends RefCounted:
	var side: int = 0
	var anchor: Vector2 = Vector2.ZERO

	func anchor_world() -> Vector2:
		# The fake anchor is already a world position, so distance_to reads plain cell distance.
		return anchor


func _source(side: int, at: Vector2) -> FakeSource:
	var src := FakeSource.new()
	src.side = side
	src.anchor = at
	return src


func _event(type: StringName, source: Object) -> ChEvent:
	var event := ChEvent.new()
	event.type = type
	# A null source is a chariot-wide event, so it carries no side or position.
	event.source = source
	if source != null:
		# shortcut: FakeSource is the only source type these tests build.
		# ChEvent.side names the chariot the event belongs to; the bus filter reads the source.
		event.side = source.side
		event.position = source.anchor_world()
	return event


func test_global_subscriber_receives() -> void:
	var bus := ChEventBus.new()
	var heard: Array[StringName] = []
	# proximity_of defaults to null, so this subscription is chariot-wide.
	bus.subscribe(_listener(), ChEvent.HIT, func(event: ChEvent): heard.append(event.type))
	bus.subscribe(_listener(), ChEvent.ENERGY_GAINED, func(event: ChEvent): heard.append(event.type))
	# A source far away and a source-less event both reach a global subscriber.
	bus.emit(_event(ChEvent.HIT, _source(0, Vector2(900, 0))))
	bus.emit(_event(ChEvent.ENERGY_GAINED, null))
	assert_eq(heard, [ChEvent.HIT, ChEvent.ENERGY_GAINED], "a global subscriber hears both, sourceless included")
	_complete()


func test_proximity_filters_by_range_and_side() -> void:
	var bus := ChEventBus.new()
	var heard: Array[Object] = []
	var watch := _source(1, Vector2.ZERO)
	# Two enemy-side sources 10 and 30 cells from the watcher, plus a player-side source sitting on
	# the watcher itself: on range alone it would pass, so it has to fail on the side check.
	var near := _source(1, Vector2(10, 0))
	var far := _source(1, Vector2(30, 0))
	var other := _source(0, Vector2.ZERO)
	bus.subscribe(_listener(), ChEvent.HIT, func(event: ChEvent): heard.append(event.source), watch, 24.0)
	bus.emit(_event(ChEvent.HIT, near))
	bus.emit(_event(ChEvent.HIT, far))
	bus.emit(_event(ChEvent.HIT, other))
	assert_eq(heard, [near], "only the 10-cell same-side source is inside range 24")
	_complete()


func _listener() -> RefCounted:
	# A listener is only an identity key for unsubscribe_all.
	return RefCounted.new()


func test_nested_emits_breadth_first() -> void:
	var bus := ChEventBus.new()
	var order: Array[String] = []
	var src := _source(0, Vector2.ZERO)
	var a_listener := _listener()
	var b := _listener()
	# Registered first, so A's callback runs before B hears A: X is queued while A is still being
	# delivered, and a depth-first bus would put X between A_event and B_event.
	bus.subscribe(a_listener, &"a", func(event: ChEvent): order.append("A_event"); bus.emit(_event(&"x", src)))
	bus.subscribe(b, &"a", func(event: ChEvent): order.append("B_event"))
	bus.subscribe(b, &"x", func(event: ChEvent): order.append("X"))
	bus.emit(_event(&"a", src))
	assert_eq(order, ["A_event", "B_event", "X"], "the nested event waits behind the current one")
	# A callback that re-emits holds the bus, and the bus holds the callback: unsubscribing at the
	# end breaks that reference cycle, otherwise the run ends with leaked-instance noise.
	bus.unsubscribe_all(a_listener)
	bus.unsubscribe_all(b)
	_complete()


func test_chain_cap() -> void:
	var bus := ChEventBus.new()
	var counted: Array[int] = [0]
	var src := _source(0, Vector2.ZERO)
	var repeater := _listener()
	# Every delivery queues another event, so only the cap can end this chain.
	bus.subscribe(repeater, ChEvent.PART_FIRED, func(event: ChEvent): counted[0] += 1; bus.emit(_event(event.type, src)))
	bus.emit(_event(ChEvent.PART_FIRED, src))
	assert_eq(counted[0], 256, "the chain stops at the 256 delivery cap")
	# The callback keeps the bus alive through the bus's own subscription list: unsubscribing lets it
	# go, so the leaked-instance noise stays out of the run.
	bus.unsubscribe_all(repeater)
	_complete()


func test_unsubscribe_all() -> void:
	var bus := ChEventBus.new()
	var heard: Array[String] = []
	var shared := _listener()
	var other := _listener()
	bus.subscribe(shared, ChEvent.FROZEN, func(event: ChEvent): heard.append("shared frozen"))
	bus.subscribe(shared, ChEvent.THAWED, func(event: ChEvent): heard.append("shared thawed"))
	bus.subscribe(other, ChEvent.FROZEN, func(event: ChEvent): heard.append("other frozen"))
	bus.emit(_event(ChEvent.FROZEN, _source(1, Vector2(1, 0))))
	bus.unsubscribe_all(shared)
	bus.emit(_event(ChEvent.FROZEN, _source(1, Vector2(1, 0))))
	bus.emit(_event(ChEvent.THAWED, null))
	bus.unsubscribe_all(_listener())
	assert_eq(heard, ["shared frozen", "other frozen", "other frozen"], "shared dropped both of its subscriptions, other kept its")
	_complete()
