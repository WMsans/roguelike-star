extends ChPartTest

# Task 8: the Inferno parts (U01-U06, R01-R03) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn, the shooters aim at the far rig, and a
# projectile only flies on engine frames, so those tests pass frames = true. The passive and trigger
# tests are pure clock and stay synchronous.
# A part that reads a status the fight would decay is given it just before the press, so the number
# the row names is the number the hit reads.

func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))


# U01: a straight shot that lays oil on the body it meets and under it.
func test_oil_sprayer_spawns_oil_on_and_under_the_enemy() -> void:
	var ctx := await duel([[[7], &"oil_sprayer"]], [], 95.0)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 5.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	var drops: Array = []
	for event in spawns:
		if event.data.get("material") == &"oil":
			drops.append(event)
	assert_eq(drops.size(), 2, "the sprayer laid two patches of oil")
	assert_true(drops[0].data["at"].y < drops[1].data["at"].y, "one on the body hit and one under it")
	assert_true(_count(ctx, &"oil", Rect2i(190, 120, 120, 60)) > 0, "and the oil is in the world")
	_complete()


# U02: a neighbour's fire cells come with oil cells of the same count (the C18 Igniter bridge).
func test_fuel_line_with_igniter_spawns_oil() -> void:
	var ctx := await duel([[[5], &"fuel_line"], [[6], &"igniter"]], [], 60.0)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 3.1)
	await step(ctx, TICK, true)
	var oil := 0
	for event in spawns:
		if event.data.get("material") == &"oil":
			oil += int(event.data["count"])
	assert_eq(oil, 8, "the neighbour's 8 fire cells came with 8 oil cells")
	assert_eq(_count(ctx, &"oil", Rect2i(176, 128, 16, 16)), 8, "and the oil is in the world")
	_complete()


# U03: while it burns, it turns its own Flame into Block once a second.
func test_heat_shield_gains_block_equal_to_its_flame() -> void:
	var ctx := await duel([[[7], &"heat_shield"]], [], 60.0)
	var shield := of(ctx, 0, &"heat_shield")
	assert_true(shield != null, "the shield mounted")
	ctx.give_status(shield, ChStatuses.FLAME, 5)
	await step(ctx, 1.1)
	assert_true(shield.statuses.count(ChStatuses.BLOCK) > 0, "it gained Block while it burned")
	assert_eq(shield.statuses.count(ChStatuses.BLOCK), shield.statuses.count(ChStatuses.FLAME),
		"Block equal to its Flame")
	_complete()


# U04: a straight shot that pays 5 for every Flame on the part it hits, or on the body for a hull hit.
# The part-hit shot is fired from a Strut's extension, one cell above the hull's top edge, so it
# meets the part mounted on the enemy's own Strut rather than the hull behind it.
func test_incinerator_5_damage_per_flame() -> void:
	var ctx := await duel([[[6], &"strut"], [[6, 0], &"incinerator"]],
		[[[0], &"strut"], [[0, 0], &"reinforced_frame"]], 60.0)
	var foe_part := of(ctx, 1, &"reinforced_frame")
	assert_true(foe_part != null, "the part on the enemy's strut mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 6.1, false, false, 0.0, true)
	ctx.give_status(foe_part, ChStatuses.FLAME, 4)
	await step(ctx, TICK, true, false, 0.0, true)
	# The shell flies on engine frames, and the Flame it reads must still be the 4 it was given, so
	# the wait is one tick at a time and stops at the hit rather than sleeping past the next second.
	for _frame in 50:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the shell landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 20, "5 for each of the 4 Flame on the part hit")
	var hull := await duel([[[7], &"incinerator"]], [], 60.0)
	var foe: ChChariotRuntime = hull.chariots[1]
	var hull_hits := sink(hull, ChEvent.HIT)
	await step(hull, 6.1, false, false, 0.0, true)
	hull.give_status(foe, ChStatuses.FLAME, 2)
	await step(hull, TICK, true, false, 0.0, true)
	for _frame in 50:
		if not hull_hits.is_empty():
			break
		await step(hull, TICK, false, false, 0.0, true)
	assert_eq(hull_hits.size(), 1, "the shell landed on the hull once")
	assert_eq(int(hull_hits[0].data["hp_damage"]), 10, "and read the body's 2 Flame")
	_complete()


# U05: a lob that pays 30, then oils the landing spot and lights it.
func test_napalm_launcher_30_damage_oil_then_fire() -> void:
	var ctx := await duel([[[7], &"napalm_launcher"]], [], 95.0)
	var hits := sink(ctx, ChEvent.HIT)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 7.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 4.5, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the shell landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 30, "the shell pays 30 where it lands")
	var first_oil := -1
	var first_fire := -1
	for i in spawns.size():
		var material: StringName = spawns[i].data.get("material")
		if material == &"oil" and first_oil < 0:
			first_oil = i
		elif material == &"fire" and first_fire < 0:
			first_fire = i
	assert_true(first_oil >= 0, "it splashed oil")
	assert_true(first_fire > first_oil, "and then lit it")
	assert_true(_count(ctx, &"fire", Rect2i(180, 120, 80, 40)) > 0, "leaving a patch of burning oil")
	_complete()


# U06: a neighbour's fire cells give every neighbour 1 Speedup.
func test_bellows_speeds_its_neighbours() -> void:
	var ctx := await duel([[[5], &"bellows"], [[6], &"igniter"], [[7], &"spare_cell"]], [], 60.0)
	var igniter := of(ctx, 0, &"igniter")
	var spare := of(ctx, 0, &"spare_cell")
	assert_true(igniter != null and spare != null, "both neighbours mounted")
	await step(ctx, 3.1)
	await step(ctx, TICK, true)
	assert_eq(igniter.statuses.count(ChStatuses.SPEEDUP), 1, "the neighbour that lit the fire gained 1 Speedup")
	assert_eq(spare.statuses.count(ChStatuses.SPEEDUP), 1, "and so did the other neighbour")
	_complete()


# R01: every enemy part with Flame bursts into fire cells, 2 per Flame, capped at 40 a part.
func test_inferno_core_2_fire_cells_per_flame_capped_at_40() -> void:
	var ctx := await duel([[[7], &"inferno_core"]],
		[[[0], &"reinforced_frame"], [[1], &"spare_cell"]], 60.0)
	var burning := of(ctx, 1, &"reinforced_frame")
	var blazing := of(ctx, 1, &"spare_cell")
	assert_true(burning != null and blazing != null, "both enemy parts mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 10.1)
	ctx.give_status(burning, ChStatuses.FLAME, 3)
	ctx.give_status(blazing, ChStatuses.FLAME, 30)
	await step(ctx, TICK, true)
	var counts: Array = []
	for event in spawns:
		if event.data.get("material") == &"fire":
			counts.append(int(event.data["count"]))
	counts.sort()
	assert_eq(counts.size(), 2, "both burning parts burst")
	assert_eq(counts[0], 6, "3 Flame gave 6 cells")
	assert_eq(counts[1], 40, "and 30 Flame was capped at 40")
	_complete()


# R02: an enemy part with Oil keeps its Flame.
func test_eternal_flame_stops_flame_decay_on_oiled_parts() -> void:
	var ctx := await duel([[[7], &"eternal_flame"]],
		[[[0], &"reinforced_frame"], [[2], &"spare_cell"]], 60.0)
	var oiled := of(ctx, 1, &"reinforced_frame")
	# Two slots on, so the Oil the oiled part drips does not reach the dry one's sample.
	var dry := of(ctx, 1, &"spare_cell")
	assert_true(oiled != null and dry != null, "both enemy parts mounted")
	ctx.setup_all()
	ctx.give_status(oiled, ChStatuses.FLAME, 5)
	ctx.give_status(oiled, ChStatuses.OIL, 5)
	ctx.give_status(dry, ChStatuses.FLAME, 5)
	await step(ctx, 2.1)
	assert_eq(oiled.statuses.count(ChStatuses.FLAME), 5, "the oiled part kept its Flame")
	assert_eq(dry.statuses.count(ChStatuses.FLAME), 3, "and the dry one lost 1 a second")
	_complete()


# R03: damage to the enemy body equal to the enemy's Flame.
func test_pyre_damage_equals_the_enemys_flame() -> void:
	var ctx := await duel([[[6], &"pyre"]], [[[0], &"spare_cell"]], 20.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var part := of(ctx, 1, &"spare_cell")
	assert_true(part != null, "the enemy part mounted")
	await step(ctx, 5.1)
	ctx.give_status(foe, ChStatuses.FLAME, 4)
	ctx.give_status(part, ChStatuses.FLAME, 3)
	var before := foe.hp
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 7, "the enemy's 7 Flame is the damage")
	_complete()