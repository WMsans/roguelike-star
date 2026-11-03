class_name ChEventBus extends RefCounted

# The battle's one-to-many announcements (spec §5.5): a part reports what it did, listeners that
# subscribed to that event type react to it. Delivery is synchronous, so a listener acts inside the
# emit that made it visible.
# An event emitted from inside a callback does not recurse: it queues behind the events already
# queued, so a chain is delivered breadth-first, one whole event at a time. That budget is capped
# (MAX_DELIVERIES per outer emit) because a chain that never ends would otherwise hang the game.

const MAX_DELIVERIES := 256

var subscriptions: Array = []  # of {"listener": Object, "type": StringName, "callback": Callable, "proximity_of": Object, "range": float}
var queued: Array = []  # ChEvents emitted during a delivery, waiting for their turn
var running: bool = false  # an emit is already delivering, so a nested emit must queue
var deliveries: int = 0  # callbacks called by the outer emit in flight


func subscribe(listener: Object, type: StringName, callback: Callable, proximity_of: Object = null,
		range: float = 0.0) -> void:
	# `listener` is only an identity key: unsubscribe_all drops everything registered under it.
	# shortcut: a listener may subscribe to the same type twice and hears twice; behaviours that
	# need "one per type" unsubscribe first, since a dedupe rule here would fight that.
	subscriptions.append({"listener": listener, "type": type, "callback": callback,
		"proximity_of": proximity_of, "range": range})


func unsubscribe_all(listener: Object) -> void:
	# remove_at keeps the order of the subscriptions that stay, so delivery order stays stable.
	var at := 0
	while at < subscriptions.size():
		if subscriptions[at]["listener"] == listener:
			subscriptions.remove_at(at)
		else:
			at += 1


func emit(event: ChEvent) -> void:
	if running:
		# Called from inside a callback: it goes behind the events already queued, which is what
		# makes the chain breadth-first rather than a depth-first recursion.
		queued.append(event)
		return
	running = true
	# The budget belongs to the outer emit, so it resets here and not per queued event.
	# shortcut: nested emits reuse the outer event's ChEvent object if a caller hands the same one
	# twice; the bus never copies an event, so a listener that mutates one sees it elsewhere.
	deliveries = 0
	_deliver(event)
	while not queued.is_empty():
		# A chain that will not end stops here: the whole rest of the queue is dropped with one
		# warning, so the emit that opened the chain is the one blamed.
		if deliveries >= MAX_DELIVERIES:
			push_warning("ChEventBus: delivery cap %d reached, dropping the queued events" % MAX_DELIVERIES)
			queued.clear()
			break
		_deliver(queued.pop_front())
	running = false


func _deliver(event: ChEvent) -> void:
	for subscription in subscriptions:
		# shortcut: the list is read live here, so a callback that subscribes or unsubscribes
		# during this delivery is not re-visited; upgrade to iterate a copy if a behaviour needs it.
		# StringName compare: an event type nobody subscribed to is simply dropped.
		if subscription["type"] != event.type:
			continue
		# emit above already refused the queued events; this keeps the cap hard for the subscribers
		# of one event, so a delivery never overruns it.
		if deliveries >= MAX_DELIVERIES:
			return
		if not _in_range(subscription["proximity_of"], subscription["range"], event):
			continue
		# Only a subscription that will fire spends the budget, so a chain of no-op event types
		# still costs nothing and cannot burn the cap.
		deliveries += 1
		# The callback takes the event as its only argument; bound arguments come first.
		(subscription["callback"] as Callable).call(event)


func _in_range(proximity_of: Object, range: float, event: ChEvent) -> bool:
	# A subscription with no proximity_of is chariot-wide: it hears whatever the type says.
	if proximity_of == null:
		return true
	# shortcut: `side` and anchor_world() are read duck-typed off both objects here (the test fakes
	# carry them); upgrade to the ChPartRuntime accessors once it gains `side` in Task 8.
	# A sourceless event has nothing to measure, so no proximity subscription can hear it.
	if event.source == null or event.source.side != proximity_of.side:
		# The far chariot's parts are never "near" this one, whatever the range says.
		return false
	return event.source.anchor_world().distance_to(proximity_of.anchor_world()) <= range
