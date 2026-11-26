extends ChTest

# Task 5: the energy pool. Pure logic, so no make_world here.
# The pool holds no queue: try_pay is the only way a part buys its cost, one whole payment at a time.
# shortcut: caps/regen/costs are fixed per test below; a suite that tunes them needs a table.


# A pool sitting at `value` of energy, reached through the public API only: a fresh pool starts at
# cap, so paying cap - value leaves `value` behind.
func _pool_at(value: float, cap: float, regen: float, drive_cost: float) -> ChEnergy:
	assert_true(value <= cap, "the helper can only drain, not fill")
	var pool := ChEnergy.new(cap, regen, drive_cost)
	assert_true(pool.try_pay(cap - value), "the drain paid off")
	assert_eq(pool.value, value, "the pool is at the requested value")
	return pool


func test_regen_clamps_to_cap() -> void:
	var pool := _pool_at(0.0, 10.0, 5.0, 2.0)
	var result: Dictionary = pool.tick(10.0, false)
	assert_eq(pool.value, 10.0, "5/s for 10 s stops at cap, not 50")
	assert_eq(result.drove, false, "regen alone drives nothing")
	_complete()


func test_try_pay_spends_only_when_it_fits() -> void:
	var pool := _pool_at(5.0, 10.0, 0.0, 2.0)
	assert_true(pool.try_pay(4.0), "4 fits in 5")
	assert_eq(pool.value, 1.0, "5 minus 4")
	assert_true(not (pool.try_pay(2.0)), "2 does not fit in 1")
	assert_eq(pool.value, 1.0, "a refused payment spends nothing")
	assert_eq(pool.spent, 9.0, "the drain's 5 plus the 4 paid")
	_complete()


func test_driving_paid_first() -> void:
	# 1 energy, driving costs 2/s: the drive takes it, so a payment after the tick no longer fits.
	var pool := _pool_at(1.0, 10.0, 0.0, 2.0)
	var result: Dictionary = pool.tick(0.5, true)
	assert_eq(result.drove, true, "1 energy covers 2/s for 0.5 s")
	assert_eq(pool.value, 0.0, "1 minus the 1 drive cost")
	assert_true(not (pool.try_pay(1.0)), "the drive spent it all")
	_complete()


func test_drive_ignored_without_energy() -> void:
	# A held direction with no energy and no regen must not stall the pool or go into debt.
	var pool := _pool_at(0.0, 10.0, 0.0, 2.0)
	var result: Dictionary = pool.tick(1.0, true)
	assert_eq(result.drove, false, "2 energy is not available, so no drive")
	assert_eq(pool.value, 0.0, "the failed drive did not spend energy")
	_complete()


func test_spent_counts_drive_and_paid_requests() -> void:
	var pool := ChEnergy.new(10.0, 0.0, 2.0)
	pool.tick(0.5, true)  # drive 2/s * 0.5 s = 1
	assert_true(pool.try_pay(3.0), "then a payment of 3")
	assert_near(pool.spent, 4.0, 0.0001, "drive and payment both count")
	assert_near(pool.value, 6.0, 0.0001)
	_complete()
