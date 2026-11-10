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
	assert_true(not ChEnemyAI.should_press(rig, 1.0, HALF),
		"nothing is ready: a full pool still has nothing to fire")
	_complete()


func test_full_pool_presses() -> void:
	# A ready Rocket facing away and out of reach, but the pool is at cap: sitting on a full pool wastes regen.
	var rig := _rig([_part(&"cutter_rocket", true, true)], 20.0, 20.0)
	assert_true(ChEnemyAI.should_press(rig, 100.0, HALF), "a pool at cap presses")
	_complete()


func test_in_reach_and_enough_energy_presses() -> void:
	var mace := _part(&"ice_cream_mace")
	var rig := _rig([mace], 20.0, 0.0)
	var cost := float(mace.def.energy_cost)
	var dx := mace.def.proximity_range + HALF  # measured from the part: range + target half
	rig.energy.value = cost * ChEnemyAI.PRESS_SHARE
	assert_true(ChEnemyAI.should_press(rig, dx, HALF), "in reach with 60% of the volley presses")
	rig.energy.value = cost * 0.5
	assert_true(not ChEnemyAI.should_press(rig, dx, HALF), "at 50% it waits")
	_complete()


func test_out_of_reach_melee_waits() -> void:
	var rig := _rig([_part(&"ice_cream_mace")], 20.0, 16.0)
	assert_true(not ChEnemyAI.should_press(rig, 100.0, HALF),
		"a Mace 100 cells from its target waits, even at 80% of cap")
	_complete()


func test_ranged_part_counts_in_reach_when_facing() -> void:
	var rocket := _part(&"cutter_rocket")
	var rig := _rig([rocket], 20.0, 20.0)
	rig.energy.value = float(rocket.def.energy_cost) * ChEnemyAI.PRESS_SHARE
	assert_true(ChEnemyAI.should_press(rig, 100.0, HALF), "a Rocket facing the target presses")
	var away := _part(&"cutter_rocket", true, true)
	rig.parts = [away] as Array[ChPartRuntime]
	assert_true(not ChEnemyAI.should_press(rig, 100.0, HALF), "facing away it waits")
	_complete()


func test_reach_is_not_counted_twice_for_an_offset_part() -> void:
	# A Mace (range 6) mounted 10 cells off the chassis centre of a hull with half-width 10, target_half 5.
	# Reach is measured from the part, so it lands up to 6 + 5 = 11 cells away; adding the own half
	# again (the old bug) would call 21 in reach and waste a press.
	var mace := _part(&"ice_cream_mace")
	mace.body.global_position = Vector2(10.0, 0.0)
	var rig := _rig([mace], 20.0, 20.0)
	rig.energy.value = float(mace.def.energy_cost)  # below cap, above 60%
	rig.energy.cap = 20.0
	assert_true(not ChEnemyAI.should_press(rig, 25.0, 5.0),
		"15 cells from the part is out of reach, though within range + both halves")
	assert_true(ChEnemyAI.should_press(rig, 20.5, 5.0), "10.5 cells from the part is inside 6 + 5")
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


# The kiter's band with a melee reach: a Tower (half 11) with a Chainsaw (reach 14) against a Wedge
# (half 17). hold = 14 + 11 + 17 = 42 and the hulls touch at 28, so a back-off edge of
# hold - KITE_BACKOFF (22) sits inside contact and the kiter could never back off. The edge is kept
# outside contact by KITE_MARGIN.
const TOWER_HALF := 11.0
const WEDGE_HALF := 17.0
const SAW_REACH := 14.0


func test_kiter_with_melee_reach_backs_off_short_of_contact() -> void:
	var contact := TOWER_HALF + WEDGE_HALF
	assert_eq(ChEnemyAI.decide(0.0, contact + 1.0, SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), -1.0,
		"a cell outside hull contact is inside the band's back-off edge")
	assert_eq(ChEnemyAI.decide(0.0, -(contact + 1.0), SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), 1.0,
		"and the same on the other side")
	_complete()


func test_kiter_with_melee_reach_band_edges() -> void:
	var hold := SAW_REACH + TOWER_HALF + WEDGE_HALF
	var edge := TOWER_HALF + WEDGE_HALF + ChEnemyAI.KITE_MARGIN
	assert_eq(ChEnemyAI.decide(0.0, edge - 0.5, SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), -1.0,
		"just inside the back-off edge backs off")
	assert_eq(ChEnemyAI.decide(0.0, edge + 0.5, SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), 0.0,
		"just outside it rests")
	assert_eq(ChEnemyAI.decide(0.0, hold, SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), 0.0,
		"at hold it rests")
	assert_eq(ChEnemyAI.decide(0.0, hold + 0.5, SAW_REACH, TOWER_HALF, WEDGE_HALF, &"kiter"), 1.0,
		"past hold it closes")
	_complete()
