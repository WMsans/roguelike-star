extends ChPartTest

# Task 16: the Grinder parts (U31-U36, R15-R17) on the Task 1 RIG, one test per part, each asserting
# the number its row in docs/design-doc/parts-list.md gives.
# Every part here reacts to a neighbour firing, so each test states the firing it needs: a press
# fires the Stinger, holding runs the Chainsaw, and the Meshing Gearbox's forced fire is what the two
# R15 tests measure. The last one is the named Review Focus 4 loop: three Chainsaws and two Gearboxes
# held for 10 s must not hang.

# The hp_damage of every hit `source` dealt, in delivery order.
func _paid(hits: Array, source: Object) -> Array:
	var out: Array = []
	for hit in hits:
		if hit.source == source:
			out.append(int(hit.data["hp_damage"]))
	return out


# The spawn events of `material`, in delivery order.
func _spawned(spawns: Array, material: StringName) -> Array:
	var out: Array = []
	for event in spawns:
		if event.data.get("material") == material:
			out.append(event)
	return out


# The part at a single top slot, for a test that mounts two parts with the same id.
func _at(ctx: ChBattleContext, side: int, slot: int) -> ChPartRuntime:
	for part in ctx.chariots[side].parts:
		if part.path.size() == 1 and part.path[0] == slot:
			return part
	return null


# The STATUS_GAINED events for `status`, in delivery order.
func _gains(gains: Array, status: StringName) -> Array:
	var out: Array = []
	for gain in gains:
		if gain.data.get("status") == status:
			out.append(gain)
	return out


# U31: 12 a tick, and +5 on the next landed tick after a neighbour fires.
func test_buzzsaw_arm_5_more_after_a_neighbour_fires() -> void:
	var ctx := await duel([[[6], &"buzzsaw_arm"], [[7], &"stinger"]], [], 60.0)
	var saw := of(ctx, 0, &"buzzsaw_arm")
	var stinger := of(ctx, 0, &"stinger")
	assert_true(saw != null and stinger != null, "the saw and its neighbour mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 2.1)  # the stinger's own 2 s cooldown, so a press can fire it
	await step(ctx, TICK, false, true)
	await step(ctx, TICK, true, false)  # the stinger fires, which arms the saw's bonus
	await step(ctx, 1.05, false, true)
	await step(ctx, 1.05, false, true)
	assert_eq(_paid(hits, saw), [12, 17, 12], "12 a tick, +5 once, then back to 12")
	_complete()


# U32: a neighbouring melee weapon's firing spawns 1 fire cell on what it hit.
func test_hot_teeth_spawns_a_fire_cell_on_what_the_neighbour_hit() -> void:
	var ctx := await duel([[[6], &"hot_teeth"], [[7], &"chainsaw"]],
		[[[7], &"reinforced_frame"]], 60.0)
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(foe != null, "the enemy part the saw reaches mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, TICK, false, true)
	var fire := _spawned(spawns, &"fire")
	assert_eq(fire.size(), 1, "the saw's firing spawned fire once")
	if fire.size() == 1:
		assert_eq(int(fire[0].data["count"]), 1, "one fire cell")
		assert_true(Vector2(fire[0].data["at"]).distance_to(foe.anchor_world()) < 1.0,
			"on what the saw hit")
	_complete()


# U33: every 4th firing by a neighbouring melee weapon gains 1 energy.
func test_gear_train_gains_1_energy_every_4th_neighbour_fire() -> void:
	var ctx := await duel([[[6], &"gear_train"], [[7], &"chainsaw"]], [], 60.0)
	assert_true(of(ctx, 0, &"gear_train") != null and of(ctx, 0, &"chainsaw") != null,
		"the train and its neighbour mounted")
	# The pool starts full, so an empty one is what makes the gain visible.
	ctx.chariots[0].energy.value = 0.0
	var gains := sink(ctx, ChEvent.ENERGY_GAINED)
	await step(ctx, 3.0, false, true)
	assert_eq(gains.size(), 0, "three firings gain nothing")
	await step(ctx, 1.2, false, true)
	assert_eq(gains.size(), 1, "the fourth gains once")
	if gains.size() == 1:
		assert_eq(int(gains[0].data["amount"]), 1, "1 energy")
	_complete()


# U34: 20 a tick, +2 for every second of unbroken contact, and a tick that finds nothing resets it.
func test_heavy_grinder_ramps_2_a_second_until_contact_breaks() -> void:
	var ctx := await duel([[[7], &"heavy_grinder"]], [], 60.0)
	var grinder := of(ctx, 0, &"heavy_grinder")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(grinder != null, "the grinder mounted")
	# The enemy's wheels go, so the hull is the only body left to measure contact against.
	for wheel in foe.wheels():
		foe.break_part(wheel, ctx)
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, false, true)
	await step(ctx, 1.05, false, true)
	# Contact breaks: the hull is dragged out of the 24-cell reach, so the ticks that follow find
	# nothing and the count resets. A miss leaves the timer at 0, so the first tick after contact
	# returns lands at once, and it is the reset that keeps it at the base 20.
	foe.chassis.global_position.x += 100.0
	await step(ctx, 1.05, false, true)
	foe.chassis.global_position.x -= 100.0
	await step(ctx, 1.05, false, true)
	assert_eq(_paid(hits, grinder), [20, 22, 20, 22], "20 a tick, +2 a second, 20 again after a miss")
	_complete()


# U35: 12 a tick, digs up to hardness 7, and gains 1 Block for every cell dug.
func test_rotary_drill_digs_hardness_7_and_gains_block_per_cell() -> void:
	var ctx := await duel([[[7], &"rotary_drill"]], [], 60.0)
	var drill := of(ctx, 0, &"rotary_drill")
	var foe: ChChariotRuntime = ctx.chariots[1]
	assert_true(drill != null, "the drill mounted")
	# Steel is hardness 7 and obsidian 8, so the tip takes the steel wall and leaves the obsidian one.
	var steel_rect := Rect2i(200, 130, 9, 12)
	var obsidian_rect := Rect2i(209, 130, 9, 12)
	ctx.world.fill_rect(steel_rect, &"steel")
	ctx.world.fill_rect(obsidian_rect, &"obsidian")
	var steel := int(ctx.world.count_materials(steel_rect).get(&"steel", 0))
	var obsidian := int(ctx.world.count_materials(obsidian_rect).get(&"obsidian", 0))
	var dug := sink(ctx, ChEvent.CELLS_DUG)
	var hits := sink(ctx, ChEvent.HIT)
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 12, "one tick of the drill pays 12")
	assert_eq(_paid(hits, drill), [12], "from the drill itself")
	assert_eq(dug.size(), 1, "the tip dug once")
	if dug.size() == 1:
		var cells := int(dug[0].data["count"])
		assert_true(cells > 0, "and took cells out")
		assert_eq(drill.statuses.count(ChStatuses.BLOCK), cells, "1 Block for every cell dug")
	assert_true(int(ctx.world.count_materials(steel_rect).get(&"steel", 0)) < steel,
		"the hardness-7 steel is dug")
	assert_eq(int(ctx.world.count_materials(obsidian_rect).get(&"obsidian", 0)), obsidian,
		"the hardness-8 obsidian is not")
	_complete()


# U36: every 10th firing by a neighbouring melee weapon gives that weapon 3 Speedup.
func test_overdrive_clutch_gives_3_speedup_on_the_10th_fire() -> void:
	var ctx := await duel([[[6], &"overdrive_clutch"], [[7], &"chainsaw"]], [], 60.0)
	var saw := of(ctx, 0, &"chainsaw")
	assert_true(saw != null and of(ctx, 0, &"overdrive_clutch") != null, "the clutch and its neighbour")
	var gains := sink(ctx, ChEvent.STATUS_GAINED)
	await step(ctx, 9.0, false, true)
	assert_eq(_gains(gains, ChStatuses.SPEEDUP).size(), 0, "nine firings give nothing")
	await step(ctx, 1.2, false, true)
	var speedups := _gains(gains, ChStatuses.SPEEDUP)
	assert_eq(speedups.size(), 1, "the tenth gives Speedup once")
	if speedups.size() == 1:
		assert_eq(int(speedups[0].data["amount"]), 3, "3 Speedup")
		assert_true(speedups[0].source == saw, "to the weapon that fired")
	_complete()


# R15: a melee neighbour's firing makes every other melee neighbour fire, free and off its own clock.
func test_meshing_gearbox_fires_the_other_melee_neighbour() -> void:
	var ctx := await duel([[[5], &"chainsaw"], [[6], &"meshing_gearbox"], [[7], &"stinger"]],
		[], 60.0)
	var gearbox := of(ctx, 0, &"meshing_gearbox")
	var stinger := of(ctx, 0, &"stinger")
	assert_true(gearbox != null and stinger != null and of(ctx, 0, &"chainsaw") != null,
		"the saw, the gearbox and the stinger mounted")
	# The stinger is not ready, so only a forced fire can make it stab.
	stinger.cooldown_left = 99.0
	var hits := sink(ctx, ChEvent.HIT)
	var fired := sink(ctx, ChEvent.PART_FIRED)
	await step(ctx, TICK, false, true)
	assert_eq(_paid(hits, stinger), [25], "the gearbox fired the stinger")
	# A volley's fire would reset the cooldown to the def's 2 s; a forced one leaves it where it was
	# (counted down by the tick, so it is a hair under the 99 set here).
	assert_true(stinger.cooldown_left > 98.0, "and left its cooldown alone")
	var forced := 0
	for event in fired:
		if event.source == stinger and bool(event.data.get("forced", false)):
			forced += 1
	assert_eq(forced, 1, "the stinger's stab was a forced fire")
	_complete()


# R15: each weapon is forced at most once per ctx.time value, so two neighbours firing in the same
# tick do not make the third weapon fire twice.
func test_meshing_gearbox_forces_a_weapon_once_a_tick() -> void:
	var ctx := await duel([[[4], &"stinger"], [[5], &"chainsaw"], [[6], &"meshing_gearbox"],
		[[7], &"stinger"]], [], 60.0)
	var other := _at(ctx, 0, 7)
	assert_true(other != null, "the far stinger mounted")
	if other == null:
		_complete()
		return
	# The far stinger is not ready, so only the gearbox can fire it.
	other.cooldown_left = 99.0
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, true, true)  # the press fires one stinger, the hold ticks the saw
	assert_eq(_paid(hits, other), [25], "two firings in one tick force the stinger once")
	_complete()


# Review Focus 4: three Chainsaws and two Gearboxes, held for 10 s. Each saw's firing forces the
# others, and each forced firing is itself a PART_FIRED, so the chain must end on its own (a forced
# firing starts no new chain) and the fight must reach 10 s rather than hang.
func test_meshing_gearbox_loop_ends() -> void:
	var ctx := await duel([[[3], &"chainsaw"], [[4], &"meshing_gearbox"], [[5], &"chainsaw"],
		[[6], &"meshing_gearbox"], [[7], &"chainsaw"]], [], 40.0)
	var hits := sink(ctx, ChEvent.HIT)
	var fired := sink(ctx, ChEvent.PART_FIRED)
	await step(ctx, 10.0, false, true)
	assert_true(ctx.time >= 10.0, "the fight reached 10 s")
	assert_true(hits.size() >= 3, "every saw fired")
	var forced := 0
	for event in fired:
		if bool(event.data.get("forced", false)):
			forced += 1
	assert_true(forced > 0, "and the gearboxes forced the other saws")
	_complete()


# R16: 15 a tick, +1 for every tick it has landed this battle.
func test_bloodsaw_15_plus_its_landed_ticks() -> void:
	var ctx := await duel([[[7], &"bloodsaw"]], [], 60.0)
	var saw := of(ctx, 0, &"bloodsaw")
	assert_true(saw != null, "the saw mounted")
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, TICK, false, true)
	await step(ctx, 1.05, false, true)
	assert_eq(_paid(hits, saw), [15, 16], "15 on the first tick, 16 on the second")
	_complete()


# R17: a neighbouring melee weapon pays no energy a second.
func test_grinding_engine_makes_melee_neighbours_free() -> void:
	var ctx := await duel([[[6], &"grinding_engine"], [[7], &"chainsaw"], [[5], &"laser"]], [], 60.0)
	# The stat hook is folded from the modifiers setup_all caches; a beam neighbour keeps its rate.
	ctx.setup_all()
	await step(ctx, 1.0, false, true)
	assert_eq(of(ctx, 0, &"chainsaw").rate, 0.0, "the melee neighbour costs nothing a second")
	assert_eq(of(ctx, 0, &"laser").rate, 3.0, "a beam neighbour keeps its 3 a second")
	# Only the beam paid: the saw's 0 rate was spent as nothing.
	assert_near(ctx.chariots[0].energy.spent, 3.0, 0.01, "a second of both held parts spends 3 only")
	_complete()
