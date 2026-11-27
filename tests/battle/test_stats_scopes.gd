extends ChTest

# Task 2: the stat hook (modify_stat / ctx.stat), the refreshed cost/rate/cooldown fields, scopes
# through ctx.near, bonus_damage, BATTLE_STARTED and pay_trigger. World-backed rigs from the real
# builder, as test_context.gd does, with the fixture behaviours under tests/battle/fixtures/.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # near the surface, per Task 9's spawn ruling
const TICK := 1.0 / 60.0  # one 60 fps frame
const BODY_HP := 100  # every rig's HP
const STAT_FIXTURE := "res://tests/battle/fixtures/ch_fixture_stat.gd"  # the modify_stat double

# A fake body, the way test_enemy_ai.gd builds them: the AI tests measure from the part, so a rig
# needs no chassis or joints to be asked.
class FakeBody:
	var global_position: Vector2 = Vector2.ZERO
	var global_rotation: float = 0.0

# A hit modifier that doubles the multiplier, to tell "(damage + bonus) x multiplier" from
# "damage x multiplier + bonus".
class DoubleHit:
	extends ChBehaviour

	func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
		hit["multiplier"] = 2.0

# One body def with slots at `positions`; the fixtures mount parts at slot index in order.
func _body(positions: PackedVector2Array, cap: float = 20.0) -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = BODY_HP
	def.energy_cap = cap
	def.energy_regen = 0.0
	def.size = Vector2i(10, 6)
	def.slots = positions
	return def

# One part def with the numbers a test needs.
func _part(id: StringName, cost: int, cooldown: float, mode: StringName,
		range_: float = 0.0, per_second: float = 0.0) -> ChPartDef:
	var def := ChPartDef.new()
	def.id = id
	def.energy_cost = cost
	def.cooldown = cooldown
	def.mode = mode
	def.damage = 10
	def.integrity = 100
	def.size = Vector2i(2, 2)
	def.charges = -1
	def.proximity_range = range_
	def.energy_per_second = per_second
	return def

func _catalog(defs: Array[ChPartDef], body: ChBodyDef) -> ChCatalog:
	return ChCatalog.from_defs(defs, [body])

# One layout mounting [[path, part_id]] in mount order; place() takes Array[int].
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout

func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps

# The part the builder put at a layout path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null

# A chariot with these parts and a pool holding `value` of `cap` (pure: no world, no joints).
func _rig(parts: Array[ChPartRuntime], cap: float, value: float) -> ChChariotRuntime:
	var rig := ChChariotRuntime.new()
	rig.parts = parts
	rig.energy = ChEnergy.new(cap, 0.0)
	rig.energy.value = value
	return rig

# A spear for the AI edge test: 10 cells long, reach 24, cost 1, ready at once.
func _spear_part(at: Vector2, flipped: bool = false) -> ChPartRuntime:
	var def := ChPartDef.new()
	def.id = &"spear"
	def.size = Vector2i(10, 1)
	def.reach = 24.0
	def.energy_cost = 1
	def.cooldown = 1.0
	def.mode = ChPartDef.MODE_COOLDOWN
	def.charges = -1
	var part := ChPartRuntime.new()
	part.def = def
	part.charges_left = -1
	part.cooldown_left = 0.0
	part.cost = 1
	part.flipped = flipped
	part.body = FakeBody.new()
	part.body.global_position = at
	return part

# The floor the chariots stand on; fill_rect returns the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")

# A battle context over `rigs` (index = side): setup_all() is the single place every behaviour gets
# setup, so it caches the modify_stat behaviours and wires the bus's near helper.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = rigs
	ctx.setup_all()
	return ctx

# Wire a stat-fixture behaviour onto a part.
func _stat_behaviour(part: ChPartRuntime, mode: StringName) -> Object:
	var fixture = load(STAT_FIXTURE).new()
	fixture.mode = mode
	fixture.part = part
	part.behaviour = fixture
	return fixture

func test_stat_folds_both_sides_in_mount_order() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var gun := _part(&"gun", 2, 1.0, ChPartDef.MODE_COOLDOWN)
	var plus := _part(&"plus", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var double := _part(&"double", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var catalog := _catalog([gun, plus, double], _body(PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0)])))
	var player := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"gun"], [[1], &"plus"]]), catalog, 0, ORIGIN, false)
	var enemy := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"double"]]), catalog, 1, Vector2(320, 140), false)
	var gun_part := _part_of(player, [0])
	var plus_part := _part_of(player, [1])
	var double_part := _part_of(enemy, [0])
	assert_true(gun_part != null and plus_part != null and double_part != null, "the three parts mounted")
	_stat_behaviour(plus_part, &"add")
	_stat_behaviour(double_part, &"double")
	var rigs: Array[ChChariotRuntime] = [player, enemy]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	# (base + 1) x 2: the add on side 0 runs first, the double on side 1 second.
	assert_eq(ctx.stat(gun_part, ChBattleContext.STAT_ENERGY_COST, 2.0), 6.0, "the stat folds both sides in mount order")
	_complete()

func test_broken_part_stops_modifying() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var gun := _part(&"gun", 2, 1.0, ChPartDef.MODE_COOLDOWN)
	var plus := _part(&"plus", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var double := _part(&"double", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var catalog := _catalog([gun, plus, double], _body(PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0)])))
	var player := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"gun"], [[1], &"plus"], [[2], &"double"]]), catalog, 0, ORIGIN, false)
	var gun_part := _part_of(player, [0])
	var double_part := _part_of(player, [2])
	assert_true(gun_part != null and double_part != null, "the gun and its doubler mounted")
	var plus_part := _part_of(player, [1])
	_stat_behaviour(plus_part, &"add")
	_stat_behaviour(double_part, &"double")
	var rigs: Array[ChChariotRuntime] = [player]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	assert_eq(ctx.stat(gun_part, ChBattleContext.STAT_ENERGY_COST, 2.0), 6.0, "both modifiers fold while unbroken")
	double_part.broken = true
	assert_eq(ctx.stat(gun_part, ChBattleContext.STAT_ENERGY_COST, 2.0), 3.0, "breaking the doubler falls back to base + 1")
	_complete()

func test_volley_pays_the_modified_cost() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var gun := _part(&"gun", 2, 1.0, ChPartDef.MODE_COOLDOWN)
	var plus := _part(&"plus", 0, 0.0, ChPartDef.MODE_PASSIVE)  # passive: never in the volley
	var catalog := _catalog([gun, plus], _body(PackedVector2Array([Vector2(0, 0), Vector2(6, 0)]), 2.0))
	var rig := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"gun"], [[1], &"plus"]]), catalog, 0, ORIGIN, false)
	var gun_part := _part_of(rig, [0])
	var plus_part := _part_of(rig, [1])
	assert_true(gun_part != null and plus_part != null, "both parts mounted")
	gun_part.cooldown_left = 0.0  # ready at once
	_stat_behaviour(plus_part, &"add")  # the gun's cost becomes 3
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var skipped: Array[ChEvent] = []
	var sink := skipped
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_SKIPPED, func(event: ChEvent): sink.append(event))
	var fired := ctx.tick(TICK, [0.0], [true])
	assert_eq(fired, [0], "the 3-energy gun does not fit the 2-energy pool")
	assert_eq(skipped.size(), 1, "exactly one part is announced as skipped")
	if skipped.size() == 1:
		assert_true(skipped[0].source == gun_part, "the gun is the one the pool refused")
		assert_eq(skipped[0].data.get("cost"), 3, "and the payload carries the modified cost")
	_complete()

func test_cooldown_resets_to_modified_cooldown() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var gun := _part(&"gun", 2, 1.0, ChPartDef.MODE_COOLDOWN)
	var double := _part(&"double", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var catalog := _catalog([gun, double], _body(PackedVector2Array([Vector2(0, 0), Vector2(6, 0)]), 100.0))
	var rig := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"gun"], [[1], &"double"]]), catalog, 0, ORIGIN, false)
	var gun_part := _part_of(rig, [0])
	var double_part := _part_of(rig, [1])
	assert_true(gun_part != null and double_part != null, "both parts mounted")
	_stat_behaviour(double_part, &"double_cooldown")  # the gun's cooldown becomes 2 s
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var fired := [0]
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(_event: ChEvent): fired[0] += 1)
	gun_part.cooldown_left = 0.0  # ready at once on the first press
	ctx.tick(TICK, [0.0], [true])
	assert_near(gun_part.cooldown_left, 2.0, 0.01, "each fire resets to the modified cooldown")
	for _tick in 299:  # 5 s in all: fires at 0, 2 and 4 s on the modified 2 s cooldown
		ctx.tick(TICK, [0.0], [true])
	assert_eq(fired[0], 3, "three fires in 5 s on the modified 2 s cooldown")
	_complete()

func test_front_and_back_follow_facing() -> void:
	var positions := PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0)])
	var body := _body(positions)
	var defs: Array[ChPartDef] = [_part(&"a", 0, 0.0, ChPartDef.MODE_PASSIVE), _part(&"b", 0, 0.0, ChPartDef.MODE_PASSIVE),
		_part(&"c", 0, 0.0, ChPartDef.MODE_PASSIVE)]
	var catalog := _catalog(defs, body)
	var world: PixelWorld = await make_world()
	_ground(world)
	var player := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"a"], [[1], &"b"], [[2], &"c"]]), catalog, 0, ORIGIN, false)
	var enemy := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"a"], [[1], &"b"], [[2], &"c"]]).mirrored(), catalog, 1, Vector2(320, 140), true)
	var a := _part_of(player, [0])
	var b := _part_of(player, [1])
	var c := _part_of(player, [2])
	assert_true(a != null and b != null and c != null, "the three parts mounted")
	for part in player.parts:
		part.behaviour = ChBehaviour.new()
		part.behaviour.part = part
	for part in enemy.parts:
		part.behaviour = ChBehaviour.new()
		part.behaviour.part = part
	var rigs: Array[ChChariotRuntime] = [player, enemy]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	# Unflipped: b faces +x, so c is ahead and a behind.
	assert_eq(b.behaviour._front_part(ctx), c, "the front is the nearest neighbour ahead of facing")
	assert_eq(b.behaviour._back_part(ctx), a, "and the back is the nearest neighbour behind it")
	# Flipped: facing reverses and the scopes swap.
	b.flipped = true
	assert_eq(b.behaviour._front_part(ctx), a, "flipped: the old back is now in front")
	assert_eq(b.behaviour._back_part(ctx), c, "flipped: the old front is now behind")
	b.flipped = false
	# On the mirrored side-1 chariot the answers match the unmirrored one.
	var eb := _part_of(enemy, [1])
	var ec := _part_of(enemy, [2])
	var ea := _part_of(enemy, [0])
	assert_true(eb != null and ec != null and ea != null, "the mirrored rig mounted the same parts")
	assert_eq(eb.behaviour._front_part(ctx), ec, "mirrored side 1: front matches the unmirrored rig")
	assert_eq(eb.behaviour._back_part(ctx), ea, "mirrored side 1: back matches the unmirrored rig")
	_complete()

func test_neighbours_stop_at_range() -> void:
	var positions := PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0), Vector2(18, 0)])
	var p0 := _part(&"p0", 0, 0.0, ChPartDef.MODE_PASSIVE, 12.0)  # proximity_range 12
	var p1 := _part(&"p1", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var p2 := _part(&"p2", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var p3 := _part(&"p3", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var catalog := _catalog([p0, p1, p2, p3], _body(positions))
	var world: PixelWorld = await make_world()
	_ground(world)
	var rig := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"p0"], [[1], &"p1"], [[2], &"p2"], [[3], &"p3"]]), catalog, 0, ORIGIN, false)
	var parts := [_part_of(rig, [0]), _part_of(rig, [1]), _part_of(rig, [2]), _part_of(rig, [3])]
	assert_true(!parts.has(null), "all four parts mounted")
	for part in parts:
		part.behaviour = ChBehaviour.new()
		part.behaviour.part = part
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var neighbours = parts[0].behaviour._neighbours(ctx)
	assert_eq(neighbours.size(), 2, "range 12 reaches the parts 6 and 12 cells away")
	assert_true(neighbours.has(parts[1]), "the part 6 cells away is a neighbour")
	assert_true(neighbours.has(parts[2]), "the part 12 cells away is a neighbour (in range)")
	assert_true(!neighbours.has(parts[3]), "the part 18 cells away is not (out of range)")
	_complete()

func test_battle_started_once() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog([_part(&"strut", 0, 0.0, ChPartDef.MODE_PASSIVE)], _body(PackedVector2Array([Vector2(0, 0)])))
	var rig := ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 0, ORIGIN, false)
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var started := []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.BATTLE_STARTED, func(_event: ChEvent): started.append(1))
	for _tick in 10:
		ctx.tick(TICK, [0.0])
	assert_eq(started.size(), 1, "the first tick emits BATTLE_STARTED once, before anything else")
	_complete()

func test_bonus_damage_adds_before_multiplier() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var source_def := _part(&"source", 0, 0.0, ChPartDef.MODE_PASSIVE)
	var catalog := _catalog([source_def], _body(PackedVector2Array([Vector2(0, 0)])))
	var source_rig := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"source"]]), catalog, 0, ORIGIN, false)
	var enemy_rig := ChChariotBuilder.build(world, _parent(),
		_mount([]), catalog, 1, Vector2(320, 140), false)
	var source := _part_of(source_rig, [0])
	assert_true(source != null, "the source part mounted")
	source.bonus_damage = 4
	source.behaviour = DoubleHit.new()
	source.behaviour.part = source
	var rigs: Array[ChChariotRuntime] = [source_rig, enemy_rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	ctx.deal_hit(source, enemy_rig.chassis, 10, {})
	assert_eq(enemy_rig.hp, BODY_HP - 28, "(damage + bonus) x multiplier: (10 + 4) x 2 = 28 off the hull")
	_complete()

func test_pay_trigger_refuses_without_energy() -> void:
	var def := _part(&"gun", 5, 1.0, ChPartDef.MODE_COOLDOWN)
	var part := ChPartRuntime.new()
	part.def = def
	part.charges_left = -1
	part.cooldown_left = 0.0
	part.cost = 5
	part.side = 0
	var rig := _rig([part], 10.0, 0.0)  # empty pool: a triggered passive cannot pay
	var ctx := ChBattleContext.new()
	var rigs: Array[ChChariotRuntime] = [rig]
	ctx.chariots = rigs
	assert_true(not ctx.pay_trigger(part, 5), "an empty pool refuses")
	rig.energy.value = 10.0
	assert_true(ctx.pay_trigger(part, 5), "a full pool pays the modified cost")
	assert_near(rig.energy.value, 5.0, 0.001, "and the pool paid")
	_complete()

func test_ai_reach_is_from_the_edge_and_forward() -> void:
	var part := _spear_part(Vector2(100.0, 0.0))  # 10 long, reach 24, edge at 105 facing +x
	var rig := _rig([part], 20.0, 1.0)  # below cap, above 60% of cost 1: reach decides
	assert_true(ChEnemyAI.should_press(rig, 128.0, 5.0), "28 cells ahead of the anchor is 23 from the edge: in reach")
	assert_true(not ChEnemyAI.should_press(rig, 72.0, 5.0), "28 cells behind the anchor is out of reach")
	part.flipped = true  # facing -x: the target ahead of the anchor is now behind the part
	assert_true(not ChEnemyAI.should_press(rig, 128.0, 5.0), "only targets on the facing side count")
	_complete()
