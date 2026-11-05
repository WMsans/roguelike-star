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
var capped: bool = false  # the outer emit ran out of budget, so part of its delivery was dropped


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
	# `capped` remembers that the budget ran out anywhere in this emit — emit warns on it once, at
	# the end, because the drops happen in two places (this queue and _deliver's subscriber loop),
	# and a warning at either one alone misses a chain whose last callback did not re-emit.
	capped = false
	deliveries = 0
	_deliver(event)
	while not queued.is_empty():
		# A chain that will not end stops here: the whole rest of the queue is dropped, and `capped`
		# tells the warning below to name this emit as the one that opened the chain.
		if deliveries >= MAX_DELIVERIES:
			capped = true
			queued.clear()
			break
		_deliver(queued.pop_front())
	running = false
	# One warning per outer emit, and only when a callback that would have fired got dropped: _deliver
	# flags that itself, so a chain that ended on its own under the cap stays silent.
	if capped:
		# The brief's rule: dropped events get a push_warning.
		push_warning("ChEventBus: delivery cap %d reached, dropping the rest of the delivery" % MAX_DELIVERIES)


func _deliver(event: ChEvent) -> void:
	# Snapshot at delivery time: `for x in subscriptions` re-reads the live array by index, so a
	# callback that subscribes during this delivery WOULD be heard, and one that unsubscribes ahead
	# of the cursor would skip the subscriber behind it. The copy makes the guarantee explicit: a
	# delivery hears exactly the subscribers that existed when it started.
	# shortcut: the copy is shallow, so a subscription dict edited in place mid-delivery is still
	# read through; upgrade to a deep copy if a behaviour ever mutates the dicts.
	for subscription in subscriptions.duplicate():
		# StringName compare: an event type nobody subscribed to is simply dropped.
		if subscription["type"] != event.type:
			continue
		if not _in_range(subscription["proximity_of"], subscription["range"], event):
			continue
		# emit above already refused the queued events; this keeps the cap hard for the subscribers of
		# one event, so a delivery never overruns it. The eligibility checks run first so `capped`
		# only trips when a callback that would have fired is the one being dropped.
		if deliveries >= MAX_DELIVERIES:
			capped = true
			return
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
