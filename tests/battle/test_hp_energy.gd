extends ChTest

# Task 3: the one HP-loss path (lose_hp), heal and energy gain, the gain and decay stat hooks, and
# the Block events. Hand-made rigs with fake bodies, except the material blast, which needs a real
# chassis for ChHazards to push and measure.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const HP := 1000  # more than a TNT centre hit, so the arithmetic is never clamped
const TNT: int = ChHazards.SIZES[&"large"]["damage"]  # the HP a TNT (large) blast takes at its centre
const NEAR := Vector2(120, 140)
const FAR := Vector2(320, 140)
const STAT_FIXTURE := "res://tests/battle/fixtures/ch_fixture_stat.gd"  # the modify_stat/gain double


class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0


func _part(side: int, at: Vector2, size := Vector2i(4, 4)) -> ChPartRuntime:
	var p := ChPartRuntime.new()
	p.def = ChPartDef.new()
	p.def.size = size
	p.side = side
	p.integrity = 100
	p.body = FakeBody.new()
	p.body.global_position = at
	return p


func _chariot(side: int, at: Vector2, parts: Array, hp := 100) -> ChChariotRuntime:
	var c := ChChariotRuntime.new()
	c.side = side
	c.hp = hp
	c.body_def = ChBodyDef.new()
	c.body_def.size = Vector2i(4, 4)
	c.body_def.hp = hp
	c.energy = ChEnergy.new(0, 0)
	c.chassis = _track(PixelRigidBody.new())
	c.chassis.position = at
	for p in parts:
		c.parts.append(p)
	return c


# A context over `chariots`, with the HP_LOST events it emits kept.
func _ctx(chariots: Array) -> Array:
	var ctx := ChBattleContext.new()
	ctx.bus = ChEventBus.new()
	for c in chariots:
		ctx.chariots.append(c)
	var heard: Array = []
	ctx.bus.subscribe(self, ChEvent.HP_LOST, func(e: ChEvent): heard.append(e))
	return [ctx, heard]


# Wire a stat-fixture behaviour onto a part.
func _stat_behaviour(part: ChPartRuntime, mode: StringName) -> Object:
	var fixture = load(STAT_FIXTURE).new()
	fixture.mode = mode
	fixture.part = part
	part.behaviour = fixture
	return fixture


# --- The material blast needs the real builder ---------------------------------------------------

func _catalog() -> ChCatalog:
	var strut := ChPartDef.new()
	strut.id = &"strut"
	strut.integrity = 200
	strut.size = Vector2i(2, 2)
	strut.charges = -1
	var body := ChBodyDef.new()
	body.id = &"rig"
	body.hp = HP
	body.size = Vector2i(10, 6)
	body.slots = PackedVector2Array([Vector2(0, 0), Vector2(6, 0)])
	return ChCatalog.from_defs([strut] as Array[ChPartDef], [body] as Array[ChBodyDef])


func _rig(world: PixelWorld, catalog: ChCatalog, side: int, at: Vector2) -> ChChariotRuntime:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	layout.place([0] as Array[int], &"strut")
	layout.place([1] as Array[int], &"strut")
	return ChChariotBuilder.build(world, _parent(), layout, catalog, side, at, false)


func _fight() -> Dictionary:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock")
	var catalog := _catalog()
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = [_rig(world, catalog, 0, NEAR), _rig(world, catalog, 1, FAR)]
	var heard: Array = []
	ctx.bus.subscribe(self, ChEvent.HP_LOST, func(e: ChEvent): heard.append(e))
	return {"world": world, "ctx": ctx, "heard": heard}


func _blast(at: Vector2, radius: int) -> Dictionary:
	return {"position": Vector2i(at), "radius": radius, "power": 1.0, "material": &"tnt", "dig": 6}


func test_every_hp_loss_announces() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var mine: ChChariotRuntime = ctx.chariots[0]
	var theirs: ChChariotRuntime = ctx.chariots[1]
	var gun: ChPartRuntime = mine.parts[0]
	var heard: Array = f.heard

	ctx.deal_hit(gun, theirs.chassis, 10)
	assert_eq(heard.size(), 1, "the hit announced once")
	if heard.size() == 1:
		assert_eq(heard[0].data, {"amount": 10, "before": HP, "after": HP - 10, "cause": &"hit"},
			"the hit's HP_LOST")
		assert_eq(heard[0].source, gun, "the attacker is the source")
	heard.clear()

	ctx.hazards.apply(ctx, [_blast(theirs.chassis.global_position, 12)])
	assert_eq(heard.size(), 1, "the blast announced once")
	if heard.size() == 1:
		assert_eq(heard[0].data["cause"], &"blast", "the blast's cause")
		assert_eq(heard[0].data["amount"], TNT, "the blast's amount")
		assert_eq(heard[0].source, null, "a material blast has no source part")
	heard.clear()

	theirs.statuses.stacks[ChStatuses.FLAME] = 5
	ctx.tick(1.0, [0.0, 0.0])
	assert_eq(heard.size(), 1, "the body Flame announced once")
	if heard.size() == 1:
		assert_eq(heard[0].data["cause"], &"status", "the status cause")
		assert_eq(heard[0].data["amount"], 5, "the status amount")
	_complete()


func test_heal_caps() -> void:
	var c := _chariot(0, Vector2.ZERO, [], 90)
	c.body_def.hp = 100  # max_hp is the body's, so 90 of 100
	var made := _ctx([c])
	var ctx: ChBattleContext = made[0]
	var heard: Array = []
	ctx.bus.subscribe(self, ChEvent.HEALED, func(e: ChEvent): heard.append(e))
	assert_eq(ctx.heal(c, 20), 10, "heal answers what landed, capped at max_hp")
	assert_eq(c.hp, 100, "hp at max")
	assert_eq(heard.size(), 1, "one HEALED")
	if heard.size() == 1:
		assert_eq(heard[0].data, {"amount": 10}, "the amount that landed")
	assert_eq(ctx.heal(c, 5), 0, "a full chariot heals nothing")
	assert_eq(heard.size(), 1, "and announces nothing")
	_complete()


func test_gain_energy_caps_and_announces() -> void:
	var c := _chariot(0, Vector2.ZERO, [])
	c.energy = ChEnergy.new(10, 0)
	c.energy.value = 4.0
	var made := _ctx([c])
	var ctx: ChBattleContext = made[0]
	var heard: Array = []
	ctx.bus.subscribe(self, ChEvent.ENERGY_GAINED, func(e: ChEvent): heard.append(e))
	assert_near(ctx.gain_energy(c, 5.0), 5.0, 0.0001, "five landed")
	assert_near(c.energy.value, 9.0, 0.0001, "the pool holds 9")
	assert_near(ctx.gain_energy(c, 5.0), 1.0, 0.0001, "the cap keeps the rest out")
	assert_near(c.energy.value, 10.0, 0.0001, "the pool is at cap")
	assert_eq(heard.size(), 2, "both gains announced")
	if heard.size() == 2:
		assert_near(heard[0].data["amount"], 5.0, 0.0001, "the first amount")
		assert_near(heard[1].data["amount"], 1.0, 0.0001, "the capped amount")
	_complete()


func test_modify_gain_can_zero_a_gain() -> void:
	var p := _part(0, Vector2.ZERO)
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	var ctx: ChBattleContext = made[0]
	_stat_behaviour(p, &"zero_gain")
	ctx.setup_all()
	var gained: Array = []
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(e: ChEvent): gained.append(e))
	assert_eq(ctx.give_status(p, ChStatuses.BLOCK, 3), 0, "the hook zeroed the gain")
	assert_eq(p.statuses.count(ChStatuses.BLOCK), 0, "nothing was added")
	assert_eq(gained.size(), 0, "nothing was announced")
	_complete()


func test_gain_carries_cause() -> void:
	for cause in [&"part", &"cells", &"sparks", &"jump"]:
		var p := _part(0, Vector2.ZERO)
		var other := _part(0, Vector2(4, 0))
		var made := _ctx([_chariot(0, Vector2(1000, 1000), [p, other])])
		var ctx: ChBattleContext = made[0]
		var heard: Array = []
		ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(e: ChEvent): heard.append(e))
		var from: Object = other if cause == &"jump" else null
		ctx.give_status(p, ChStatuses.BLOCK, 1, 1, from, cause)
		assert_eq(heard.size(), 1, "%s announced once" % cause)
		if heard.size() == 1:
			assert_eq(heard[0].data["cause"], cause, "%s cause" % cause)
			assert_eq(heard[0].data["from"], from, "%s from" % cause)
	_complete()


func test_decay_amount_from_stat() -> void:
	var p := _part(0, Vector2.ZERO)
	p.statuses.stacks[ChStatuses.FREEZE] = 6
	var made := _ctx([_chariot(0, Vector2(1000, 1000), [p])])
	var ctx: ChBattleContext = made[0]
	_stat_behaviour(p, &"double_decay_freeze")
	ctx.setup_all()
	ctx.tick(1.0, [0.0])
	assert_eq(p.statuses.count(ChStatuses.FREEZE), 4, "the doubled decay_freeze takes 2")
	_complete()


func test_block_absorbed_names_attacker() -> void:
	var gun := _part(0, Vector2.ZERO)
	var target := _part(1, Vector2(500, 0))
	target.statuses.stacks[ChStatuses.BLOCK] = 40
	var foe := _chariot(1, Vector2(500, 500), [target], 200)
	var made := _ctx([_chariot(0, Vector2(0, 500), [gun]), foe])
	var ctx: ChBattleContext = made[0]
	var lost: Array = []
	var soaked: Array = []
	ctx.bus.subscribe(self, ChEvent.STATUS_LOST, func(e: ChEvent): lost.append(e))
	ctx.bus.subscribe(self, ChEvent.BLOCK_ABSORBED, func(e: ChEvent): soaked.append(e))
	ctx.deal_hit(gun, target.body, 100)
	assert_eq(foe.hp, 140, "40 Block soaked, 60 through")
	assert_eq(lost.size(), 1, "the last Block used up is lost")
	if lost.size() == 1:
		assert_eq(lost[0].data, {"status": ChStatuses.BLOCK, "attacker": gun}, "the attacker is named")
	assert_eq(soaked.size(), 1, "one BLOCK_ABSORBED")
	if soaked.size() == 1:
		assert_eq(soaked[0].data, {"amount": 40, "attacker": gun}, "what Block soaked, and who hit")
		assert_eq(soaked[0].source, target, "announced on the holder")
	_complete()


func test_block_mult_doubles_block_damage() -> void:
	var gun := _part(0, Vector2.ZERO)
	var target := _part(1, Vector2(500, 0))
	target.statuses.stacks[ChStatuses.BLOCK] = 40
	var foe := _chariot(1, Vector2(500, 500), [target], 200)
	var made := _ctx([_chariot(0, Vector2(0, 500), [gun]), foe])
	var ctx: ChBattleContext = made[0]
	ctx.deal_hit(gun, target.body, 10, {"block_mult": 2.0})
	assert_eq(target.statuses.count(ChStatuses.BLOCK), 20, "Block took the hit twice")
	assert_eq(foe.hp, 200, "and nothing reached HP")

	var plain_gun := _part(0, Vector2.ZERO)
	var plain_target := _part(1, Vector2(500, 0))
	plain_target.statuses.stacks[ChStatuses.BLOCK] = 40
	var plain_foe := _chariot(1, Vector2(500, 500), [plain_target], 200)
	var plain := _ctx([_chariot(0, Vector2(0, 500), [plain_gun]), plain_foe])
	var plain_ctx: ChBattleContext = plain[0]
	plain_ctx.deal_hit(plain_gun, plain_target.body, 10)
	assert_eq(plain_target.statuses.count(ChStatuses.BLOCK), 30, "one for one by default")
	_complete()