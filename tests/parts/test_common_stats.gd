extends ChPartTest

# Task 5: the common stats, wheels and frames (C36-C43) on the Task 1 RIG, one test per part, each
# asserting the number its row in docs/design-doc/parts-list.md gives.
# The wheels are the only parts that move the chariot, so their tests await engine frames: the motor
# turns on a physics frame and the chassis only travels while the world steps.

# C36: +5 energy capacity, and the pool starts full.
func test_spare_cell_5_energy_capacity() -> void:
	var ctx := await duel([[[0], &"spare_cell"]])
	var energy: ChEnergy = ctx.chariots[0].energy
	assert_eq(energy.cap, 25.0, "the pool holds 5 more")
	assert_eq(energy.value, 25.0, "and starts full")
	_complete()


# C37: +1 energy regen a second.
func test_generator_1_energy_regen() -> void:
	var ctx := await duel([[[0], &"generator"]])
	assert_eq(ctx.chariots[0].energy.regen, 5.0, "the pool regens 1 more a second")
	_complete()


# C38: +100 max HP, and the body starts with it.
func test_reinforced_frame_100_max_hp() -> void:
	var ctx := await duel([[[0], &"reinforced_frame"]])
	var chariot: ChChariotRuntime = ctx.chariots[0]
	assert_eq(chariot.max_hp, 900, "the body holds 100 more HP")
	assert_eq(chariot.hp, 900, "and starts with them")
	_complete()


# C39: 1 energy a second, at the motor speed and grip the row's average buys.
func test_roller_average_speed_and_grip() -> void:
	var ctx := await duel([[[0], &"roller"]])
	var roller := of(ctx, 0, &"roller")
	assert_true(roller != null, "the roller mounted")
	await step(ctx, 3.0, false, false, 1.0, true)
	assert_eq(roller.rate, 1.0, "and costs 1 energy a second")
	assert_eq(roller.def.wheel_speed, 12.0, "at the motor speed the row's average speed buys")
	assert_eq(roller.def.wheel_friction, 1.5, "with the grip the row's average grip buys")
	_complete()


# C40: 2 energy a second, and it ends the same 3 s drive further than a Roller.
func test_bigfoot_fast_and_climbs() -> void:
	var bigfoot := await duel([[[0], &"bigfoot"]])
	var roller := await duel([[[0], &"roller"]])
	var bigfoot_x: float = bigfoot.chariots[0].chassis.global_position.x
	var roller_x: float = roller.chariots[0].chassis.global_position.x
	await step(bigfoot, 3.0, false, false, 1.0, true)
	await step(roller, 3.0, false, false, 1.0, true)
	assert_true(bigfoot.chariots[0].chassis.global_position.x > roller.chariots[0].chassis.global_position.x,
		"the bigfoot ends further than the roller")
	assert_true(bigfoot_x <= bigfoot.chariots[0].chassis.global_position.x, "and it really drove right")
	assert_true(roller_x <= roller.chariots[0].chassis.global_position.x, "as did the roller")
	assert_eq(of(bigfoot, 0, &"bigfoot").rate, 2.0, "the bigfoot costs 2 energy a second")
	_complete()


# C41: 1 energy a second, and the grip that makes it hard to push back.
func test_sticky_tire_excellent_grip() -> void:
	var ctx := await duel([[[0], &"sticky_tire"]])
	var tire := of(ctx, 0, &"sticky_tire")
	assert_true(tire != null, "the sticky tire mounted")
	await step(ctx, 3.0, false, false, 1.0, true)
	assert_eq(tire.rate, 1.0, "and costs 1 energy a second")
	assert_eq(tire.def.wheel_friction, 3.0, "with the grip the row's 'excellent grip' buys")
	_complete()


# C42: one extension slot, and a part bolted onto it.
func test_strut_holds_one_more_part() -> void:
	var def: ChPartDef = ChCatalog.load_default().part(&"strut")
	assert_true(def != null, "the strut loads from res://game/data/parts")
	assert_eq(def.extension_slots.size(), 1, "one extension slot")
	assert_eq(def.extension_slots[0], Vector2(0, -6), "6 cells above its anchor")
	var ctx := await duel([[[0], &"strut"], [[0, 0], &"spare_cell"]])
	assert_true(of(ctx, 0, &"spare_cell") != null, "a part mounts on the slot")
	_complete()


# C43: one extension slot 30 cells out, past the edge of the body.
func test_long_arm_holds_one_part_30_cells_out() -> void:
	var def: ChPartDef = ChCatalog.load_default().part(&"long_arm")
	assert_true(def != null, "the long arm loads from res://game/data/parts")
	assert_eq(def.extension_slots.size(), 1, "one extension slot")
	var ctx := await duel([[[0], &"long_arm"], [[0, 0], &"spare_cell"]])
	var arm := of(ctx, 0, &"long_arm")
	var child := of(ctx, 0, &"spare_cell")
	assert_true(arm != null and child != null, "the arm and the part on it mounted")
	assert_near(child.anchor_world().distance_to(arm.anchor_world()), 30.0, 0.01,
		"the part on it sits 30 cells out")
	_complete()