extends ChTest

# Task 12: the first weapons actually working. World-backed and on the real defs, so the
# behaviour scripts the .tres files name are the ones under test rather than a double.
# The reach test is geometric (the brief's ruling: reach comes from def.proximity_range), so the
# rigs stay where ChChariotBuilder put them, as in tests/battle/test_context.gd: no world.step in
# the reach tests, since nothing drives them and a settle would move the anchors the box measures.
# shortcut: rig numbers are literals per def below; the slice's weapon tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # near the floor: a drop faster than this tunnels the bodies (Task 9)
const IN_REACH := 12  # origins this far apart put the enemy's front part inside a 6-cell reach
const APART := 20  # the brief's setup: a 6-cell mace cannot reach across this gap
const TICK := 1.0 / 60.0
const MACE_TICKS := 62  # 1.03 s: ChChariotBuilder starts a part at def.cooldown, so a 1 s cooldown goes ready here
const SAW_TICKS := 40  # 0.66 s: the saw's 0.5 s cooldown gets one fire, not a second
const FREEZE_HIT := 0.5  # the Freeze Charge's freeze per hit, twice of which fills the meter
const BATTERY_GAIN := 3.0  # ember_battery's energy per CAUGHT_FIRE
const ENERGY_TICKS := 10  # 0.166 s of ticks: inside the battery's 0.5 s cooldown
const PAST_TICKS := 30  # 0.5 s of ticks: enough for the battery's cooldown to go ready

# The rig body every test's chariot sits on: a 10x6 hull with four slots, so the distances the
# reach and range tests read are slot numbers. Slots 0 and 1 are the hull's two ends 10 cells apart
# (inside the Freeze Charge's 24-cell reach); slot 3 hangs 25 from slot 0, outside it.
func _rig() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = 100
	def.energy_cap = 20
	def.energy_regen = 0.0
	def.size = Vector2i(10, 6)
	def.slots = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(0, -3), Vector2(-30, -3)])
	return def

# The real defs from res://game/data/parts under that rig body, so a build reads the weapon numbers
# off the .tres (proximity_range as reach, damage, cooldown) and gets the behaviour the .tres names.
func _catalog() -> ChCatalog:
	var loaded := ChCatalog.load_default()
	var defs: Array[ChPartDef] = []
	for id in [&"ice_cream_mace", &"cutter_chainsaw", &"freeze_charge", &"ember_battery", &"wheel", &"strut"]:
		var def: ChPartDef = loaded.part(id)
		assert_true(def != null, "%s loads from res://game/data/parts" % id)
		defs.append(def)
	var catalog := ChCatalog.from_defs(defs, [_rig()])
	for pair in [[&"ice_cream_mace", true], [&"cutter_chainsaw", true], [&"freeze_charge", true], [&"ember_battery", true], [&"wheel", false], [&"strut", false]]:
		var has: bool = catalog.part(pair[0]).behaviour != null
		assert_eq(has, pair[1], "%s behaviour is%s as the .tres stand" % [pair[0], "" if pair[1] else " left out"])
	return catalog

# A build from [[path, part_id]] in mount order on the rig body; place() takes Array[int].
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

# The node the builder hangs bodies under; the arena lives in root space.
func _parent() -> Node2D:
	var parent := Node2D.new()
	Engine.get_main_loop().get_root().add_child(parent)
	return parent

# The part the builder put at a layout path; runtime.parts keeps every part's own path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null

# A battle over both sides, with every mounted behaviour getting the setup call that subscribes it.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = rigs
	for rig in rigs:
		for part in rig.parts:
			if part.behaviour != null:
				part.behaviour.setup(ctx)
	return ctx

# The rock floor the chariots stand on; fill_rect returns the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")

# The mace's reach box is the def's proximity_range (6 cells) x the part's height, out along facing()
# from the part's edge. In reach: origins 12 apart, so the foe's body (x 136.5 .. 137.5) and its
# chassis (x 127 .. 137) both overlap the box and the nearer body takes the hit. Out of reach: the
# brief's 20 apart, where the box stops at x = 131.5 and nothing of the foe reaches it.
func test_mace_hits_in_reach_only() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"ice_cream_mace"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(IN_REACH, 0), false)
	var mace := _part_of(at, [1])
	var foe_part := _part_of(foe, [0])
	assert_true(mace != null and foe_part != null, "the mace and the foe's part both mounted")
	assert_true(mace.behaviour != null, "the mace's def carries its behaviour script")
	assert_near(mace.anchor_world().x + mace.def.proximity_range, 131.0, 0.001, "reach is the def's proximity_range in cells")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChPartRuntime] = []
	var sink := hits
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): sink.append(event.data["target_part"]))
	var foe_hp := foe.hp
	# ChChariotBuilder starts a part at def.cooldown, so the 1 s countdown runs over these ticks: the mace
	# gets one payment, one fire and one landed hit, and its second fire would need another full second.
	for _tick in MACE_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
	assert_eq(hits.size(), 1, "one fire, one landed hit")
	assert_true(hits[0] == foe_part, "on the foe's part, the nearest body in the box")
	assert_eq(foe.hp, foe_hp - mace.def.damage, "an unfrozen target takes the plain damage")
	assert_eq(foe_part.integrity, foe_part.def.integrity - 10, "and the part wore ChDamage's half damage")
	# The same rigs 20 apart: the box stops at x = 131.5 while the foe's chassis starts at 135, so the
	# fire lands nothing. The energy went to the fire either way, which ChBattleContext's own tests
	# cover, so what this test pins is that a swing out of reach pays no HP and announces no HIT.
	var far_at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"ice_cream_mace"]]), catalog, 0, ORIGIN, false)
	var far_foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var far_mace := _part_of(far_at, [1])
	var far_foe_part := _part_of(far_foe, [0])
	assert_true(far_mace != null and far_foe_part != null, "the out-of-reach pair mounted")
	var far_rigs: Array[ChChariotRuntime] = [far_at, far_foe]
	var far_ctx: ChBattleContext = _battle(world, catalog, far_rigs)
	var far_hits: Array[ChPartRuntime] = []
	var far_sink := far_hits
	far_ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): far_sink.append(event.data["target_part"]))
	var far_hp := far_foe.hp
	for _tick in MACE_TICKS:
		far_ctx.tick(TICK, [0.0, 0.0])
	assert_true(far_foe_part.anchor_world().x > far_mace.anchor_world().x + far_mace.def.proximity_range, "the foe sits past the box")
	assert_eq(far_hits, [], "so the fire landed nothing")
	assert_eq(far_foe.hp, far_hp, "and paid no HP")
	_complete()

# The Mace's Shatter: its own modify_hit reads the target off the hit dict, so a frozen target takes
# ChDamage's x3 (20 damage -> 60 HP) and loses its freeze. The wear keeps the multiplier off, per
# ChDamage's own rule, so the part still wears 10.
# shortcut: fire is called directly rather than through ctx.tick: paying the cost and resetting the
# cooldown is ChBattleContext's, already pinned by test_context.gd, and is not what this asserts.
func test_mace_shatters_frozen() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"ice_cream_mace"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(IN_REACH, 0), false)
	var mace := _part_of(at, [1])
	var foe_part := _part_of(foe, [0])
	assert_true(mace != null and foe_part != null and mace.behaviour != null, "the mace and its foe mounted, mace behaving")
	foe_part.freeze = 1.0
	assert_true(foe_part.is_frozen(), "a full meter is frozen")
	var ctx: ChBattleContext = _battle(world, catalog, [at, foe])
	var thawed: Array[ChEvent] = []
	var sink := thawed
	ctx.bus.subscribe(RefCounted.new(), ChEvent.THAWED, func(event: ChEvent): sink.append(event))
	var foe_hp := foe.hp
	mace.behaviour.fire(ctx)
	assert_eq(foe.hp, foe_hp - 3 * mace.def.damage, "the shatter costs 60 HP: 20 damage times x3")
	assert_near(foe_part.freeze, 0.0, 0.0001, "and ends the target's freeze")
	assert_true(foe_part.is_frozen() == false, "so the target is thawed")
	assert_eq(thawed.size(), 1, "and the shatter announced one THAWED")
	assert_eq(foe_part.integrity, foe_part.def.integrity - 10, "while the part wore the unmultiplied half")
	_complete()

# The Freeze Charge is passive: it adds hit["freeze"] to a hit from a same-side part inside its 24
# cells, and ChBattleContext puts that freeze on the part hit. Two hits of 0.5 fill the meter, so the
# enemy's wheel freezes and ChChariotRuntime.drive takes its motor off.
# shortcut: deal_hit is called directly twice rather than over a cooldown: the freeze per hit is the
# rule here, and a tick-driven fire would add the energy queue without adding what is asserted.
func test_freeze_charge_freezes_wheel() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"ice_cream_mace"], [[1], &"freeze_charge"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"wheel"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var mace := _part_of(at, [0])
	var charge := _part_of(at, [1])
	var wheel := _part_of(foe, [0])
	assert_true(mace != null and charge != null and wheel != null, "the mace, the charge and the wheel mounted")
	assert_true(charge.behaviour != null, "the charge's def names its behaviour script")
	assert_near(charge.anchor_world().distance_to(mace.anchor_world()), 10.0, 0.001, "the charge sits inside its 24-cell reach")
	var ctx: ChBattleContext = _battle(world, catalog, [at, foe])
	var wheel_hp := foe.hp
	# Two hits from the same mace, so the charge is asked both times and the meter fills by 0.5 each.
	for _two in 2:
		ctx.deal_hit(mace, wheel.body, mace.def.damage)
	assert_near(wheel.freeze, 2 * FREEZE_HIT, 0.0001, "two hits of 0.5 fill the meter")
	assert_true(wheel.is_frozen(), "a full meter freezes the wheel")
	assert_eq(foe.hp, wheel_hp - 2 * mace.def.damage, "neither hit was multiplied: the wheel was not frozen when either landed")
	assert_eq(wheel.integrity, wheel.def.integrity - 20, "and the wheel wore the wear of both hits")
	foe.drive(1.0)
	assert_true(not wheel.joint.enable_motor, "the frozen wheel's motor is off")
	assert_near(wheel.joint.motor_speed, 0.0, 0.0001, "and carries no speed")
	_complete()

# The same charge mounted 25 cells from the mace, outside its own 24-cell reach: deal_hit never asks
# it, so the hit carries no freeze, the wheel stays unfrozen and its motor runs.
func test_freeze_charge_out_of_range_no_effect() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"ice_cream_mace"], [[3], &"freeze_charge"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"wheel"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var mace := _part_of(at, [0])
	var charge := _part_of(at, [3])
	var wheel := _part_of(foe, [0])
	assert_true(mace != null and charge != null and wheel != null, "the mace, the charge and the wheel mounted")
	assert_near(charge.anchor_world().distance_to(mace.anchor_world()), 25.0, 0.001, "the charge sits outside its 24-cell reach")
	var ctx: ChBattleContext = _battle(world, catalog, [at, foe])
	var foe_hp := foe.hp
	for _two in 2:
		ctx.deal_hit(mace, wheel.body, mace.def.damage)
	assert_near(wheel.freeze, 0.0, 0.0001, "so the hit carries no freeze")
	assert_true(not wheel.is_frozen(), "and the wheel stays unfrozen")
	assert_eq(foe.hp, foe_hp - 2 * mace.def.damage, "the hits cost plain damage, x1")
	foe.drive(1.0)
	assert_true(wheel.joint.enable_motor, "so the wheel's motor runs")
	assert_near(wheel.joint.motor_speed, 12.0, 0.0001, "at ChChariotRuntime.MOTOR_SPEED")
	_complete()

# A hand-built CAUGHT_FIRE in ChPartRuntime._emit's shape: side, source and position are what the
# bus's proximity filter reads, and the battery subscribes with no range, so it hears either side.
func _catch_fire(ctx: ChBattleContext, part: ChPartRuntime) -> void:
	var event := ChEvent.new()
	event.type = ChEvent.CAUGHT_FIRE
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	ctx.bus.emit(event)

# The Ember Battery subscribes to CAUGHT_FIRE with no proximity, so a fire on either chariot buys
# its own chariot 3 energy (clamped to the cap) and announces ENERGY_GAINED. The first catch is the
# real one - ChPartRuntime.apply_sample over fire cells is what emits it - and it comes from the ENEMY
# side. The second catch, hand-built 10 ticks (0.166 s) later, is inside the 0.5 s cooldown, so it
# buys nothing. Past the cooldown a catch from the battery's own side buys again.
func test_ember_battery_gains_on_any_caught_fire() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"ember_battery"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var battery := _part_of(at, [0])
	var burner := _part_of(foe, [0])
	assert_true(battery != null and burner != null, "the battery and the burning part mounted")
	# The pool starts at cap, so a gain would be invisible there: spend it first, then watch the gain.
	at.energy.value = 10.0
	var ctx: ChBattleContext = _battle(world, catalog, [at, foe])
	var gained: Array[ChEvent] = []
	var sink := gained
	ctx.bus.subscribe(RefCounted.new(), ChEvent.ENERGY_GAINED, func(event: ChEvent): sink.append(event))
	# The fire is a real fill over the foe's part, so apply_sample's not-burning to burning transition
	# emits the CAUGHT_FIRE the battery hears, with the foe's side and source on it.
	world.fill_circle(Vector2i(burner.anchor_world()), 3, &"fire")
	for _tick in ENERGY_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
	assert_near(at.energy.value, 13.0, 0.0001, "the enemy's catch bought 3 energy")
	assert_eq(gained.size(), 1, "one ENERGY_GAINED")
	# A second catch 0.166 s later, inside the battery's 0.5 s cooldown: it buys nothing and announces
	# nothing, which is the brief's second half of the rule.
	_catch_fire(ctx, burner)
	assert_near(at.energy.value, 13.0, 0.0001, "the second catch inside 0.5 s bought nothing")
	assert_eq(gained.size(), 1, "and announced no gain")
	# Past the cooldown a catch on the battery's own side buys again, and the cap is where it lands:
	# the pool sits 2 below cap, so the gain is clamped rather than spent in full.
	for _tick in PAST_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
	at.energy.value = 18.0
	_catch_fire(ctx, battery)
	assert_near(at.energy.value, 20.0, 0.0001, "so the gain clamps to the cap")
	assert_eq(gained.size(), 2, "and the gain announced itself")
	_complete()

# The Chainsaw cuts what is in its 14-cell reach: a landed hit announces CELLS_CUT and reports the
# fire sparks it threw (spawn_particles's pooled count), and it pays the plain 20 damage.
# With nothing of the enemy inside the box and solid ground at the tip, the cut goes to the terrain:
# explode(tip, 2, 50) digs, and CELLS_CUT still announces the cut.
func test_chainsaw_sparks_emit_cells_cut() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"cutter_chainsaw"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var saw := _part_of(at, [1])
	var foe_part := _part_of(foe, [0])
	assert_true(saw != null and foe_part != null and saw.behaviour != null, "the saw and the foe mounted, saw behaving")
	# The saw sits at x = 125 and reaches 14 cells, so its box ends at x = 139.5 while the foe's body
	# spans 134.5 .. 135.5: 20 cells apart, the Chainsaw cuts where a 6-cell Mace cannot.
	var ctx: ChBattleContext = _battle(world, catalog, [at, foe])
	var cut: Array[ChEvent] = []
	var sink := cut
	ctx.bus.subscribe(RefCounted.new(), ChEvent.CELLS_CUT, func(event: ChEvent): sink.append(event))
	var foe_hp := foe.hp
	for _tick in SAW_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
	assert_eq(cut.size(), 1, "the cut announced itself once")
	assert_eq(cut[0].data["sparks"], 4, "and threw the 4 fire sparks the brief names")
	assert_eq(foe.hp, foe_hp - saw.def.damage, "the cut paid the saw's 20 damage")

# Now nothing of the enemy reaches the box, and the tip stands in solid rock.
	var at2: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"cutter_chainsaw"]]), catalog, 0, ORIGIN, false)
	var foe2: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(60, 0), false)
	var saw2 := _part_of(at2, [1])
	assert_true(saw2 != null and foe2 != null, "the second pair built")
	# Rock packed around the tip (x = 139 at the saw's 14-cell reach) so the cut has ground to bite.
	world.fill_rect(Rect2i(135, 133, 10, 8), &"rock")
	var ctx2: ChBattleContext = _battle(world, catalog, [at2, foe2])
	var cut2: Array[ChEvent] = []
	var sink2 := cut2
	ctx2.bus.subscribe(RefCounted.new(), ChEvent.CELLS_CUT, func(event: ChEvent): sink2.append(event))
	for _tick in SAW_TICKS:
		ctx2.tick(TICK, [0.0, 0.0])
	assert_eq(cut2.size(), 1, "the terrain cut still announced CELLS_CUT")
	assert_eq(cut2[0].data["sparks"], 4, "with the same sparks")
	assert_eq(foe2.hp, 100, "no enemy body was in reach, so no HP went")
	assert_true(world.get_material_at(Vector2i(139, 137)) != &"rock", "the dig opened the tip cell")
	_complete()
