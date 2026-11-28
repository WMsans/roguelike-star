extends ChPartTest

# Task 12: the Acid Eater parts (U20-U24, R10-R11) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn, the shooters aim at the far rig, and a
# projectile only flies on engine frames, so those tests pass frames = true. The melee trigger and
# the stat hook tests are pure clock and stay synchronous.
# A part whose behaviour is a stat hook (R10) needs ctx.setup_all(), which is what caches the
# modifiers the context folds; duel() only calls each behaviour's setup.

func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))


func _spawned(spawns: Array, material: StringName) -> Array:
	var out: Array = []
	for event in spawns:
		if event.data.get("material") == material:
			out.append(event)
	return out


# U20: a straight shot that pays 20 and splashes acid cells over the part hit.
func test_acid_cannon_20_damage_and_acid() -> void:
	var ctx := await duel([[[7], &"acid_cannon"]], [[[0], &"reinforced_frame"]], 60.0)
	var hits := sink(ctx, ChEvent.HIT)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 6.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 60:
		if not hits.is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	assert_eq(hits.size(), 1, "the cannon landed once")
	assert_eq(int(hits[0].data["hp_damage"]), 20, "the cannon pays 20")
	var acid := _spawned(spawns, &"acid")
	assert_eq(acid.size(), 1, "it splashed acid once")
	assert_eq(int(acid[0].data["count"]), 8, "8 acid cells over the part hit")
	_complete()


# U21: a neighbouring melee weapon's tick drips one acid cell on what it hit.
func test_corroder_drips_acid_on_a_melee_neighbours_hit() -> void:
	var ctx := await duel([[[6], &"corroder"], [[7], &"chainsaw"]],
		[[[7], &"reinforced_frame"]], 60.0)
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(foe != null, "the enemy part the saw reaches mounted")
	var hits := sink(ctx, ChEvent.HIT)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, TICK, false, true)
	assert_eq(hits.size(), 1, "the saw ticked once")
	var acid := _spawned(spawns, &"acid")
	assert_eq(acid.size(), 1, "the corroder dripped once")
	assert_eq(int(acid[0].data["count"]), 1, "one acid cell")
	assert_true(Vector2(acid[0].data["at"]).distance_to(foe.anchor_world()) < 1.0,
		"on what the saw hit")
	_complete()


# U22: a cloud of 20 acid gas cells 6 cells in front.
func test_acid_gas_vent_20_cells_ahead() -> void:
	var ctx := await duel([[[7], &"acid_gas_vent"]], [], 60.0)
	var vent := of(ctx, 0, &"acid_gas_vent")
	assert_true(vent != null, "the vent mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 6.1)
	await step(ctx, TICK, true)
	var gas := _spawned(spawns, &"acid_gas")
	assert_eq(gas.size(), 1, "one cloud")
	assert_eq(int(gas[0].data["count"]), 20, "20 acid gas cells")
	assert_true(Vector2(gas[0].data["at"]).is_equal_approx(
		vent.anchor_world() + vent.facing() * 6.0), "6 cells in front")
	_complete()


# U23: a beam that pays 6 a second, and Block spends two for every point of it.
func test_etching_ray_6_damage_and_double_block() -> void:
	var ctx := await duel([[[7], &"etching_ray"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 6, "the ray pays 6 a second")
	# 6 damage spends 12 Block, so 20 Block is 8 after one tick and nothing reaches HP.
	var guarded := await duel([[[7], &"etching_ray"]], [], 60.0)
	var guarded_foe: ChChariotRuntime = guarded.chariots[1]
	var guarded_before := guarded_foe.hp
	guarded.give_status(guarded_foe, ChStatuses.BLOCK, 20)
	await step(guarded, TICK, false, true)
	assert_eq(guarded_foe.statuses.count(ChStatuses.BLOCK), 8, "damage to Block is doubled")
	assert_eq(guarded_foe.hp, guarded_before, "and nothing reached HP behind it")
	_complete()


# U24: a lobbed flask that bursts into a 30-cell acid pool under the enemy hull's bottom centre.
func test_sinkhole_flask_30_acid_under_the_enemy() -> void:
	var ctx := await duel([[[7], &"sinkhole_flask"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 8.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	for _frame in 300:
		if not _spawned(spawns, &"acid").is_empty():
			break
		await step(ctx, TICK, false, false, 0.0, true)
	var acid := _spawned(spawns, &"acid")
	assert_eq(acid.size(), 1, "the flask burst once")
	assert_eq(int(acid[0].data["count"]), 30, "30 acid cells")
	var hull := ChBattle.hull_box(foe)
	var at: Vector2 = acid[0].data["at"]
	assert_true(absf(at.x - hull.get_center().x) < 3.0, "under the hull's centre")
	assert_true(at.y >= hull.end.y, "below its bottom edge")
	assert_true(_count(ctx, &"acid", Rect2i(int(at.x) - 10, int(at.y) - 5, 20, 15)) > 0,
		"and the pool is in the world under the enemy")
	_complete()


# R10: Acid on an enemy part also costs the enemy HP; your own Acid still only wears your part.
func test_universal_solvent_pays_enemy_acid_as_hp() -> void:
	var ctx := await duel([[[6], &"universal_solvent"], [[7], &"reinforced_frame"]],
		[[[7], &"reinforced_frame"]], 60.0)
	ctx.setup_all()
	var own := of(ctx, 0, &"reinforced_frame")
	var foe := of(ctx, 1, &"reinforced_frame")
	assert_true(own != null and foe != null, "both frames mounted")
	var mine: ChChariotRuntime = ctx.chariots[0]
	var theirs: ChChariotRuntime = ctx.chariots[1]
	var mine_hp := mine.hp
	var theirs_hp := theirs.hp
	ctx.give_status(foe, ChStatuses.ACID, 6)
	ctx.give_status(own, ChStatuses.ACID, 5)
	await step(ctx, 1.1)
	assert_eq(theirs_hp - theirs.hp, 6, "the enemy's 6 Acid also cost 6 HP")
	assert_eq(mine_hp, mine.hp, "your own Acid does not cost your HP")
	_complete()


# R11: a beam that pays 8 a second, drips one acid cell on its target, and digs the terrain in its
# path at hardness 8 (all but concrete) twice a second.
func test_matter_eater_8_damage_acid_and_dig() -> void:
	var ctx := await duel([[[7], &"matter_eater"]], [], 100.0)
	# Rock in the beam's path between the hulls (y 132..140), clear of both bodies, and concrete
	# beside it: hardness 8 digs the rock and never the indestructible concrete.
	ctx.world.fill_rect(Rect2i(200, 132, 20, 8), &"rock")
	ctx.world.fill_rect(Rect2i(196, 132, 4, 8), &"concrete")
	var rock_before := _count(ctx, &"rock", Rect2i(200, 132, 20, 8))
	var hits := sink(ctx, ChEvent.HIT)
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	var dug := sink(ctx, ChEvent.CELLS_DUG)
	await step(ctx, TICK, false, true)
	assert_eq(hits.size(), 1, "the beam hit once")
	assert_eq(int(hits[0].data["hp_damage"]), 8, "the beam pays 8")
	var acid := _spawned(spawns, &"acid")
	assert_eq(acid.size(), 1, "it dripped acid once")
	assert_eq(int(acid[0].data["count"]), 1, "one acid cell on its target")
	await step(ctx, 1.0, false, true)
	assert_true(dug.size() > 0, "the beam dug at its tip")
	assert_true(_count(ctx, &"rock", Rect2i(200, 132, 20, 8)) < rock_before,
		"it dissolved the rock in the beam")
	assert_eq(_count(ctx, &"concrete", Rect2i(196, 132, 4, 8)), 32,
		"and left the concrete alone")
	_complete()
