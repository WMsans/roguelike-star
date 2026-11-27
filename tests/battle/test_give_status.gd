extends ChTest

# give_status: stacks, events and Shock jumps. Fake bodies, world = null.


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


func _part(side: int, at: Vector2, size := Vector2i(4, 4)) -> ChPartRuntime:
	var p := ChPartRuntime.new()
	p.def = ChPartDef.new()
	p.def.size = size
	p.side = side
	p.integrity = 10
	p.body = FakeBody.new()
	p.body.global_position = at
	return p


func _chariot(side: int, at: Vector2, parts: Array) -> ChChariotRuntime:
	var c := ChChariotRuntime.new()
	c.side = side
	c.body_def = ChBodyDef.new()
	c.body_def.size = Vector2i(4, 4)
	c.chassis = _track(PixelRigidBody.new())
	c.chassis.position = at
	for p in parts:
		c.parts.append(p)
	return c


# The sink lists the events it heard, in order.
func _ctx(chariots: Array) -> Array:
	var ctx := ChBattleContext.new()
	ctx.bus = ChEventBus.new()
	for c in chariots:
		ctx.chariots.append(c)
	var heard: Array = []
	for type in [ChEvent.STATUS_GAINED, ChEvent.STATUS_LOST, ChEvent.STATUS_CANCELLED,
			ChEvent.STATUS_DOUBLED, ChEvent.SHOCK_JUMPED]:
		ctx.bus.subscribe(self, type, func(e: ChEvent): heard.append(e))
	return [ctx, heard]


func _row(wet_b := 0) -> Array:
	# A, B, C edge to edge, D far off, hull far off. Returns [ctx, heard, [A, B, C, D]].
	var a := _part(0, Vector2(0, 0))
	var b := _part(0, Vector2(4, 0))
	var c := _part(0, Vector2(8, 0))
	var d := _part(0, Vector2(28, 0))
	if wet_b > 0:
		b.statuses.stacks[ChStatuses.WET] = wet_b
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [a, b, c, d])])
	return [made[0], made[1], [a, b, c, d]]


func test_give_status_emits_gained_and_cancelled() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.WET] = 3
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	var heard: Array = made[1]
	assert_eq(made[0].give_status(p, ChStatuses.FLAME, 5), 2, "2 left after Wet")
	assert_eq(heard.size(), 3, "cancelled, gained, then the Wet that ran out")
	assert_eq(heard[0].type, ChEvent.STATUS_CANCELLED, "cancel first")
	assert_eq(heard[0].data, {"status": ChStatuses.FLAME, "against": ChStatuses.WET, "amount": 3}, "cancel data")
	assert_eq(heard[1].type, ChEvent.STATUS_GAINED, "gained second")
	assert_eq(heard[1].data, {"status": ChStatuses.FLAME, "amount": 2, "before": 0, "cause": &"part",
		"from": null}, "gained data")
	assert_eq(heard[1].source, p, "source is the holder")
	assert_eq(heard[2].type, ChEvent.STATUS_LOST, "lost third")
	assert_eq(heard[2].data, {"status": ChStatuses.WET}, "the Wet is gone")
	_complete()


func test_flame_cancelling_the_last_freeze_thaws() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.FREEZE] = 2
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	made[0].give_status(p, ChStatuses.FLAME, 5)
	var heard: Array = made[1]
	assert_eq(heard.size(), 3, "cancelled, gained, lost")
	assert_eq(heard[-1].type, ChEvent.STATUS_LOST, "lost last")
	assert_eq(heard[-1].data, {"status": ChStatuses.FREEZE}, "the Freeze")
	assert_true(ChEvent.thawed(heard[-1]), "reads as a thaw")
	_complete()


func test_doubling_the_last_oil_loses_it() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.OIL] = 2
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	made[0].give_status(p, ChStatuses.FLAME, 5)
	var heard: Array = made[1]
	assert_eq(heard.size(), 3, "doubled, gained, lost")
	assert_eq(heard[-1].type, ChEvent.STATUS_LOST, "lost last")
	assert_eq(heard[-1].data, {"status": ChStatuses.OIL}, "the Oil")
	_complete()


func test_give_status_emits_doubled() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.OIL] = 2
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	made[0].give_status(p, ChStatuses.FLAME, 5)
	var heard: Array = made[1]
	assert_eq(heard[0].type, ChEvent.STATUS_DOUBLED, "doubled")
	assert_eq(heard[0].data["amount"], 2, "by the Oil")
	_complete()


func test_shock_jumps_half_to_touching() -> void:
	var r := _row()
	var p: Array = r[2]
	r[0].give_status(p[0], ChStatuses.SHOCK, 6)
	assert_eq(p[0].statuses.count(ChStatuses.SHOCK), 6, "A keeps 6")
	assert_eq(p[1].statuses.count(ChStatuses.SHOCK), 3, "B gets half")
	assert_eq(p[2].statuses.count(ChStatuses.SHOCK), 0, "C is two hops away")
	assert_eq(p[3].statuses.count(ChStatuses.SHOCK), 0, "D is far")
	_complete()


func test_wet_part_passes_shock_one_more_hop() -> void:
	var r := _row(1)
	var p: Array = r[2]
	r[0].give_status(p[0], ChStatuses.SHOCK, 8)
	assert_eq(p[0].statuses.count(ChStatuses.SHOCK), 8, "A gains nothing back")
	assert_eq(p[1].statuses.count(ChStatuses.SHOCK), 4, "B gets 4")
	assert_eq(p[2].statuses.count(ChStatuses.SHOCK), 2, "C gets 2")
	var heard: Array = r[1]
	var jumped := heard.find_custom(func(e: ChEvent): return e.type == ChEvent.SHOCK_JUMPED and e.source == p[1])
	var gained := heard.find_custom(func(e: ChEvent): return e.type == ChEvent.STATUS_GAINED and e.source == p[1])
	assert_true(jumped >= 0 and jumped < gained, "JUMPED(A->B) comes before B's own GAINED")
	if jumped >= 0:
		assert_eq(heard[jumped].data, {"from": p[0], "amount": 4}, "jumped data")
	_complete()


func test_shock_on_wet_cluster_stops_after_two_hops() -> void:
	var grid: Array = []
	for y in 3:
		for x in 3:
			var p := _part(0, Vector2(x * 4, y * 4))
			p.statuses.stacks[ChStatuses.WET] = 1
			grid.append(p)
	var made := _ctx([_chariot(0, Vector2(1000, 1000), grid)])
	made[0].give_status(grid[4], ChStatuses.SHOCK, 64)
	assert_eq(grid[4].statuses.count(ChStatuses.SHOCK), 64, "nothing jumps back to the centre")
	var jumps := 0
	for e in made[1]:
		if e.type == ChEvent.SHOCK_JUMPED:
			jumps += 1
			assert_true(e.data["amount"] == 32 or e.data["amount"] == 16, "only two hops")
	assert_true(jumps > 0, "it did jump")
	assert_true(not made[0].bus.capped, "the bus never hit its cap")
	_complete()


func test_body_touches_mounted_parts() -> void:
	var p := _part(0, Vector2(4, 0))
	var c := _chariot(0, Vector2(0, 0), [p])
	var made := _ctx([c])
	assert_true(made[0].touching(c).has(p), "part touches the hull")
	assert_true(made[0].touching(p).has(c), "hull touches the part")
	assert_eq(c.status_box(), Rect2(-2, -2, 4, 4), "hull box")
	_complete()


func test_give_status_ignores_broken_null_and_zero() -> void:
	var p := _part(0, Vector2.ZERO)
	var q := _part(0, Vector2(4, 0))
	q.broken = true
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p, q])])
	assert_eq(made[0].give_status(q, ChStatuses.FLAME, 5), 0, "broken")
	assert_eq(made[0].give_status(null, ChStatuses.FLAME, 5), 0, "null")
	assert_eq(made[0].give_status(p, ChStatuses.FLAME, 0), 0, "zero")
	assert_eq(made[1].size(), 0, "no events")
	_complete()


func test_shock_on_chariot_with_freed_chassis() -> void:
	var a := _part(0, Vector2(0, 0))
	var b := _part(0, Vector2(4, 0))
	var c := _chariot(0, Vector2(1000, 1000), [a, b])
	c.anchor_world()  # cache the last reading
	c.chassis.free()
	var made := _ctx([c])
	assert_eq(made[0].give_status(a, ChStatuses.SHOCK, 6), 6, "no crash on a freed chassis")
	assert_eq(a.statuses.count(ChStatuses.SHOCK), 6, "A holds 6")
	assert_eq(b.statuses.count(ChStatuses.SHOCK), 3, "B still gets half")
	c.chassis = null
	assert_eq(c.anchor_world(), Vector2(1000, 1000), "null chassis keeps the cached anchor")
	_complete()
