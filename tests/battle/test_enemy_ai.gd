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
	var part := _part_with(ChCatalog.load_default().part(id), ready)
	part.flipped = flipped
	return part


# A part on a hand-built def, so a test can set the fields the catalog's parts do not carry.
func _part_with(def: ChPartDef, ready := true) -> ChPartRuntime:
	var part := ChPartRuntime.new()
	part.def = def
	part.charges_left = -1
	part.cooldown_left = 0.0 if ready else def.cooldown
	# The fields the AI reads, seeded the way the builder seeds them (Task 2).
	part.cost = def.energy_cost
	part.rate = def.energy_per_second
	part.cooldown = def.cooldown
	part.body = FakeBody.new()
	return part


# A weapon def with the given reach and proximity_range, so a test can tell the two fields apart.
func _weapon(reach: float, proximity := 0.0) -> ChPartDef:
	var def := ChPartDef.new()
	def.id = &"test_weapon"
	def.damage = 5
	def.cooldown = 1.0
	def.reach = reach
	def.proximity_range = proximity
	def.charges = -1
	return def


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
	var dx := mace.def.reach + HALF  # measured from the part: reach + target half
	rig.energy.value = cost * ChEnemyAI.PRESS_SHARE
	assert_true(ChEnemyAI.should_press(rig, dx, HALF), "in reach with 60% of the volley presses")
	rig.energy.value = cost * 0.5
	assert_true(not ChEnemyAI.should_press(rig, dx, HALF), "at 50% it waits")
	_complete()


# Task 1: reach() reads ChPartDef.reach, the cells a weapon brings to bear. proximity_range is the
# proximity-chain range and never a weapon's reach, and a cooldown part with no charges left is out.
func test_reach_reads_the_reach_field() -> void:
	var near := _rig([_part_with(_weapon(30.0))], 20.0, 20.0)
	assert_near(ChEnemyAI.reach(near), 30.0, 0.001, "a part with reach 30 gives reach 30")
	var far := _rig([_part_with(_weapon(0.0, 30.0))], 20.0, 20.0)
	assert_true(is_inf(ChEnemyAI.reach(far)), "proximity_range 30 is not a weapon's reach")
	var spent := _part_with(_weapon(30.0))
	spent.charges_left = 0
	assert_true(is_inf(ChEnemyAI.reach(_rig([spent], 20.0, 20.0))), "a spent cooldown part is out of reach")
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
	# A Mace (range 6, 8 cells long) mounted 10 cells off the chassis centre of a hull with half-width
	# 10, target_half 5. Reach is measured from the part's edge (anchor + half its length), so the
	# 6 + 5 = 11 cells are past that edge: 12 past it is out, 6.5 past it is in.
	var mace := _part(&"ice_cream_mace")
	mace.body.global_position = Vector2(10.0, 0.0)
	var rig := _rig([mace], 20.0, 20.0)
	rig.energy.value = float(mace.def.energy_cost)  # below cap, above 60%
	rig.energy.cap = 20.0
	assert_true(not ChEnemyAI.should_press(rig, 26.0, 5.0),
		"12 cells from the part's edge is out of reach, though within range + both halves")
	assert_true(ChEnemyAI.should_press(rig, 20.5, 5.0), "6.5 cells from the edge is inside 6 + 5")
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


# --- Task 3: the held button ----------------------------------------------------------------------
# A continuous part pays energy_per_second for every frame the button is down, so the share is taken of
# that per-second cost rather than a volley's. Reach is measured from the part exactly as should_press
# measures it.
const PER_SECOND := 2.0


# A melee part: continuous by mode, so can_run() is true, with its own per-second price.
func _runner(reach: float, per_second := PER_SECOND) -> ChPartDef:
	var def := _weapon(reach)
	def.mode = ChPartDef.MODE_MELEE
	def.cooldown = 0.0
	def.energy_per_second = per_second
	return def


func test_holds_with_a_melee_part_in_reach() -> void:
	var part := _part_with(_runner(10.0))
	var rig := _rig([part], 20.0, PER_SECOND * ChEnemyAI.HOLD_SHARE)
	var dx := part.def.reach + HALF  # measured from the part: reach + target half
	assert_true(ChEnemyAI.should_hold(rig, dx, HALF),
		"a melee part with the target in reach and half its cost in the pool holds")
	# A second runner out of reach is still priced: the continuous step pays every part that can run.
	var far := _part_with(_runner(2.0))
	far.body.global_position = Vector2(500.0, 0.0)
	rig.parts = [part, far] as Array[ChPartRuntime]
	assert_true(not ChEnemyAI.should_hold(rig, dx, HALF),
		"a runner that cannot reach the target is part of the hold's cost, so the same pool no longer holds")
	rig.energy.value = 2.0 * PER_SECOND * ChEnemyAI.HOLD_SHARE
	assert_true(ChEnemyAI.should_hold(rig, dx, HALF), "and the whole drain in the pool holds")
	_complete()


func test_no_hold_out_of_reach() -> void:
	var rig := _rig([_part_with(_runner(10.0))], 20.0, 20.0)
	assert_true(not ChEnemyAI.should_hold(rig, 100.0, HALF),
		"a full pool holds nothing with no part in reach")
	_complete()


func test_no_hold_below_the_share() -> void:
	var part := _part_with(_runner(10.0))
	var rig := _rig([part], 20.0, PER_SECOND * ChEnemyAI.HOLD_SHARE - 0.01)
	var dx := part.def.reach + HALF
	assert_true(not ChEnemyAI.should_hold(rig, dx, HALF), "a hair under half the per-second cost waits")
	rig.energy.value = PER_SECOND * ChEnemyAI.HOLD_SHARE
	assert_true(ChEnemyAI.should_hold(rig, dx, HALF), "and exactly half holds: the rule is at least")
	_complete()


func test_no_hold_when_the_whole_drain_is_unaffordable() -> void:
	# One runner in reach and one out of it, both of which the continuous step would pay. The pool
	# covers half the in-reach runner's rate but not half the total, so the hold would start and starve.
	var near := _part_with(_runner(10.0))
	var far := _part_with(_runner(10.0))
	far.body.global_position = Vector2(500.0, 0.0)
	var rig := _rig([near, far], 20.0, 1.5 * PER_SECOND * ChEnemyAI.HOLD_SHARE)
	var dx := near.def.reach + HALF
	assert_true(not ChEnemyAI.should_hold(rig, dx, HALF),
		"the bar is the whole can_run() drain, not just the in-reach part's")
	_complete()


func test_no_hold_without_continuous_parts() -> void:
	# A cooldown part is what a press fires; the hold has nothing of its own to keep running.
	var rig := _rig([_part_with(_weapon(10.0))], 20.0, 20.0)
	assert_true(not ChEnemyAI.should_hold(rig, 2.0, HALF), "a cooldown-only rig never holds")
	_complete()
