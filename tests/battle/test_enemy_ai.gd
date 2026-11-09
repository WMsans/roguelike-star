extends ChTest

# Task 2 (one button): ChEnemyAI.should_press, the enemy's finger. Pure: a hand-built
# ChChariotRuntime with ChPartRuntimes on fake bodies, the way test_part_runtime.gd builds them. The
# rule: press when a ready part has a target in reach and the pool holds PRESS_SHARE (60%) of the
# ready volley's cost, or when the pool is at cap (so it never sits on a full pool).

const HALF := 5.0  # both hulls' half-width in these tests


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


func _part(id: StringName, ready := true, flipped := false) -> ChPartRuntime:
	var part := ChPartRuntime.new()
	part.def = ChCatalog.load_default().part(id)
	part.charges_left = -1
	part.cooldown_left = 0.0 if ready else part.def.cooldown
	part.flipped = flipped
	part.body = FakeBody.new()
	return part


# A chariot with these parts and a pool of `cap` holding `share` of it. Costs are per-part, so the
# share is taken of the ready volley's cost by the caller, who passes `value` directly.
func _rig(parts: Array[ChPartRuntime], cap: float, value: float) -> ChChariotRuntime:
	var rig := ChChariotRuntime.new()
	rig.parts = parts
	rig.energy = ChEnergy.new(cap, 0.0)
	rig.energy.value = value
	return rig


func test_no_ready_parts_never_press() -> void:
	var rig := _rig([_part(&"ice_cream_mace", false), _part(&"cutter_rocket", false)], 20.0, 20.0)
	assert_true(not ChEnemyAI.should_press(rig, 1.0, HALF, HALF),
		"nothing is ready: a full pool still has nothing to fire")
	_complete()


func test_full_pool_presses() -> void:
	# A ready Rocket facing away and out of reach, but the pool is at cap: sitting on a full pool wastes regen.
	var rig := _rig([_part(&"cutter_rocket", true, true)], 20.0, 20.0)
	assert_true(ChEnemyAI.should_press(rig, 100.0, HALF, HALF), "a pool at cap presses")
	_complete()


func test_in_reach_and_enough_energy_presses() -> void:
	var mace := _part(&"ice_cream_mace")
	var rig := _rig([mace], 20.0, 0.0)
	var cost := float(mace.def.energy_cost)
	var dx := mace.def.proximity_range + HALF  # measured from the part: range + target half
	rig.energy.value = cost * ChEnemyAI.PRESS_SHARE
	assert_true(ChEnemyAI.should_press(rig, dx, HALF, HALF), "in reach with 60% of the volley presses")
	rig.energy.value = cost * 0.5
	assert_true(not ChEnemyAI.should_press(rig, dx, HALF, HALF), "at 50% it waits")
	_complete()


func test_out_of_reach_melee_waits() -> void:
	var rig := _rig([_part(&"ice_cream_mace")], 20.0, 16.0)
	assert_true(not ChEnemyAI.should_press(rig, 100.0, HALF, HALF),
		"a Mace 100 cells from its target waits, even at 80% of cap")
	_complete()


func test_ranged_part_counts_in_reach_when_facing() -> void:
	var rocket := _part(&"cutter_rocket")
	var rig := _rig([rocket], 20.0, 20.0)
	rig.energy.value = float(rocket.def.energy_cost) * ChEnemyAI.PRESS_SHARE
	assert_true(ChEnemyAI.should_press(rig, 100.0, HALF, HALF), "a Rocket facing the target presses")
	var away := _part(&"cutter_rocket", true, true)
	rig.parts = [away] as Array[ChPartRuntime]
	assert_true(not ChEnemyAI.should_press(rig, 100.0, HALF, HALF), "facing away it waits")
	_complete()


func test_reach_is_not_counted_twice_for_an_offset_part() -> void:
	# A Mace (range 6) mounted 10 cells off the chassis centre on a hull with own_half 10, target_half 5.
	# Reach is measured from the part, so it lands up to 6 + 5 = 11 cells away; adding own_half again
	# (the old bug) would call 21 in reach and waste a press.
	var mace := _part(&"ice_cream_mace")
	mace.body.global_position = Vector2(10.0, 0.0)
	var rig := _rig([mace], 20.0, 20.0)
	rig.energy.value = float(mace.def.energy_cost)  # below cap, above 60%
	rig.energy.cap = 20.0
	assert_true(not ChEnemyAI.should_press(rig, 25.0, 10.0, 5.0),
		"15 cells from the part is out of reach, though within range + both halves")
	assert_true(ChEnemyAI.should_press(rig, 20.5, 10.0, 5.0), "10.5 cells from the part is inside 6 + 5")
	_complete()


# Task 6: drive styles. Pure decide() calls, no rig needed.
func test_brawler_keeps_pushing() -> void:
	# The hulls overlap at 20 apart (halves 15+15) and it still pushes.
	assert_eq(ChEnemyAI.decide(0.0, 20.0, 6.0, 15.0, 15.0, &"brawler"), 1.0)
	_complete()


func test_kiter_backs_off_inside_reach() -> void:
	assert_eq(ChEnemyAI.decide(0.0, 20.0, 30.0, 10.0, 10.0, &"kiter"), -1.0)
	_complete()


func test_kiter_holds_in_band() -> void:
	assert_eq(ChEnemyAI.decide(0.0, 45.0, 30.0, 10.0, 10.0, &"kiter"), 0.0)
	_complete()


func test_kiter_closes_from_far() -> void:
	assert_eq(ChEnemyAI.decide(0.0, 200.0, 30.0, 10.0, 10.0, &"kiter"), 1.0)
	_complete()


func test_kiter_with_no_reach_holds_still() -> void:
	# INF - KITE_BACKOFF is still INF, so without a guard every finite distance reads "too close".
	assert_eq(ChEnemyAI.decide(0.0, 100.0, INF, 10.0, 10.0, &"kiter"), 0.0)
	_complete()
