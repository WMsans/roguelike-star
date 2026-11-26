extends ChTest

# The status second: pass A (damage, cell effects) for every holder, then pass B (gain from cells,
# decay) for every holder. Fake part bodies; a real world only where cells matter.

const TICK_SECOND := 1.0


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


func _part(side: int, at: Vector2, integrity := 50) -> ChPartRuntime:
	var p := ChPartRuntime.new()
	p.def = ChPartDef.new()
	p.def.size = Vector2i(2, 2)
	p.side = side
	p.integrity = integrity
	p.body = FakeBody.new()
	p.body.global_position = at
	return p


func _chariot(side: int, at: Vector2, parts: Array, hp := 100) -> ChChariotRuntime:
	var c := ChChariotRuntime.new()
	c.side = side
	c.hp = hp
	c.body_def = ChBodyDef.new()
	c.body_def.size = Vector2i(4, 4)
	c.energy = ChEnergy.new(0, 0)
	c.chassis = _track(PixelRigidBody.new())
	c.chassis.position = at
	for p in parts:
		c.parts.append(p)
	return c


func _ctx(chariots: Array, world: PixelWorld = null) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.bus = ChEventBus.new()
	ctx.world = world
	for c in chariots:
		ctx.chariots.append(c)
	return ctx


func _heard(ctx: ChBattleContext, type: StringName) -> Array:
	# The events of one type the bus carries from here on, in order.
	var heard: Array = []
	ctx.bus.subscribe(self, type, func(e: ChEvent): heard.append(e))
	return heard


func _tick(ctx: ChBattleContext, delta := TICK_SECOND) -> void:
	var drive: Array[float] = []
	for _c in ctx.chariots:
		drive.append(0.0)
	ctx.tick(delta, drive)


func test_fire_cells_give_flame_each_second() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, 100))
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [p])], world)
	assert_eq(p.sample_rect(), Rect2i(97, 97, 6, 6), "a 36-cell rect")
	assert_eq(world.fill_rect(Rect2i(97, 97, 4, 1), &"fire"), 4, "4 fire cells, under half the rect")
	_tick(ctx)
	assert_eq(p.integrity, 50, "the first second gains, it does not burn yet")
	assert_eq(p.statuses.count(ChStatuses.FLAME), 2, "gained 2, no decay while in the fire")
	_tick(ctx)
	assert_eq(p.integrity, 48, "the next second burns the 2")
	assert_eq(p.statuses.count(ChStatuses.FLAME), 3, "and grows 1 net while in the fire")
	_complete()


func _holds_while_touching(material: StringName, status: StringName) -> void:
	# A 1-stack-a-second material keeps its status at 1 on every frame, with one GAINED and no LOST.
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, 100))
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [p])], world)
	var gained := _heard(ctx, ChEvent.STATUS_GAINED)
	var lost := _heard(ctx, ChEvent.STATUS_LOST)
	assert_eq(world.fill_rect(Rect2i(97, 97, 4, 1), material), 4, "4 %s cells, under half the rect" % material)
	for second in 3:
		_tick(ctx, 0.5)
		if second > 0:
			assert_eq(p.statuses.count(status), 1, "%s held between seconds (second %d)" % [status, second])
			if status == ChStatuses.FREEZE:
				assert_true(p.is_frozen(), "frozen on the frame between seconds")
		_tick(ctx, 0.5)
		assert_eq(p.statuses.count(status), 1, "%s is 1 after second %d" % [status, second + 1])
	assert_eq(gained.size(), 1, "one STATUS_GAINED")
	assert_eq(gained[0].data["status"] if gained.size() > 0 else &"", status, "for %s" % status)
	assert_eq(lost.size(), 0, "no STATUS_LOST")


func test_ice_holds_freeze_while_touching() -> void:
	await _holds_while_touching(&"ice", ChStatuses.FREEZE)
	_complete()


func test_smoke_holds_slow_while_touching() -> void:
	await _holds_while_touching(&"smoke", ChStatuses.SLOW)
	_complete()


func test_both_sides_gain_after_both_sides_cells() -> void:
	# Pass B for side 0 reads cells side 1's Freeze turned to ice in pass A of the same second.
	var world: PixelWorld = await make_world()
	var mine := _part(0, Vector2(100, 100))
	var theirs := _part(1, Vector2(100, 100))
	theirs.statuses.stacks[ChStatuses.FREEZE] = 3
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [mine]), _chariot(1, Vector2(400, 100), [theirs])], world)
	assert_eq(world.fill_rect(Rect2i(97, 97, 6, 1), &"water"), 6, "6 water cells under both")
	_tick(ctx)
	assert_eq(mine.statuses.count(ChStatuses.FREEZE), 1, "side 0 gained from side 1's new ice")
	_complete()


func test_flame_wears_integrity_not_hp() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.FLAME] = 5
	var c := _chariot(0, Vector2(1000, 1000), [p])
	var ctx := _ctx([c])
	_tick(ctx)
	assert_eq(p.integrity, 45, "integrity down 5")
	assert_eq(c.hp, 100, "HP unchanged")
	assert_eq(p.statuses.count(ChStatuses.FLAME), 4, "Flame decayed")
	_complete()


func test_body_flame_burns_hp() -> void:
	var c := _chariot(0, Vector2.ZERO, [])
	c.statuses.stacks[ChStatuses.FLAME] = 5
	_tick(_ctx([c]))
	assert_eq(c.hp, 95, "HP down 5")
	_complete()


func test_acid_eats_block_first() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.ACID] = 4
	p.statuses.stacks[ChStatuses.BLOCK] = 3
	var ctx := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	var lost := _heard(ctx, ChEvent.STATUS_LOST)
	_tick(ctx)
	assert_eq(p.statuses.count(ChStatuses.BLOCK), 0, "Block spent")
	var block_lost := lost.filter(func(e: ChEvent): return e.data["status"] == ChStatuses.BLOCK)
	assert_eq(block_lost.size(), 1, "Acid eating the last Block loses it")
	assert_eq(p.integrity, 49, "integrity down 1")
	_complete()


func test_fire_mult_scales_enemy_flame_only() -> void:
	var mine := _chariot(0, Vector2.ZERO, [])
	var foe := _chariot(1, Vector2(1000, 0), [])
	mine.statuses.stacks[ChStatuses.FLAME] = 10
	foe.statuses.stacks[ChStatuses.FLAME] = 10
	var ctx := _ctx([mine, foe])
	ctx.rules.fire_mult = 0.5
	_tick(ctx)
	assert_eq(foe.hp, 95, "side 1 takes half")
	assert_eq(mine.hp, 90, "side 0 takes it all")
	_complete()


func test_freeze_pauses_cooldown_speedup_doubles_slow_halves() -> void:
	var p := _part(0, Vector2.ZERO)
	p.def.cooldown = 3.0
	p.cooldown_left = 3.0
	p.statuses.stacks[ChStatuses.FREEZE] = 1
	p.tick_cooldown(1.0)
	assert_near(p.cooldown_left, 3.0, 0.0001, "Freeze pauses")
	p.statuses.stacks[ChStatuses.FREEZE] = 0
	p.statuses.stacks[ChStatuses.SPEEDUP] = 1
	p.tick_cooldown(1.0)
	assert_near(p.cooldown_left, 1.0, 0.0001, "Speedup doubles")
	p.statuses.stacks[ChStatuses.SPEEDUP] = 0
	p.statuses.stacks[ChStatuses.SLOW] = 1
	p.cooldown_left = 3.0
	p.tick_cooldown(1.0)
	assert_near(p.cooldown_left, 2.5, 0.0001, "Slow halves")
	_complete()


func test_body_freeze_pauses_regen() -> void:
	var c := _chariot(0, Vector2.ZERO, [])
	c.energy = ChEnergy.new(10, 4)
	c.energy.value = 0.0
	c.statuses.stacks[ChStatuses.FREEZE] = 2
	_tick(_ctx([c]), 0.5)
	assert_near(c.energy.value, 0.0, 0.0001, "no regen while the body is frozen")
	_complete()


func test_frozen_wheel_locks_motor() -> void:
	var wheel := _part(0, Vector2.ZERO)
	wheel.def.id = ChChariotRuntime.WHEEL_ID
	wheel.joint = _track(PixelWheelJoint.new())
	wheel.statuses.stacks[ChStatuses.FREEZE] = 1
	var c := _chariot(0, Vector2(1000, 1000), [wheel])
	c.drive(1.0)
	assert_true(not wheel.joint.enable_motor, "the frozen wheel's motor is off")
	_complete()


func test_freeze_turns_touching_water_to_ice() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, 100))
	p.statuses.stacks[ChStatuses.FREEZE] = 3
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [p])], world)
	assert_eq(world.fill_rect(Rect2i(97, 97, 6, 1), &"water"), 6, "6 water cells")
	_tick(ctx)
	var ice := 0
	for x in range(97, 103):
		if world.get_material_at(Vector2i(x, 97)) == &"ice":
			ice += 1
	assert_true(ice >= 4, "at least 4 turned to ice (got %d)" % ice)
	_complete()


func test_block_absorbs_weapon_hit_in_deal_hit() -> void:
	var gun := _part(0, Vector2.ZERO)
	var target := _part(1, Vector2(500, 0))
	target.integrity = 200
	target.statuses.stacks[ChStatuses.BLOCK] = 40
	var foe := _chariot(1, Vector2(500, 500), [target], 200)
	var ctx := _ctx([_chariot(0, Vector2(0, 500), [gun]), foe])
	var lost := _heard(ctx, ChEvent.STATUS_LOST)
	ctx.deal_hit(gun, target.body, 100)
	assert_eq(foe.hp, 140, "HP down 60")
	assert_eq(target.statuses.count(ChStatuses.BLOCK), 0, "Block spent")
	assert_eq(lost.size(), 1, "the last Block used up is lost")
	if lost.size() == 1:
		assert_eq(lost[0].data, {"status": ChStatuses.BLOCK}, "lost Block")
		assert_eq(lost[0].source, target, "on the part hit")
	_complete()


func test_long_tick_runs_two_status_seconds() -> void:
	var c := _chariot(0, Vector2.ZERO, [])
	c.statuses.stacks[ChStatuses.FLAME] = 10
	var ctx := _ctx([c])
	_tick(ctx, 2.5)
	assert_eq(c.hp, 81, "10 then 9")
	assert_near(ctx.status_clock, 0.5, 0.0001, "half a second carried")
	_complete()


func test_status_break_mid_second() -> void:
	var parent := _part(0, Vector2.ZERO, 3)
	var child := _part(0, Vector2(0, -4))
	parent.children.append(child)
	child.parent = parent
	parent.statuses.stacks[ChStatuses.FLAME] = 5
	var c := _chariot(0, Vector2(1000, 1000), [parent, child])
	_tick(_ctx([c]))
	assert_true(parent.broken and child.broken, "both broke")
	assert_eq(parent.statuses.count(ChStatuses.FLAME), 5, "no decay on the part that broke")
	_complete()


func test_dead_chariot_takes_no_status_second() -> void:
	var c := _chariot(0, Vector2.ZERO, [], 2)
	c.statuses.stacks[ChStatuses.FLAME] = 10
	var ctx := _ctx([c])
	_tick(ctx)
	_tick(ctx)
	assert_eq(c.hp, 0, "dead")
	assert_eq(c.statuses.count(ChStatuses.FLAME), 9, "the second second skipped it")
	_complete()


func test_acid_eats_the_first_sand_cell() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, 100))
	p.statuses.stacks[ChStatuses.ACID] = 2
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [p])], world)
	assert_eq(world.fill_rect(Rect2i(97, 100, 6, 1), &"sand"), 6, "a row of sand in the rect")
	_tick(ctx)
	assert_eq(world.get_material_at(Vector2i(97, 100)), &"air", "the first sand cell is gone")
	assert_eq(world.get_material_at(Vector2i(98, 100)), &"sand", "and only that one")
	_complete()


func test_oil_drips_every_second_status_second() -> void:
	var world: PixelWorld = await make_world()
	var p := _part(0, Vector2(100, 100))
	p.statuses.stacks[ChStatuses.OIL] = 3
	var ctx := _ctx([_chariot(0, Vector2(300, 100), [p])], world)
	var under := Vector2i(99, 101)  # the first cell of the row under the 2x2 box at (99, 99)
	_tick(ctx)
	assert_eq(world.get_material_at(under), &"air", "no drip on the first status second")
	_tick(ctx)
	assert_eq(world.get_material_at(under), &"oil", "one drip on the second")
	_complete()
