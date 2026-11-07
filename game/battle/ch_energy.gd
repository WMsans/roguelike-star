class_name ChEnergy extends RefCounted

# The battle's energy pool: a value that regenerates, a drive cost paid while a direction is held,
# and the parts waiting in line for it (spec §5.3). A part that cannot pay its cost queues its
# requester and fires on a later tick; the queue is strict FIFO, so the head blocks everything
# behind it and a part is never starved indefinitely.
# Tick order is fixed by spec §5.3: regen, then the drive, then the waiting parts, so a held
# direction always beats a waiting part and delays it visibly rather than deadlocking it.

var value: float = 0.0
var cap: float = 0.0
var regen: float = 0.0
var drive_cost: float = 2.0
var queue: Array = []  # FIFO of {"requester": Object, "cost": float}
var spent: float = 0.0  # every point paid since construction, drive and requests both (balance runner)


func _init(cap: float, regen: float, drive_cost: float = 2.0) -> void:
	# The parameters shadow the members of the same name, so self. names the member being written.
	self.cap = cap
	self.regen = regen
	self.drive_cost = drive_cost
	value = cap


func request(requester: Object, cost: float) -> void:
	# One entry per requester: a part that is already waiting does not queue a second line.
	if _queued(requester):
		# shortcut: the first request's cost wins; a part that changes its cost while waiting has
		# to cancel and request again.
		return
	queue.append({"requester": requester, "cost": cost})


func cancel(requester: Object) -> void:
	# cancel drops a waiting part's entry, so the part re-queues at its new cost on request.
	for at in range(queue.size()):
		if queue[at]["requester"] == requester:
			# request keeps at most one entry per requester, so the first match is the only one.
			queue.remove_at(at)
			return


func queue_size() -> int:
	return queue.size()


func is_queued(requester: Object) -> bool:
	# Public for the balance runner, which counts the seconds a part spends waiting in line.
	return _queued(requester)


func _queued(requester: Object) -> bool:
	# Object == compares identity, and request keeps one entry per requester, so the first match is
	# the only one.
	for entry in queue:
		if entry["requester"] == requester:
			return true
	return false


func tick(delta: float, driving: bool) -> Dictionary:
	# Regen first, so a tick that both refills and pays can fire a part that was one point short.
	# minf clamps the pool rather than letting it overflow, so regen buys nothing above cap.
	value = minf(value + regen * delta, cap)
	var drove: bool = false
	# A drive that does not fit is not taken: driving spends nothing and queues nothing, so a
	# chariot with no energy stays put rather than going into debt.
	# shortcut: the drive pays whole for the whole delta; splitting a delta into smaller steps is
	# a caller's job, since a part of a drive costs nothing here.
	if driving and value >= drive_cost * delta:
		value -= drive_cost * delta
		spent += drive_cost * delta
		drove = true
	var paid: Array[Object] = []
	# Strict FIFO: only the head can pay, and the moment it cannot, the rest wait behind it.
	# shortcut: costs are paid whole, so a part that fits fires in full. A partial-fire rule needs
	# per-entry remaining costs.
	while not queue.is_empty():
		var head: Dictionary = queue[0]
		# The head's cost is read before popping so a refusal leaves the queue untouched.
		var cost: float = head["cost"]
		# An exact fit pays: energy is only spent when it covers the cost outright.
		if cost > value:
			# The head blocks the line, so stop rather than searching for one that fits.
			break
		queue.pop_front()
		value -= cost
		spent += cost
		paid.append(head["requester"])
	return {"drove": drove, "paid": paid}
