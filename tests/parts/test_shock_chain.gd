extends ChPartTest

# Task 11: the Shock Chain parts (U14-U19, R07-R09) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The shooters aim at the far rig, and a projectile only flies on engine frames, so those tests pass
# frames = true. The passive and trigger tests are pure clock and stay synchronous.
# A part that reads a status the fight would decay is given it just before the press, so the number
# the row names is the number the hit reads.
# The parts whose behaviour is a stat or gain hook (R07, R09, U18) need ctx.setup_all(), which is
# what caches the modifiers the context folds; duel() only calls each behaviour's setup.

# Every unbroken part of `side` carrying `id`, in mount order.
func _parts_of(ctx: ChBattleContext, side: int, id: StringName) -> Array:
	var out: Array = []
	for part in ctx.chariots[side].parts:
		if part.def != null and part.def.id == id:
			out.append(part)
	return out


# The stacks a holder's own spark gain added, read off the STATUS_GAINED events.
func _spark_amount(gains: Array, holder: Object) -> int:
	var amount := 0
	for event in gains:
		if event.source == holder and event.data.get("cause") == &"sparks":
			amount = int(event.data["amount"])
	return amount


# U14: a straight shot that pays 40 and throws sparks at the part hit, and 1 Speedup when a
# neighbour fires.
func test_tesla_coil_40_damage_and_speedup_when_a_neighbour_fires() -> void:
	var ctx := await duel([[[6], &"battery_dropper"], [[7], &"tesla_coil"]],
		[[[0], &"reinforced_frame"]], 60.0)
	var coil := of(ctx, 0, &"tesla_coil")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(coil != null and foe != null, "both parts mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 8.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	# Read before the frames the bolt needs: a status second would decay the Speedup away.
	assert_eq(coil.statuses.count(ChStatuses.SPEEDUP), 1,
		"the neighbour's fire gave the coil 1 Speedup")
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the coil landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 40, "the coil pays 40")
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "the sparks it threw shocked the part hit")
	_complete()


# U15: a straight shot that pays 30, and the Shock its sparks carry jumps on to a touching part.
func test_chain_lightning_30_damage_and_shock_that_jumps() -> void:
	var ctx := await duel([[[7], &"chain_lightning"]],
		[[[0], &"reinforced_frame"], [[1], &"reinforced_frame"]], 60.0)
	var foes := _parts_of(ctx, 1, &"reinforced_frame")
	assert_eq(foes.size(), 2, "both enemy parts mounted")
	var foe: ChPartRuntime = foes[0]
	var neighbour: ChPartRuntime = foes[1]
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 7.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the bolt landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 30, "the bolt pays 30")
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "the sparks shocked the part hit")
	assert_true(neighbour.statuses.count(ChStatuses.SHOCK) > 0,
		"and the Shock jumped to the part touching it")
	_complete()


# U16: three slow orbs, each 10, each bursting into sparks.
func test_ball_lightning_three_orbs_of_10() -> void:
	var ctx := await duel([[[7], &"ball_lightning"]], [[[7], &"strut"]], 60.0)
	var foe := of(ctx, 1, &"strut")
	assert_true(foe != null, "the enemy strut mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 8.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 90:
		if hits.size() >= 3:
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 3, "all three orbs landed")
	for hit in hits:
		assert_eq(int(hit.data["hp_damage"]), 10, "each orb pays 10")
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "the orbs' sparks shocked the part hit")
	_complete()


# U17: a part within the M range that gains Shock, on either side, gives 1 energy.
func test_capacitor_gains_energy_for_shock_in_range() -> void:
	var ctx := await duel([[[7], &"capacitor"]], [[[7], &"reinforced_frame"]], 60.0)
	var capacitor := of(ctx, 0, &"capacitor")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(capacitor != null and foe != null, "both parts mounted")
	var energy: ChEnergy = ctx.chariots[0].energy
	energy.value = 5.0
	ctx.give_status(foe, ChStatuses.SHOCK, 2)
	assert_eq(energy.value, 6.0, "the enemy part in range gave 1 energy")
	# The same gain past the range pays nothing.
	var far := await duel([[[7], &"capacitor"]], [[[0], &"reinforced_frame"]], 60.0)
	var far_capacitor := of(far, 0, &"capacitor")
	var far_foe := of(far, 1, &"reinforced_frame")
	assert_true(far_capacitor != null and far_foe != null, "the far duel mounted")
	var far_energy: ChEnergy = far.chariots[0].energy
	far_energy.value = 5.0
	far.give_status(far_foe, ChStatuses.SHOCK, 2)
	assert_eq(far_energy.value, 5.0, "and a part past the range gave none")
	_complete()


# U18: sparks give a Wet enemy part double Shock, and a dry one the normal amount.
func test_wet_wire_doubles_shock_from_sparks_on_wet_enemy_parts() -> void:
	var ctx := await duel([[[6], &"wet_wire"], [[7], &"spare_cell"]],
		[[[0], &"reinforced_frame"], [[5], &"reinforced_frame"]], 60.0)
	ctx.setup_all()
	var foes := _parts_of(ctx, 1, &"reinforced_frame")
	assert_eq(foes.size(), 2, "both enemy parts mounted")
	var wet: ChPartRuntime = foes[0]
	var dry: ChPartRuntime = foes[1]
	var gains := sink(ctx, ChEvent.STATUS_GAINED)
	ctx.give_status(wet, ChStatuses.WET, 3)
	ctx.throw_sparks(wet, wet.anchor_world())
	assert_eq(_spark_amount(gains, wet), 4, "a Wet enemy part gained double Shock")
	ctx.throw_sparks(dry, dry.anchor_world())
	assert_eq(_spark_amount(gains, dry), 2, "and a dry one the normal 2")
	_complete()


# U19: the spark runs along the steel under it to the first part it reaches, and a spike with no
# conductor under it shocks nobody.
func test_grounding_spike_runs_a_spark_along_steel() -> void:
	var ctx := await duel([[[7], &"grounding_spike"]], [[[0], &"reinforced_frame"]], 60.0)
	var spike := of(ctx, 0, &"grounding_spike")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(spike != null, "the spike mounted")
	# A steel rail along the floor from under the spike to under the enemy, then up into the hull.
	for x in range(181, 221):
		ctx.world.set_cell(Vector2i(x, 160), &"steel")
	for y in range(145, 161):
		ctx.world.set_cell(Vector2i(220, y), &"steel")
	await step(ctx, 6.1)
	await step(ctx, TICK, true)
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0,
		"the spark ran along the steel to the enemy hull")
	# The same spike over no conductor at all shocks nobody.
	var dry := await duel([[[7], &"grounding_spike"]], [[[0], &"reinforced_frame"]], 60.0)
	var dry_foe: ChChariotRuntime = dry.chariots[1]
	assert_true(of(dry, 0, &"grounding_spike") != null, "the dry duel mounted")
	await step(dry, 6.1)
	await step(dry, TICK, true)
	assert_eq(dry_foe.statuses.count(ChStatuses.SHOCK), 0,
		"and a spike with no conductor under it shocked nobody")
	_complete()


# R07: the Storm Core keeps the enemy's Shock jumping, and the halving ends it. Review Focus 4: six
# packed Wet parts, a 32-Shock gain, and the fight still reaches 10 s.
func test_storm_core_jumps_end() -> void:
	var mounts: Array = []
	for slot in range(6):
		mounts.append([[slot], &"reinforced_frame"])
	var ctx := await duel([[[7], &"storm_core"]], mounts, 60.0)
	ctx.setup_all()
	assert_true(of(ctx, 0, &"storm_core") != null, "the storm core mounted")
	var parts := _parts_of(ctx, 1, &"reinforced_frame")
	assert_eq(parts.size(), 6, "six packed enemy parts mounted")
	for part in parts:
		ctx.give_status(part, ChStatuses.WET, 5)
	ctx.give_status(parts[0], ChStatuses.SHOCK, 32)
	await step(ctx, 10.0)
	assert_true(ctx.time >= 10.0, "the fight reached 10 s")
	# Every hop halves, so the whole cascade is bounded by twice the gain for each part.
	var total := 0
	for part in parts:
		total += part.statuses.count(ChStatuses.SHOCK)
	assert_true(total <= 32 * parts.size() * 2, "the jumping stayed bounded (%d stacks)" % total)
	_complete()


# R08: 150 on the body it meets, a large explosion, and the sparks that spray from it.
func test_lightning_bolt_150_damage_and_a_large_explosion() -> void:
	var ctx := await duel([[[7], &"lightning_bolt"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(foe != null, "the enemy part mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var blasts := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 10.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 90:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the bolt landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 150, "the bolt pays 150")
	assert_eq(blasts.size(), 1, "and it set off one explosion")
	assert_eq(blasts[0].data["size"], &"large", "a large blast")
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "and its sparks shocked the part hit")
	_complete()


# R09: the Superconductor doubles the Shock damage on the enemy side and refuses Shock to its own parts.
func test_superconductor_doubles_enemy_shock_and_refuses_it_on_own_parts() -> void:
	var ctx := await duel([[[6], &"superconductor"], [[7], &"spare_cell"]],
		[[[0], &"reinforced_frame"]], 60.0)
	ctx.setup_all()
	var own := of(ctx, 0, &"spare_cell")
	var foe := of(ctx, 1, &"reinforced_frame")
	var body: ChChariotRuntime = ctx.chariots[0]
	assert_true(own != null and foe != null, "both parts mounted")
	ctx.give_status(own, ChStatuses.SHOCK, 5)
	assert_eq(own.statuses.count(ChStatuses.SHOCK), 0, "an own part cannot gain Shock")
	ctx.give_status(body, ChStatuses.SHOCK, 3)
	ctx.give_status(foe, ChStatuses.SHOCK, 3)
	var hp_before := body.hp
	var integrity_before := foe.integrity
	await step(ctx, 1.1)
	assert_eq(hp_before - body.hp, 3, "the body's 3 Shock dealt 3")
	assert_eq(integrity_before - foe.integrity, 6, "and the enemy's 3 Shock dealt 6")
	_complete()
