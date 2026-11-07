extends ChTest

# Task 5: the energy pool. Pure logic, so no make_world here.
# Requesters are stand-in part runtimes (Task 9 hands the real ones): only identity matters, so
# bare RefCounted instances are enough.
# shortcut: caps/regen/costs are fixed per test below; a suite that tunes them needs a table.


# A pool sitting at `value` of energy, reached through the public API only: a fresh pool starts at
# cap, so a drain request of cap - value pays off on a zero-length tick and leaves `value` behind.
func _pool_at(value: float, cap: float, regen: float, drive_cost: float) -> ChEnergy:
	assert_true(value <= cap, "the helper can only drain, not fill")
	var pool := ChEnergy.new(cap, regen, drive_cost)
	var drain := _requester()
	# The drain is the only queued entry, so nothing else is paid on this tick.
	pool.request(drain, cap - value)
	var result: Dictionary = pool.tick(0.0, false)
	assert_eq(result.paid, [drain], "the drain paid off")
	assert_eq(pool.value, value, "the pool is at the requested value")
	assert_eq(pool.queue_size(), 0, "the drain left the queue")
	return pool


func _requester() -> RefCounted:
	return RefCounted.new()


func test_regen_clamps_to_cap() -> void:
	var pool := _pool_at(0.0, 10.0, 5.0, 2.0)
	var result: Dictionary = pool.tick(10.0, false)
	assert_eq(pool.value, 10.0, "5/s for 10 s stops at cap, not 50")
	assert_eq(result.paid, [], "regen alone pays nobody")
	assert_eq(pool.queue_size(), 0, "no request was queued")
	_complete()


func test_request_paid_immediately_when_affordable() -> void:
	# cap 10, regen 0: the cost has to fit out of the starting value.
	var pool := _pool_at(10.0, 10.0, 0.0, 2.0)
	var requester := _requester()
	pool.request(requester, 4.0)
	assert_eq(pool.queue_size(), 1, "the request is queued")
	var result: Dictionary = pool.tick(1.0, false)
	assert_eq(result.paid, [requester], "an affordable head pays on the tick it is queued")
	assert_eq(pool.value, 6.0, "10 minus the 4 cost")
	assert_eq(pool.queue_size(), 0, "a paid request leaves the queue")
	_complete()


func test_fifo_strict() -> void:
	var pool := _pool_at(0.0, 10.0, 2.0, 2.0)
	# A costs more than B and queued first, so B can only fire after A: a permissive queue would
	# pay B out of 2 energy here.
	var a := _requester()
	var b := _requester()
	pool.request(a, 3.0)
	# A repeat request from A is ignored, so the queue holds exactly A then B.
	# The dedupe rule itself is owned by test_cancel_removes.
	pool.request(a, 3.0)
	pool.request(b, 1.0)
	assert_eq(pool.queue_size(), 2, "A queued once, then B")
	var result: Dictionary = pool.tick(1.0, false)
	assert_eq(result.paid, [], "2 energy cannot pay the 3-cost head")
	assert_eq(pool.value, 2.0, "regen 2/s for 1 s")
	assert_eq(pool.queue_size(), 2, "a blocked head keeps both entries")
	result = pool.tick(0.5, false)
	assert_eq(result.paid, [a], "the head pays the moment it fits")
	assert_eq(pool.value, 0.0, "the 3 cost spent out of 3")
	assert_eq(pool.queue_size(), 1, "B is still waiting")
	result = pool.tick(0.5, false)
	assert_eq(result.paid, [b], "B is paid next")
	assert_eq(pool.queue_size(), 0, "the queue is empty")
	_complete()


func test_driving_paid_first() -> void:
	# 1 energy, driving costs 2/s, one part wants 1: driving has to win the energy.
	var pool := _pool_at(1.0, 10.0, 0.0, 2.0)
	var requester := _requester()
	pool.request(requester, 1.0)
	var result: Dictionary = pool.tick(0.5, true)
	assert_eq(result.drove, true, "1 energy covers 2/s for 0.5 s")
	assert_eq(result.paid, [], "the drive spent it all, so the queued part waits")
	assert_eq(pool.value, 0.0, "1 minus the 1 drive cost")
	assert_eq(pool.queue_size(), 1, "the request is still queued")
	_complete()


func test_drive_ignored_without_energy() -> void:
	# A held direction with no energy and no regen must not stall the pool or grow the queue.
	var pool := _pool_at(0.0, 10.0, 0.0, 2.0)
	var result: Dictionary = pool.tick(1.0, true)
	assert_eq(result.drove, false, "2 energy is not available, so no drive")
	assert_eq(result.paid, [], "nothing was queued to pay")
	assert_eq(pool.value, 0.0, "the failed drive did not spend energy")
	assert_eq(pool.queue_size(), 0, "driving never queues a request")
	_complete()


func test_release_drive_drains_queue_in_order() -> void:
	# Review Focus 2: regen 2/s never beats the 2/s drive cost, so a held direction starves the
	# queued parts forever. Releasing it must fire them in FIFO order.
	var pool := _pool_at(0.0, 4.0, 2.0, 2.0)
	var a := _requester()
	var b := _requester()
	pool.request(a, 3.0)
	pool.request(b, 1.0)
	var result: Dictionary = pool.tick(1.0, true)
	assert_eq(result.drove, true, "the regen paid for the drive")
	assert_eq(result.paid, [], "the drive spent it, so nothing fired")
	assert_eq(pool.value, 0.0, "2 regen minus the 2 drive cost")
	assert_eq(pool.queue_size(), 2, "both parts are still waiting")
	result = pool.tick(3.0, false)
	assert_eq(result.drove, false, "the direction is released")
	assert_eq(result.paid, [a, b], "the released drive drains the queue in FIFO order")
	assert_eq(pool.value, 0.0, "4 energy paid out as 3 plus 1")
	assert_eq(pool.queue_size(), 0, "the queue is empty")
	_complete()


func test_cancel_removes() -> void:
	var pool := _pool_at(2.0, 2.0, 0.0, 2.0)
	var a := _requester()
	var b := _requester()
	pool.request(a, 3.0)
	pool.request(b, 4.0)
	assert_eq(pool.queue_size(), 2, "both queued")
	pool.request(a, 3.0)
	assert_eq(pool.queue_size(), 2, "a requester already queued is ignored")
	pool.cancel(a)
	assert_eq(pool.queue_size(), 1, "cancel removed A")
	pool.cancel(_requester())
	assert_eq(pool.queue_size(), 1, "cancelling a requester that is not queued changes nothing")
	var result: Dictionary = pool.tick(0.0, false)
	assert_eq(result.paid, [], "the head costs 4 out of 2 energy")
	assert_eq(pool.queue_size(), 1, "B is still waiting at the head")
	pool.request(a, 3.0)
	assert_eq(pool.queue_size(), 2, "A re-queues now that the cancel freed it")
	_complete()


func test_spent_counts_drive_and_paid_requests() -> void:
	var pool := ChEnergy.new(10.0, 0.0, 2.0)
	pool.request(_requester(), 3.0)
	pool.tick(0.5, true)  # drive 2/s * 0.5 s = 1, then the request's 3
	assert_near(pool.spent, 4.0, 0.0001, "drive and paid request both count")
	assert_near(pool.value, 6.0, 0.0001)
	_complete()


func test_is_queued_reports_waiting_requester() -> void:
	var pool := ChEnergy.new(1.0, 0.0, 2.0)
	var waiting := _requester()
	pool.request(waiting, 5.0)
	pool.tick(0.0, false)
	assert_true(pool.is_queued(waiting), "unaffordable request waits")
	assert_true(not pool.is_queued(_requester()), "a stranger is not queued")
	_complete()
