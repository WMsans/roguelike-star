extends ChPartTest

# Task 19: the Demolition parts (U42-U47, R20-R22) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The cell parts are asserted on the cells they spawn, the lobs on the EXPLOSION they leave and the
# HP the enemy paid, and the diggers on the cells they take out. A lob only flies on engine frames,
# so those tests pass frames = true; the passive listeners stay synchronous.
# R22's two stat reads only fold through ctx.setup_all, so its tests call it after duel mounted the
# parts (the amplifier's own setup subscribes nothing, so the second setup call changes nothing).

# The HP every HIT `source` dealt, in delivery order.
func _paid(hits: Array, source: Object) -> Array:
	var out: Array = []
	for hit in hits:
		if hit.source == source:
			out.append(int(hit.data["hp_damage"]))
	return out


# How many cells of `material` sit in `rect`.
func _count(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> int:
	return int(ctx.world.count_materials(rect).get(material, 0))


# The first cell of `material` inside `rect`, or null.
func _first(ctx: ChBattleContext, material: StringName, rect: Rect2i) -> Variant:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if ctx.world.get_material_at(Vector2i(x, y)) == material:
				return Vector2i(x, y)
	return null


# A hand-made material blast, as test_hazards.gd feeds ctx.hazards.apply.
func _blast(at: Vector2, material := &"tnt", radius := 12) -> Dictionary:
	return {"position": Vector2i(at), "radius": radius, "power": 1.0, "material": material, "dig": 6}


# U42: a lob that lands a 6x6 TNT crate, owned by the side that fired it.
func test_tnt_launcher_lobs_a_6x6_crate() -> void:
	var ctx := await duel([[[7], &"tnt_launcher"]], [], 60.0)
	var launcher := of(ctx, 0, &"tnt_launcher")
	assert_true(launcher != null, "the launcher mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	await step(ctx, 2.1, false, false, 0.0, true)
	launcher.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 8 s
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 6.0, false, false, 0.0, true)
	var crates: Array = []
	for event in spawns:
		if event.data.get("material") == &"tnt":
			crates.append(event)
	assert_eq(crates.size(), 1, "one crate landed")
	if crates.size() != 1:
		_complete()
		return
	assert_eq(int(crates[0].data["count"]), 36, "a 6x6 crate is 36 cells")
	var at: Vector2 = crates[0].data["at"]
	var cell = _first(ctx, &"tnt", Rect2i(Vector2i(at) - Vector2i(4, 4), Vector2i(9, 9)))
	assert_true(cell != null, "the crate is in the world")
	if cell == null:
		_complete()
		return
	# The crate is the player's: setting it off names side 0.
	var booms := sink(ctx, ChEvent.EXPLOSION)
	ctx.world.ignite(cell)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_true(booms.size() > 0, "the crate went off once fire reached it")
	for event in booms:
		assert_eq(event.side, 0, "the crate belongs to the side that laid it")
	_complete()


# U43: every TNT and gunpowder cell within 40 cells is set off; the ones further out are not.
func test_detonator_sets_off_tnt_within_40_cells() -> void:
	var ctx := await duel([[[7], &"detonator"]], [], 60.0)
	var det := of(ctx, 0, &"detonator")
	assert_true(det != null, "the detonator mounted")
	var near := Vector2i(190, 150)
	var far := Vector2i(260, 150)
	ctx.world.set_cell(near, &"tnt")
	ctx.world.set_cell(far, &"tnt")
	var booms := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 2.1, false, false, 0.0, true)
	det.cooldown_left = 0.0
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_true(booms.size() >= 1, "the TNT in reach went off")
	assert_eq(ctx.world.get_material_at(near), &"air", "the TNT 17 cells out is set off")
	assert_eq(ctx.world.get_material_at(far), &"tnt", "the TNT 80 cells out stays")
	_complete()


# U44: an explosion within range gives every neighbour 10 Block, not the shield itself.
func test_blast_shield_gives_neighbours_10_block() -> void:
	var ctx := await duel([[[5], &"reinforced_frame"], [[6], &"blast_shield"]], [], 60.0)
	var shield := of(ctx, 0, &"blast_shield")
	var neighbour := of(ctx, 0, &"reinforced_frame")
	assert_true(shield != null and neighbour != null, "the shield and its neighbour mounted")
	ctx.explode(shield, Vector2i(shield.anchor_world()), &"small", 0, 2)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 10, "the neighbour gains 10 Block")
	assert_eq(shield.statuses.count(ChStatuses.BLOCK), 0, "the shield is no neighbour of itself")
	ctx.explode(shield, Vector2i(400, 140), &"small", 0, 2)
	assert_eq(neighbour.statuses.count(ChStatuses.BLOCK), 10, "and nothing for a blast out of range")
	_complete()


# U45: a large blast where it lands: 80 damage, hardness 6.
func test_demolition_charge_large_80_damage_and_dig_6() -> void:
	var ctx := await duel([[[7], &"demolition_charge"]], [], 60.0)
	var charge := of(ctx, 0, &"demolition_charge")
	assert_true(charge != null, "the charge mounted")
	var foe: ChChariotRuntime = ctx.chariots[1]
	var booms := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 2.1, false, false, 0.0, true)
	charge.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 9 s
	await step(ctx, TICK, true, false, 0.0, true)
	var before := foe.hp
	await step(ctx, 6.0, false, false, 0.0, true)
	assert_eq(booms.size(), 1, "the charge exploded once")
	if booms.size() == 1:
		assert_eq(booms[0].data["size"], &"large", "a large blast")
		assert_eq(booms[0].data["dig"], 6, "digs up to hardness 6")
	assert_eq(before - foe.hp, 80, "80 damage where it lands")
	_complete()


# U46: a mine 4 cells behind the hull, which goes off (medium) when an enemy part comes near.
func test_mine_layer_drops_a_mine_behind_the_hull() -> void:
	var ctx := await duel([[[3], &"mine_layer"]], [[[0], &"reinforced_frame"]], 60.0)
	var layer := of(ctx, 0, &"mine_layer")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(layer != null and target != null, "the layer and an enemy part to trip it mounted")
	layer.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 7 s
	await step(ctx, TICK, true, false)
	assert_eq(ctx.fuses.size(), 1, "one mine is waiting")
	if ctx.fuses.is_empty():
		_complete()
		return
	var mine: Dictionary = ctx.fuses[0]
	var hull := ChBattle.hull_box(ctx.chariots[0])
	assert_near(float(mine["at"].x), hull.position.x - 4.0, 0.01, "4 cells behind the hull")
	assert_true(mine["node"] is Sprite2D, "a placeholder sprite marks it")
	if mine["node"] is Sprite2D:
		assert_eq(mine["node"].texture.get_width(), 3, "3 cells wide")
		assert_eq(mine["node"].texture.get_height(), 3, "and 3 tall")
	# An enemy part's box comes within the mine's 10 cells, and the enemy hull with it.
	target.body.teleport(mine["at"] + Vector2(2.0, 0.0))
	ctx.chariots[1].chassis.global_position = mine["at"] + Vector2(10.0, 0.0)
	var booms := sink(ctx, ChEvent.EXPLOSION)
	var before := ctx.chariots[1].hp
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(booms.size(), 1, "the mine went off")
	if booms.size() == 1:
		assert_eq(booms[0].data["size"], &"medium", "a medium blast")
		assert_eq(booms[0].data["radius"], 8, "the medium radius")
		assert_eq(booms[0].data["dig"], 4, "and the medium dig")
		assert_eq(booms[0].side, 0, "the layer's side owns it")
	assert_eq(before - ctx.chariots[1].hp, 60, "60 damage at the centre")
	assert_eq(ctx.fuses.size(), 0, "the mine is spent")
	_complete()


# U46: the mine belongs to the fight, so a layer broken before it goes off still sets it off.
func test_mine_outlives_its_layer() -> void:
	var ctx := await duel([[[3], &"mine_layer"]], [[[0], &"reinforced_frame"]], 60.0)
	var layer := of(ctx, 0, &"mine_layer")
	var target := of(ctx, 1, &"reinforced_frame")
	assert_true(layer != null and target != null, "the layer and an enemy part to trip it mounted")
	layer.cooldown_left = 0.0
	await step(ctx, TICK, true, false)
	assert_eq(ctx.fuses.size(), 1, "the mine is laid")
	if ctx.fuses.is_empty():
		_complete()
		return
	var mine: Dictionary = ctx.fuses[0]
	ctx.chariots[0].break_part(layer, ctx)
	assert_true(layer.broken, "the layer broke")
	target.body.teleport(mine["at"] + Vector2(2.0, 0.0))
	var booms := sink(ctx, ChEvent.EXPLOSION)
	ctx.tick(TICK, [0.0, 0.0], [], [])
	assert_eq(booms.size(), 1, "the mine still went off")
	if booms.size() == 1:
		assert_eq(booms[0].data["source"], layer, "as the broken layer's blast")
		assert_eq(booms[0].side, 0, "and on its side")
	_complete()


# U47: 8 a tick, and while running a 3-wide column straight down under it, 4 cells more a cut.
func test_excavator_8_a_tick_and_digs_straight_down() -> void:
	var ctx := await duel([[[7], &"excavator"]], [], 60.0)
	var excavator := of(ctx, 0, &"excavator")
	assert_true(excavator != null, "the excavator mounted")
	var foe: ChChariotRuntime = ctx.chariots[1]
	var hits := sink(ctx, ChEvent.HIT)
	var dug := sink(ctx, ChEvent.CELLS_DUG)
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 8, "one tick pays 8")
	assert_eq(_paid(hits, excavator), [8], "8 damage a tick")
	# At the brief's cadence (a cut every 0.5 s, 4 cells each) ~3 s reaches the arena floor; this drive
	# leaves a margin. The floor is measured under the column before the cuts, not named.
	var anchor := excavator.anchor_world()
	var floor_row := roundi(anchor.y)
	while ctx.world.get_material_at(Vector2i(roundi(anchor.x), floor_row)) == &"air" \
			and floor_row < roundi(anchor.y) + 60:
		floor_row += 1
	await step(ctx, 4.5, false, true)
	# A cut covers each of the column's 3 cells over its 4 rows, so the events are grouped by row and
	# every cut is deeper than the one before it.
	var depths: Array = []
	for event in dug:
		assert_near(event.position.x, anchor.x, 1.01, "the column is straight down")
		if depths.is_empty() or event.position.y > depths[-1]:
			depths.append(event.position.y)
	assert_true(depths.size() >= 2, "%d cuts reached the ground" % depths.size())
	for at in range(1, depths.size()):
		assert_true(depths[at] > depths[at - 1], "each cut is deeper")
	var first: Vector2 = dug[0].position
	assert_eq(ctx.world.get_material_at(Vector2i(first) + Vector2i(1, 0)), &"air",
		"the column is 3 cells wide")
	assert_true(depths[-1] >= float(floor_row), "the cuts reached the arena floor")
	_complete()


# U47: the column is a shaft, not a stack of sealed pockets. A radius-1 dig's ragged rim can leave a
# cell solid, so a cut digs each of the column's 3 cells and every row is cut: nothing between the
# anchor and the deepest cut stays solid, so the dig reaches the lava it opens the way to.
func test_excavator_cuts_a_shaft_with_no_solid_plugs() -> void:
	var ctx := await duel([[[3], &"excavator"]], [], 60.0)
	var excavator := of(ctx, 0, &"excavator")
	assert_true(excavator != null, "the excavator mounted")
	# Solid rock in the column from just under the anchor, so the plugs the dig would otherwise leave
	# between two cuts are visible.
	var anchor := Vector2i(excavator.anchor_world())
	var top := anchor.y + 1
	ctx.world.fill_rect(Rect2i(anchor.x - 1, top, 3, 24), &"rock")
	var dug := sink(ctx, ChEvent.CELLS_DUG)
	await step(ctx, 2.0, false, true)
	var deepest: float = float(top)
	for event in dug:
		deepest = maxf(deepest, event.position.y)
	assert_true(deepest > float(top + 4), "the cuts reached the rock")
	assert_eq(_count(ctx, &"rock", Rect2i(anchor.x - 1, top, 3, roundi(deepest) - top + 1)), 0,
		"no solid plug is left in the column down to the deepest cut")
	_complete()


# R20: an explosion near the enemy spawns a 4x4 owned TNT crate on the surface, once a second.
func test_chain_detonator_spawns_a_crate_on_the_surface() -> void:
	var ctx := await duel([[[7], &"chain_detonator"]], [], 60.0)
	var det := of(ctx, 0, &"chain_detonator")
	assert_true(det != null, "the chain detonator mounted")
	var spawns := sink(ctx, ChEvent.CELLS_SPAWNED)
	var at := Vector2i(ctx.chariots[1].chassis.global_position)
	ctx.explode(det, at, &"small", 0, 2)
	var crates: Array = []
	for event in spawns:
		if event.data.get("material") == &"tnt":
			crates.append(event)
	assert_eq(crates.size(), 1, "one crate")
	if crates.size() != 1:
		_complete()
		return
	assert_eq(int(crates[0].data["count"]), 16, "a 4x4 crate is 16 cells")
	assert_eq(roundi(crates[0].data["at"].x), at.x, "on the surface at the explosion's x")
	assert_eq(roundi(crates[0].data["at"].y), GROUND_TOP, "on the surface")
	# At most once a second: a second blast inside the same second spawns nothing.
	ctx.explode(det, at, &"small", 0, 2)
	assert_eq(spawns.size(), crates.size(), "no second crate inside the second")
	await step(ctx, 1.1)
	ctx.explode(det, at, &"small", 0, 2)
	assert_eq(spawns.size(), crates.size() + 1, "and one more a second later")
	_complete()


# R21: the ground under the enemy collapses 30 wide and 40 deep, down to hardness 8.
func test_earthquake_collapses_30_by_40_to_hardness_8() -> void:
	var ctx := await duel([[[7], &"earthquake"]], [], 60.0)
	var quake := of(ctx, 0, &"earthquake")
	assert_true(quake != null, "the earthquake mounted")
	var box := ChBattle.hull_box(ctx.chariots[1])
	var cx := roundi(box.get_center().x)
	var steel := Vector2i(cx - 10, GROUND_TOP + 4)  # hardness 7
	var obsidian := Vector2i(cx + 10, GROUND_TOP + 12)  # hardness 8
	var concrete := Vector2i(cx, GROUND_TOP + 2)  # never dug
	ctx.world.set_cell(steel, &"steel")
	ctx.world.set_cell(obsidian, &"obsidian")
	ctx.world.set_cell(concrete, &"concrete")
	quake.cooldown_left = 0.0  # a fresh part starts on its full cooldown; the def pins the 15 s
	await step(ctx, TICK, true, false)
	assert_eq(_count(ctx, &"rock", Rect2i(cx - 15, GROUND_TOP, 30, 20)), 0,
		"the 30-wide ground under the enemy is gone")
	assert_eq(ctx.world.get_material_at(steel), &"air", "hardness 7 is dug")
	assert_eq(ctx.world.get_material_at(obsidian), &"air", "hardness 8 is dug")
	assert_eq(ctx.world.get_material_at(concrete), &"concrete", "concrete never digs")
	assert_eq(_count(ctx, &"rock", Rect2i(cx - 30, GROUND_TOP, 5, 20)), 100,
		"the ground beyond the collapse stays")
	_complete()


# R22: your blasts are one size bigger, on both the part-made and the material path.
func test_blast_amplifier_one_size_bigger() -> void:
	var ctx := await duel([[[6], &"blast_amplifier"], [[7], &"dynamite_toss"]], [], 60.0)
	ctx.setup_all()
	var toss := of(ctx, 0, &"dynamite_toss")
	assert_true(toss != null and of(ctx, 0, &"blast_amplifier") != null,
		"the amplifier and a part to throw the blast mounted")
	var booms := sink(ctx, ChEvent.EXPLOSION)
	await step(ctx, 2.1, false, false, 0.0, true)
	toss.cooldown_left = 0.0  # a fresh part starts on its full cooldown
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 7.0, false, false, 0.0, true)
	assert_eq(booms.size(), 1, "the stick went off")
	if booms.size() == 1:
		assert_eq(booms[0].data["size"], &"medium", "a small part blast steps up to medium")
		assert_eq(booms[0].data["radius"], 8, "and takes the medium radius")
	# The same stat steps an owned material blast the side laid: gunpowder would be a small blast.
	var foe: ChChariotRuntime = ctx.chariots[1]
	ctx.hazards.own_charge(Rect2i(Vector2i(foe.chassis.global_position) - Vector2i(10, 10),
		Vector2i(20, 20)), 0)
	var before := foe.hp
	ctx.hazards.apply(ctx, [_blast(Vector2(foe.chassis.global_position), &"gunpowder", 5)])
	assert_eq(booms.size(), 2, "the material blast announced")
	if booms.size() == 2:
		assert_eq(booms[1].data["size"], &"medium", "a small material blast steps up too")
		assert_eq(booms[1].data["radius"], 8, "with the medium radius")
	assert_eq(before - foe.hp, int(ChHazards.SIZES[&"medium"]["damage"]),
		"and pays the medium size's damage")
	_complete()


# R22: no HP and no wear from an unowned terrain blast, nor from a blast its own side laid.
func test_amplifier_ignores_terrain_tnt() -> void:
	var ctx := await duel([[[7], &"blast_amplifier"]], [], 200.0)
	ctx.setup_all()
	var mine: ChChariotRuntime = ctx.chariots[0]
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := mine.hp
	var integrities: Array[int] = []
	for part in mine.parts:
		integrities.append(part.integrity)
	# Terrain TNT the engine set off: nobody owns it.
	ctx.hazards.apply(ctx, [_blast(Vector2(mine.chassis.global_position))])
	assert_eq(mine.hp, before, "terrain TNT does nothing to the amplifier's body")
	for at in mine.parts.size():
		assert_eq(mine.parts[at].integrity, integrities[at], "part %d untouched" % at)
	# Its own blast is no different.
	ctx.hazards.own_charge(Rect2i(Vector2i(mine.chassis.global_position) - Vector2i(20, 10),
		Vector2i(40, 20)), 0)
	ctx.hazards.apply(ctx, [_blast(Vector2(mine.chassis.global_position))])
	assert_eq(mine.hp, before, "and neither does its own blast")
	# The enemy is not shielded: the same blast pays it in full.
	var foe_before := foe.hp
	ctx.hazards.apply(ctx, [_blast(Vector2(foe.chassis.global_position))])
	assert_eq(foe_before - foe.hp, int(ChHazards.SIZES[&"large"]["damage"]),
		"the enemy pays a full TNT")
	_complete()


# R22: the ownership disc covers the blast's stepped size, so a chain landing past the material's
# own radius still belongs to the side that laid the first blast.
func test_amplified_blast_owns_the_stepped_radius() -> void:
	var ctx := await duel([[[6], &"blast_amplifier"]], [], 200.0)
	ctx.setup_all()
	var booms := sink(ctx, ChEvent.EXPLOSION)
	var at := Vector2i(240, 100)
	ctx.hazards.own_charge(Rect2i(at, Vector2i(2, 2)), 0)
	# gunpowder is a small blast (radius 5); the amplifier steps it to medium (radius 8).
	ctx.hazards.apply(ctx, [_blast(Vector2(at), &"gunpowder", 5)])
	assert_eq(booms.size(), 1, "the charge's blast announced")
	if booms.size() == 1:
		assert_eq(booms[0].data.owner, 0, "the charge owns it")
	# 7 cells out: outside the small radius and outside the charge's 4-cell margin, inside medium.
	ctx.hazards.apply(ctx, [_blast(at + Vector2i(7, 0), &"tnt", 12)])
	assert_eq(booms.size(), 2, "the chained blast announced")
	if booms.size() == 2:
		assert_eq(booms[1].data.owner, 0, "the chain carries the owner inside the stepped radius")
	_complete()
