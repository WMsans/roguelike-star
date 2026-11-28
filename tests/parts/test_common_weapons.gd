extends ChPartTest

# Task 5: the common weapons (C01-C10) on the Task 1 RIG, one test per part, each asserting the
# number its row in docs/design-doc/parts-list.md gives.
# The RIG's top slots sit on the hull's top edge (y = -4 on an 8-cell hull), so a straight shot from
# one runs along that edge: the projectile tests give the enemy a part on its own top slot to meet,
# which straddles the line, and the melee tests measure the reach box against the hull.
# A projectile only flies on engine frames, so those tests pass frames = true; the melee, bayonet and
# frame tests are pure geometry and stay synchronous.

# C01: a straight shot, 60 on the body it meets.
func test_rocket_pod_60_damage() -> void:
	var ctx := await duel([[[7], &"rocket_pod"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 4.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_eq(before - foe.hp, 60, "the rocket pays 60 on the body it meets")
	_complete()


# C02: a heavy shell, 120, lobbed under gravity.
func test_cannon_120_damage() -> void:
	var ctx := await duel([[[7], &"cannon"]], [[[0], &"reinforced_frame"]], 100.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 7.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 2.0, false, false, 0.0, true)
	assert_eq(before - foe.hp, 120, "the shell pays 120 on the body it meets")
	_complete()


# C03: a continuous melee weapon, 15 a tick.
func test_chainsaw_15_damage_per_tick() -> void:
	var ctx := await duel([[[7], &"chainsaw"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 15, "one tick of the saw pays 15")
	_complete()


# C04: 12 a tick, and the tip digs the ground in front of it once a second.
func test_drill_12_damage_per_tick() -> void:
	var ctx := await duel([[[7], &"drill"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	# Rock in front of the tip (the reach box ends at x 209.5), clear of the enemy hull at 190.
	ctx.world.fill_rect(Rect2i(200, 130, 12, 12), &"rock")
	var dug := sink(ctx, ChEvent.CELLS_DUG)
	var before := foe.hp
	await step(ctx, TICK, false, true)
	await step(ctx, 0.5, false, true)
	assert_eq(before - foe.hp, 12, "one tick of the drill pays 12")
	assert_true(dug.size() > 0 and int(dug[0].data["count"]) > 0, "the tip dug the rock in front of it")
	_complete()


# C05: 25, and it reaches twice as far as the other melee weapons: the hull is out of a 24-cell
# reach at this gap and inside the Stinger's 48.
func test_stinger_25_damage() -> void:
	var ctx := await duel([[[7], &"stinger"]], [], 100.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 2.1)
	await step(ctx, TICK, true)
	assert_eq(before - foe.hp, 25, "the stab pays 25 at twice the reach")
	_complete()


# C06: 10 a tick, and the square reach box ignores which way the part faces: this one is mounted
# flipped, so it is turned away from the enemy and still hits.
func test_spinning_blade_10_damage_per_tick() -> void:
	var ctx := await duel([[[7], &"spinning_blade", true]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 10, "one tick of the blade pays 10, facing away")
	_complete()


# C07: a beam, 12 a second on the body it reaches.
func test_laser_12_damage_per_second() -> void:
	var ctx := await duel([[[7], &"laser"]], [], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, TICK, false, true)
	assert_eq(before - foe.hp, 12, "the first tick of the beam pays 12")
	await step(ctx, 2.0, false, true)
	assert_true(before - foe.hp >= 36, "and it keeps paying 12 a second while held")
	_complete()


# C08: 7 pellets of 12, and the kick that shoves both chariots.
func test_shotgun_7_pellets_of_12_damage() -> void:
	var ctx := await duel([[[7], &"shotgun"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var mine: ChChariotRuntime = ctx.chariots[0]
	var before := foe.hp
	var mine_x := mine.chassis.global_position.x
	var foe_x := foe.chassis.global_position.x
	var hits := sink(ctx, ChEvent.HIT)
	await step(ctx, 5.1, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_true(hits.size() >= 1 and hits.size() <= 7, "%d pellets landed, want 1 to 7" % hits.size())
	for hit in hits:
		# A pellet that met the hull pays its 12 whole; one that met a part still pays 12 HP.
		assert_eq(int(hit.data["hp_damage"]), 12, "a pellet pays 12")
	assert_eq(before - foe.hp, 12 * hits.size(), "the pellets are the whole of the damage")
	assert_true(mine.chassis.global_position.x < mine_x, "the kick shoves the shooter back")
	assert_true(foe.chassis.global_position.x > foe_x, "and the target away")
	_complete()


# C09: a bullet, 6.
func test_minigun_6_damage() -> void:
	var ctx := await duel([[[7], &"minigun"]], [[[0], &"reinforced_frame"]], 60.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var before := foe.hp
	await step(ctx, 0.6, false, false, 0.0, true)
	await step(ctx, TICK, true, false, 0.0, true)
	await step(ctx, 1.5, false, false, 0.0, true)
	assert_eq(before - foe.hp, 6, "the bullet pays 6")
	_complete()


# C10: 20 when the weapon behind it fires. Two Bayonets behind a Minigun chain: the Minigun's shot
# pays the first Bayonet, whose own PART_FIRED pays the second. The whole chain is one press, and
# the 10 s of quiet after it must not hang (Review Focus 4).
func test_bayonet_20_damage() -> void:
	var ctx := await duel([[[5], &"minigun"], [[6], &"bayonet"], [[7], &"bayonet"]], [], 40.0)
	var foe: ChChariotRuntime = ctx.chariots[1]
	var fired := sink(ctx, ChEvent.PART_FIRED)
	var before := foe.hp
	await step(ctx, 0.6)
	await step(ctx, TICK, true)
	assert_eq(fired.size(), 3, "the Minigun and both Bayonets fired")
	assert_eq(before - foe.hp, 40, "each Bayonet paid 20")
	await step(ctx, 10.0)
	assert_eq(fired.size(), 3, "and the chain stopped there")
	_complete()