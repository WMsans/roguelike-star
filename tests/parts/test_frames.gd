extends ChPartTest

# Task 24: the frames (U86-U88, R38) and the Mimic Module (R37), one test per part plus the three
# the brief names. Each asserts the number its row in docs/design-doc/parts-list.md gives.
# The stat hook (R38's range) and the Mimic's own resolution both run in ctx.setup_all(), so those
# tests call it after duel(): duel alone calls each behaviour's setup and caches no modifier.

# A child weapon that records the way it was facing when it fired, so the Turret Mount's forced
# fire can be read back: the forced event is delivered after the mount has put the facing back.
class FireProbe:
	extends ChBehaviour

	var facings: Array[Vector2] = []

	func fire(_ctx: ChBattleContext) -> void:
		facings.append(part.facing())


# U86: a weapon mounted on the turret fires both ways, at half damage each way.
func test_turret_fires_both_ways_at_half() -> void:
	var ctx := await duel([[[3], &"turret_mount"], [[3, 0], &"minigun"]])
	var turret := of(ctx, 0, &"turret_mount")
	var gun := of(ctx, 0, &"minigun")
	assert_true(turret != null and gun != null, "the mount and its gun mounted")
	if turret == null or gun == null:
		_complete()
		return
	assert_eq(gun.parent, turret, "the gun is mounted on the turret")
	# Half damage: the gun's 20 lands as 10 on the enemy.
	var before := ctx.chariots[1].hp
	ctx.deal_hit(gun, of(ctx, 1, WHEEL_ID).body, 20)
	assert_eq(before - ctx.chariots[1].hp, 10, "the gun's hit is halved")
	# Both ways: the gun's own firing makes the mount fire it again facing the other way.
	var probe := FireProbe.new()
	probe.part = gun
	gun.behaviour = probe
	var fired := sink(ctx, ChEvent.PART_FIRED)
	ctx._emit_fired(gun)
	assert_eq(probe.facings.size(), 1, "the mount forced one more firing")
	if probe.facings.size() == 1:
		assert_true(probe.facings[0].is_equal_approx(-gun.facing()),
			"the forced firing faces the other way")
	assert_eq(fired.size(), 2, "the gun's own firing and the forced one")
	if fired.size() == 2:
		assert_true(bool(fired[1].data.get("forced", false)), "the second firing is forced")
		assert_eq(fired[1].data.get("by"), turret, "and the mount forced it")
	_complete()


# U87: start of battle, every part mounted on the gantry gains 10 Block.
func test_gantry_10_block_per_mounted_part() -> void:
	var ctx := await duel([[[3], &"gantry"], [[3, 0], &"reinforced_frame"],
		[[3, 1], &"spare_cell"]])
	var gantry := of(ctx, 0, &"gantry")
	assert_true(gantry != null, "the gantry mounted")
	if gantry == null:
		_complete()
		return
	assert_eq(gantry.children.size(), 2, "both parts are mounted on it")
	await step(ctx, TICK)
	assert_eq(of(ctx, 0, &"reinforced_frame").statuses.count(ChStatuses.BLOCK), 10,
		"a mounted part gains 10 Block")
	assert_eq(of(ctx, 0, &"spare_cell").statuses.count(ChStatuses.BLOCK), 10,
		"and so does the other")
	assert_eq(gantry.statuses.count(ChStatuses.BLOCK), 0, "the gantry itself gains none")
	_complete()


# U88: parts mounted on the hub count as neighbours of each other and of the hub.
func test_hub_frame_children_are_neighbours() -> void:
	var ctx := await duel([[[3], &"hub_frame"], [[3, 0], &"spare_cell"],
		[[3, 1], &"generator"], [[5], &"reinforced_frame"]])
	var hub := of(ctx, 0, &"hub_frame")
	var a := of(ctx, 0, &"spare_cell")
	var b := of(ctx, 0, &"generator")
	var other := of(ctx, 0, &"reinforced_frame")
	assert_true(hub != null and a != null and b != null and other != null, "the hub and its parts mounted")
	if hub == null or a == null or b == null or other == null:
		_complete()
		return
	assert_eq(a.parent, hub, "the spare cell hangs on the hub")
	assert_eq(b.parent, hub, "and so does the generator")
	assert_true(ctx.near(hub, a), "a part mounted on the hub is a neighbour of the hub")
	assert_true(ctx.near(a, b), "and the two mounted parts are neighbours of each other")
	assert_true(not ctx.near(hub, other), "a part mounted elsewhere is not")
	_complete()


# R38: a part mounted on the Exo-Frame has one size more range.
func test_exo_frame_children_get_one_size_more_range() -> void:
	var ctx := await duel([[[3], &"exo_frame"], [[3, 0], &"bayonet"],
		[[3, 1], &"antifreeze_coat"], [[3, 2], &"condenser"], [[3, 3], &"spare_cell"],
		[[5], &"bellows"]])
	ctx.setup_all()
	var bayonet := of(ctx, 0, &"bayonet")
	var coat := of(ctx, 0, &"antifreeze_coat")
	var condenser := of(ctx, 0, &"condenser")
	var cell := of(ctx, 0, &"spare_cell")
	var bellows := of(ctx, 0, &"bellows")
	assert_true(bayonet != null and coat != null and condenser != null and cell != null
		and bellows != null, "the frame and its parts mounted")
	if bayonet == null or coat == null or condenser == null or cell == null or bellows == null:
		_complete()
		return
	assert_near(ctx.range_of(bayonet), 20.0, 0.001, "S 12 steps up to M 20")
	assert_near(ctx.range_of(coat), 32.0, 0.001, "M 20 steps up to L 32")
	assert_near(ctx.range_of(condenser), 32.0, 0.001, "L 32 stays L")
	assert_near(ctx.range_of(cell), 0.0, 0.001, "no range stays none")
	assert_near(ctx.range_of(bellows), 12.0, 0.001, "a part mounted elsewhere keeps its S 12")
	_complete()


# R37: the Mimic Module becomes the part in front of it, with its own id, integrity, size and look.
func test_mimic_module_copies_the_part_in_front() -> void:
	var ctx := await duel([[[2], &"mimic_module"], [[3], &"chainsaw"]])
	var mimic := of(ctx, 0, &"mimic_module")
	var saw := of(ctx, 0, &"chainsaw")
	assert_true(mimic != null and saw != null, "the Mimic and the chainsaw mounted")
	if mimic == null or saw == null:
		_complete()
		return
	ctx.setup_all()
	assert_eq(mimic.def.id, &"mimic_module", "the Mimic keeps its own id")
	assert_eq(mimic.def.damage, saw.def.damage, "the copied damage")
	assert_eq(mimic.def.mode, ChPartDef.MODE_MELEE, "the copied firing mode")
	assert_eq(mimic.def.energy_per_second, saw.def.energy_per_second, "the copied energy cost")
	assert_eq(mimic.def.tags, saw.def.tags, "the copied tags")
	assert_eq(mimic.def.integrity, 50, "its own integrity")
	assert_eq(mimic.integrity, 50, "the live part keeps its own")
	assert_eq(mimic.def.size, Vector2i(6, 6), "its own size")
	assert_true(mimic.behaviour != null and not mimic.behaviour.has_method("resolve"),
		"a fresh behaviour of the front def's script")
	assert_eq(mimic.behaviour.get_script().resource_path,
		saw.behaviour.get_script().resource_path, "the chainsaw's script")
	assert_eq(mimic.cost, saw.def.energy_cost, "the cost re-seeded")
	assert_near(mimic.rate, saw.def.energy_per_second, 0.001, "the rate re-seeded")
	assert_near(mimic.cooldown, saw.def.cooldown, 0.001, "the cooldown re-seeded")
	_complete()


# R37: the copied chainsaw is a real weapon: the held button runs it and its tick deals 15.
func test_mimic_copies_a_chainsaw_and_holds() -> void:
	var ctx := await duel([[[2], &"mimic_module"], [[3], &"chainsaw"]])
	var mimic := of(ctx, 0, &"mimic_module")
	var saw := of(ctx, 0, &"chainsaw")
	assert_true(mimic != null and saw != null, "the Mimic and the chainsaw mounted")
	if mimic == null or saw == null:
		_complete()
		return
	ctx.setup_all()
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 1.2, false, true)
	var saw_hits := 0
	var copy_hits := 0
	var copy_damage := 0
	for hit in hits:
		var event: ChEvent = hit
		if event.source == saw:
			saw_hits += 1
		elif event.source == mimic:
			copy_hits += 1
			copy_damage = event.data["hp_damage"]
	assert_true(saw_hits > 0, "the chainsaw ticks")
	assert_true(copy_hits > 0, "the Mimic runs the copied chainsaw on the held button")
	assert_eq(copy_damage, saw.def.damage, "the copied tick deals the chainsaw's damage")
	assert_eq(mimic.def.id, &"mimic_module", "the copy holds: the Mimic keeps its own id")
	_complete()


# R37: a wheel is not a part in a slot ahead to copy. The left wheel sits one cell ahead of
# slot 0, so the old "nearest part ahead" rule copied it and gave the Mimic the wheel tag and mode,
# which put it back in chariot.wheels() as a wheel that cannot motorise.
func test_mimic_with_a_wheel_ahead_stays_inert() -> void:
	var ctx := await duel([[[0], &"mimic_module"]])
	var mimic := of(ctx, 0, &"mimic_module")
	assert_true(mimic != null, "the Mimic mounted")
	if mimic == null:
		_complete()
		return
	ctx.setup_all()
	assert_eq(mimic.def.id, &"mimic_module", "the Mimic keeps its own id")
	assert_eq(mimic.def.mode, ChPartDef.MODE_PASSIVE, "it stays passive")
	assert_true(not mimic.def.is_wheel(), "and it did not become a wheel")
	assert_true(not ctx.chariots[0].wheels().has(mimic), "the chariot does not motorise it")
	_complete()


# R37: the Mimic copies the slot immediately ahead, not the next part along its facing. A chainsaw
# two slots ahead with slot 3 empty is out of reach.
func test_mimic_with_a_gap_ahead_stays_inert() -> void:
	var ctx := await duel([[[2], &"mimic_module"], [[4], &"chainsaw"]])
	var mimic := of(ctx, 0, &"mimic_module")
	assert_true(mimic != null, "the Mimic mounted")
	if mimic == null:
		_complete()
		return
	ctx.setup_all()
	assert_eq(mimic.def.id, &"mimic_module", "the Mimic keeps its own id")
	assert_eq(mimic.def.damage, 0, "a part two slots ahead is not copied")
	assert_eq(mimic.def.mode, ChPartDef.MODE_PASSIVE, "so it stays passive")
	assert_true(mimic.behaviour != null and mimic.behaviour.has_method("resolve"),
		"with no copy taken")
	_complete()


# R37 and parts-list §6: two Mimic Modules facing each other copy nothing and the fight runs on.
# Slots 0 and 1: the two face each other in adjacent slots, and the left wheel a cell ahead of the
# left Mimic is not copied either, so the wheel case cannot hide behind the Mimic rule.
func test_two_mimics_do_nothing() -> void:
	var ctx := await duel([[[0], &"mimic_module"], [[1], &"mimic_module", true]])
	ctx.setup_all()
	var mimics: Array[ChPartRuntime] = []
	for part in ctx.chariots[0].parts:
		if part.def != null and part.def.id == &"mimic_module":
			mimics.append(part)
	assert_eq(mimics.size(), 2, "both Mimics mounted")
	var fired := sink(ctx, ChEvent.PART_FIRED)
	await step(ctx, 1.0, true, true)
	for mimic in mimics:
		assert_eq(mimic.def.damage, 0, "a Mimic facing a Mimic stays inert")
		assert_eq(mimic.def.mode, ChPartDef.MODE_PASSIVE, "and passive")
		assert_true(mimic.behaviour != null and mimic.behaviour.has_method("resolve"),
			"with no copy taken")
	assert_eq(fired.size(), 0, "and nothing fires")
	_complete()
