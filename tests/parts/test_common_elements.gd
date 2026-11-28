extends ChPartTest

# Task 6: the common elemental and support parts (C16-C35) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The cell parts (fire, frost, water, acid, smoke) are asserted on the status the cells give the body
# they land on, within two status seconds; the shooters aim at the far rig, whose hull is what a
# straight shot meets, and the cells land on that body.
# A projectile only flies on engine frames, so those tests pass frames = true; the melee, passive and
# wind tests are pure geometry and stay synchronous.

func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))


# C16: a beam, 4 a second, and the fire it sprays along the beam sets the body it reaches alight.
func test_flamethrower_4_damage_per_second_and_fire() -> void:
	var ctx := await duel([[[7], &"flamethrower"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 4, "the first tick of the beam pays 4")
	await step(ctx, 2.0, false, true)
	assert_true(before - foe.hp >= 12, "and it keeps paying 4 a second while held")
	assert_true(foe.statuses.count(ChStatuses.FLAME) > 0, "the fire it sprayed set the body alight")
	_complete()


# C17: a lobbed bottle, 30 on the body it meets, and a patch of fire where it lands.
func test_molotov_30_damage_and_a_fire_patch() -> void:
	var ctx := await duel([[[7], &"molotov"]], [], 95.0)
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 6.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 4.5, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the bottle landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 30, "the bottle pays 30 where it lands")
	assert_true(_count(ctx, &"fire", Rect2i(180, 120, 80, 40)) > 0, "and it burst into fire")
	_complete()


# C18: a small patch of fire 8 cells ahead, and a neighbour's fire cells are doubled.
func test_igniter_spawns_fire_and_doubles_a_neighbour() -> void:
	var ctx := await duel([[[6], &"igniter"], [[7], &"spare_cell"]], [], 60.0)
	await step(ctx, 3.1)
	await step(ctx, TICK, true)
	assert_eq(_count(ctx, &"fire", Rect2i(176, 128, 16, 16)), 8, "8 fire cells ahead of it")
	var neighbour := of(ctx, 0, &"spare_cell")
	var igniter := of(ctx, 0, &"igniter")
	assert_true(neighbour != null and igniter != null, "both parts mounted")
	assert_eq(igniter.behaviour.modify_stat(ctx, neighbour, &"spawn_fire", 4), 8,
		"a neighbour's spawn_fire is doubled")
	assert_eq(igniter.behaviour.modify_stat(ctx, igniter, &"spawn_fire", 4), 4,
		"and its own is not")
	_complete()


# C19: 15, and frost cells over the body hit freeze it.
func test_frost_sprayer_15_damage_and_freeze() -> void:
	var ctx := await duel([[[7], &"frost_sprayer"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 4.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the spray landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 15, "the spray pays 15 on the body it meets")
	assert_true(foe.statuses.count(ChStatuses.FREEZE) > 0, "the frost cells froze the body hit")
	_complete()


# C20: 10, the enemy shoved back, and water cells that soak it.
func test_water_cannon_10_damage_pushes_and_soaks() -> void:
	var ctx := await duel([[[7], &"water_cannon"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	var foe_x := foe.chassis.global_position.x
	await step(ctx, 4.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the jet landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 10, "the jet pays 10")
	assert_true(foe.chassis.global_position.x > foe_x, "and it shoved the enemy back")
	assert_true(foe.statuses.count(ChStatuses.WET) > 0, "the water it spawned soaked the enemy")
	_complete()


# C21: 20, or 40 when the struck holder is frozen.
func test_ice_pick_20_or_40_on_a_frozen_holder() -> void:
	var ctx := await duel([[[7], &"ice_pick"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 2.1)
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 20, "the pick pays 20 on a warm hull")
	var frozen := await duel([[[7], &"ice_pick"]], [], 60.0)
	var frozen_foe: ChChariotRuntime = frozen.chariots[1]
	var frozen_before := frozen_foe.hp
	await step(frozen, 2.1)
	frozen.give_status(frozen_foe, ChStatuses.FREEZE, 1)
	await step(frozen, TICK, true)
	assert_eq(frozen_before - frozen_foe.hp, 40, "and 40 on a frozen one")
	_complete()


# C22: 15, and the sparks it throws shock the body hit.
func test_zap_gun_15_damage_and_shock() -> void:
	var ctx := await duel([[[7], &"zap_gun"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 3.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the gun landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 15, "the gun pays 15")
	assert_true(foe.statuses.count(ChStatuses.SHOCK) > 0, "the sparks it threw shocked the body hit")
	_complete()


# C23: a 4x4 battery block on the first solid surface 10 cells ahead.
func test_battery_dropper_16_cells_on_the_ground() -> void:
	var ctx := await duel([[[7], &"battery_dropper"]], [], 60.0)
	await step(ctx, 8.1)
	await step(ctx, TICK, true)
	assert_eq(_count(ctx, &"battery", Rect2i(175, 140, 40, 30)), 16,
		"a 4x4 block of battery on the floor ahead")
	_complete()


# C24: sparks meant for a neighbour are drawn to the Rod instead.
func test_lightning_rod_takes_the_sparks() -> void:
	var ctx := await duel([[[6], &"lightning_rod"], [[7], &"spare_cell"]], [], 60.0)
	var rod := of(ctx, 0, &"lightning_rod")
	var neighbour := of(ctx, 0, &"spare_cell")
	assert_true(rod != null and neighbour != null, "both parts mounted")
	ctx.setup_all()
	var gains := sink(ctx, ChEvent.STATUS_GAINED)
	ctx.throw_sparks(neighbour, neighbour.anchor_world())
	assert_true(rod.statuses.count(ChStatuses.SHOCK) > 0, "the Rod holds the Shock")
	var direct := 0
	for gain in gains:
		if gain.source == neighbour and gain.data["cause"] == &"sparks":
			direct += 1
	assert_eq(direct, 0, "and the neighbour took no sparks of its own")
	_complete()


# C25: 10, and acid cells on the body hit eat into it.
func test_acid_squirter_10_damage_and_acid() -> void:
	var ctx := await duel([[[7], &"acid_squirter"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 4.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the squirter landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 10, "the squirter pays 10")
	assert_true(foe.statuses.count(ChStatuses.ACID) > 0, "the acid cells ate into the body hit")
	_complete()


# C26: 3 acid cells under the hull's bottom centre every 2 seconds.
func test_acid_dripper_drips_every_two_seconds() -> void:
	var ctx := await duel([[[7], &"acid_dripper"]], [], 60.0)
	await step(ctx, 2.1)
	assert_eq(_count(ctx, &"acid", Rect2i(150, 140, 40, 25)), 3, "one drip of 3 cells")
	await step(ctx, 2.0)
	assert_eq(_count(ctx, &"acid", Rect2i(150, 140, 40, 25)), 6, "and a second after 2 s")
	_complete()


# C27: a lit stick that explodes (small) for 50 after 2 seconds.
func test_dynamite_50_damage_after_two_seconds() -> void:
	var ctx := await duel([[[7], &"dynamite_toss"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	var blasts := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 6.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 4.0, false, false, 0.0, true)
	await step(ctx, 1.0, false, false, 0.0, true)
	assert_eq(blasts.size(), 0, "the fuse is still burning after 1 s")
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_eq(blasts.size(), 1, "and it exploded once the 2 s ran out")
	assert_eq(before - foe.hp, 50, "the small blast paid 50")
	_complete()


# Review Focus 3: the fuse belongs to the fight, so a Toss broken mid-fuse still explodes.
func test_dynamite_outlives_its_thrower() -> void:
	var ctx := await duel([[[7], &"dynamite_toss"]], [], 95.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var toss := of(ctx, 0, &"dynamite_toss")
	var blasts := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 6.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 4.5, false, false, 0.0, true)
	ctx.chariots[0].break_part(toss, ctx)
	assert_true(toss.broken, "the Toss broke mid-fuse")
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(blasts.size(), 1, "the explosion still came without its thrower")
	assert_true(foe.hp < foe.max_hp, "and it still hurt the enemy")
	_complete()


# C28: a 12-cell line of gunpowder on the surface in front.
func test_gunpowder_hopper_12_cells_in_front() -> void:
	var ctx := await duel([[[7], &"gunpowder_hopper"]], [], 60.0)
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_eq(_count(ctx, &"gunpowder", Rect2i(175, 125, 40, 40)), 12,
		"a line of 12 gunpowder cells on the surface ahead")
	_complete()


# C29: 20 Block at the start, and 10 more when an explosion lands within 30 cells.
func test_sandbag_20_block_and_10_near_a_blast() -> void:
	var ctx := await duel([[[7], &"sandbag"]], [], 60.0)
	var bag := of(ctx, 0, &"sandbag")
	await step(ctx, TICK)
	assert_eq(bag.statuses.count(ChStatuses.BLOCK), 20, "20 Block as the battle opens")
	ctx.explode(bag, Vector2i(190, 140), &"small", 0, 2)
	assert_eq(bag.statuses.count(ChStatuses.BLOCK), 30, "and 10 more for a blast within 30 cells")
	ctx.explode(bag, Vector2i(400, 140), &"small", 0, 2)
	assert_eq(bag.statuses.count(ChStatuses.BLOCK), 30, "but nothing for one further out")
	_complete()


# C30: a beam that only blows the gases in front of it, and never hits.
func test_fan_blows_gas_forward_without_hitting() -> void:
	var ctx := await duel([[[7], &"fan"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	var fired := sink(ctx, ChEvent.PART_FIRED)
	ctx.world.set_cell(Vector2i(200, 135), &"smoke")
	await step(ctx, TICK, false, true)
	assert_eq(ctx.world.get_material_at(Vector2i(200, 135)), &"air", "the fan moved the smoke off its cell")
	assert_eq(ctx.world.get_material_at(Vector2i(202, 135)), &"smoke", "two cells forward")
	assert_eq(before - foe.hp, 0, "the fan never hits")
	assert_eq(fired.size(), 1, "its only PART_FIRED is switching on")
	_complete()


# C31: a cloud of 30 smoke cells 6 cells ahead, and the Slow it gives.
func test_smoke_bomb_30_cells_and_slow() -> void:
	var ctx := await duel([[[7], &"smoke_bomb"]], [], 40.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	await step(ctx, 6.1)
	await step(ctx, TICK, true)
	await step(ctx, 2.0)
	assert_eq(_count(ctx, &"smoke", Rect2i(175, 120, 40, 40)), 30, "a cloud of 30 smoke cells ahead")
	assert_true(foe.statuses.count(ChStatuses.SLOW) > 0, "and the smoke slowed the enemy")
	_complete()


# C32: neighbours gain 1 Speedup.
func test_turbo_booster_speeds_its_neighbours() -> void:
	var ctx := await duel([[[6], &"turbo_booster"], [[7], &"spare_cell"]], [], 60.0)
	var neighbour := of(ctx, 0, &"spare_cell")
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_eq(neighbour.statuses.count(ChStatuses.SPEEDUP), 1, "the neighbour gained 1 Speedup")
	_complete()


# C33: 10 damage, and every own weapon gains +2 damage for the battle.
func test_targeting_computer_10_damage_and_weapon_bonus() -> void:
	var ctx := await duel([[[6], &"targeting_computer"], [[7], &"chainsaw"]], [], 20.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var saw := of(ctx, 0, &"chainsaw")
	var before := foe.hp
	await step(ctx, 5.1)
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 10, "the computer pays 10")
	assert_eq(saw.bonus_damage, 2, "and the weapon behind it gained 2 damage")
	_complete()


# C34: a melee-tagged neighbour's hit gets +3.
func test_sharpener_3_more_on_a_melee_neighbour() -> void:
	var ctx := await duel([[[6], &"sharpener"], [[7], &"chainsaw"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 18, "the saw's 15 plus the Sharpener's 3")
	_complete()


# C35: the weapon in front deals +20 and costs +1 energy (or +1 per second when it is continuous).
func test_heavy_rounds_20_more_and_1_more_energy() -> void:
	var ctx := await duel([[[6], &"heavy_rounds"], [[7], &"minigun"]], [], 60.0)
	ctx.setup_all()
	var gun := of(ctx, 0, &"minigun")
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK)
	assert_eq(gun.cost, 2, "the gun in front costs 1 more")
	await step(ctx, 0.6, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_eq(before - foe.hp, 26, "and its hit deals 20 more")
	var beam := await duel([[[6], &"heavy_rounds"], [[7], &"laser"]], [], 60.0)
	beam.setup_all()
	await step(beam, TICK)
	assert_eq(of(beam, 0, &"laser").rate, 4.0, "a continuous weapon in front costs 1 more a second")
	_complete()
