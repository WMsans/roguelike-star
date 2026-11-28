extends ChTest

# Task 2: the held button runs continuous parts. A melee or beam part pays def.energy_per_second
# every frame it can pay, and lands one tick a second of running (Speedup x2, Slow x0.5, Freeze
# stops). World-backed on rigs from the real builder, as test_context.gd does, with the two fixture
# behaviours under tests/battle/fixtures: they are ChBehaviour subclasses whose continuous_tick is
# _strike, so a HIT here went through the real damage path (ctx.deal_hit).
# shortcut: rig numbers are literals in the defs below; the slice's tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # near the floor, as test_context.gd spawns
const ENEMY_AT := Vector2(132, 140)  # 12 cells right: the foe's 10x6 hull sits inside both reaches
const TICK := 1.0 / 60.0  # one 60 fps frame
const DAMAGE := 10  # every fixture hit
const PER_SECOND := 2.0  # every fixture part's energy_per_second
const MELEE_REACH := 24.0  # the brief's fixture reach, in cells from the part's edge
const BEAM_REACH := 40.0  # the brief's fixture reach
const BODY_CAP := 100  # the rig's pool, so 3 s of 2/s never runs dry by itself
const MELEE_FIXTURE := "res://tests/battle/fixtures/ch_fixture_melee.gd"
const BEAM_FIXTURE := "res://tests/battle/fixtures/ch_fixture_beam.gd"
const HELD := [true, false]  # the player holds, the enemy never does
const RELEASED := [false, false]

# The rig body both sides sit on: a 10x6 hull with four slots. Slot 0 takes the weapon and slot 1 a
# wheel; the enemy mounts nothing, so its chassis is the body a swing lands on.
func _body(cap := BODY_CAP, regen := 0.0) -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = 100
	def.energy_cap = cap
	def.energy_regen = regen
	def.size = Vector2i(10, 6)
	def.slots = PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0), Vector2(30, 0)])
	return def

func _wheel_def() -> ChPartDef:
	# A wheel by tag (ChPartDef.is_wheel): 1.0 a second is the drive's price.
	var def := ChPartDef.new()
	def.id = &"test_wheel"
	def.tags = PackedStringArray(["passive", "wheel"])
	def.mode = ChPartDef.MODE_WHEEL
	def.energy_per_second = 1.0
	def.size = Vector2i(2, 2)
	def.charges = -1
	return def

func _gun_def(id: StringName, cost: int) -> ChPartDef:
	# A press-fired part for the volley's PART_SKIPPED test: ready at once, 1 s cooldown.
	var def := ChPartDef.new()
	def.id = id
	def.mode = ChPartDef.MODE_COOLDOWN
	def.energy_cost = cost
	def.cooldown = 1.0
	def.damage = DAMAGE
	def.integrity = 100
	def.size = Vector2i(2, 2)
	def.charges = -1
	return def

func _continuous_def(id: StringName, mode: StringName, reach: float, behaviour_path: String) -> ChPartDef:
	var def := ChPartDef.new()
	def.id = id
	def.mode = mode
	def.energy_per_second = PER_SECOND
	def.damage = DAMAGE
	def.reach = reach
	def.integrity = 100
	def.size = Vector2i(2, 2)
	def.charges = -1
	# Loaded rather than preloaded: a fixture that no longer parses still builds a part, so a test's
	# own assertion names the missing behaviour instead of the whole file failing to load.
	def.behaviour = load(behaviour_path)
	return def

func _melee_def() -> ChPartDef:
	return _continuous_def(&"test_melee", ChPartDef.MODE_MELEE, MELEE_REACH, MELEE_FIXTURE)

func _beam_def() -> ChPartDef:
	return _continuous_def(&"test_beam", ChPartDef.MODE_BEAM, BEAM_REACH, BEAM_FIXTURE)

# One layout mounting [[path, part_id]] in mount order; place() takes Array[int].
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout

# The part the builder put at a layout path; runtime.parts keeps every part's own path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null

# A battle context over `rigs` (index = side), with every mounted behaviour getting the setup call
# that subscribes it through the one entry point, exactly as test_context.gd's _battle does.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = rigs
	ctx.setup_all()
	return ctx

# The player rig with `defs` mounted at `mounts`, and a bare enemy rig 12 cells to the right, inside
# both fixture reaches. Answers [player rig, enemy rig, context].
func _arena(world: PixelWorld, defs: Array[ChPartDef], mounts: Array,
		cap := BODY_CAP, regen := 0.0) -> Array:
	var catalog := ChCatalog.from_defs(defs, [_body(cap, regen)])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount(mounts), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ENEMY_AT, false)
	var rigs: Array[ChChariotRuntime] = [rig, foe]
	return [rig, foe, _battle(world, catalog, rigs)]

# The rock floor the chariots stand on; fill_rect returns the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")

# Holds for `ticks` frames and answers nothing; the caller reads its own counters back.
func _hold(ctx: ChBattleContext, ticks: int, held := true) -> void:
	for _tick in ticks:
		ctx.tick(TICK, [0.0, 0.0], [], [held, false])

# The counter pair every continuous test reads: HITs, PART_FIREDs and, for the melee timer, the tick
# the first HIT landed on. A Dictionary is a reference, so a lambda may write through it.
func _counters(ctx: ChBattleContext) -> Dictionary:
	var counts := {"hit": 0, "fired": 0, "first": 0, "tick": 0}
	var sink := counts
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(_event: ChEvent):
		sink["hit"] += 1
		if sink["hit"] == 1:
			sink["first"] = sink["tick"])
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(_event: ChEvent): sink["fired"] += 1)
	return counts

# Review Focus 1's other half: the timer runs only while the part runs. 3 s held is three ticks of a
# 1 s timer, the first on the first held tick (tick_left starts at 0, so a fresh part swings at once).
func test_melee_ticks_once_a_second_while_held() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var rig: ChChariotRuntime = set[0]
	var melee := _part_of(rig, [0])
	assert_true(melee != null and melee.behaviour != null, "the melee part mounted with its fixture behaviour")
	assert_true(melee != null and melee.outline != null, "a continuous part gets an outline the way a cooldown part does")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	for at in 180:
		counts["tick"] = at + 1
		ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_eq(counts["hit"], 3, "180 held ticks land exactly three HITs")
	assert_eq(counts["fired"], 3, "and each melee tick announces PART_FIRED")
	assert_eq(counts["first"], 1, "the first HIT lands on the first held tick")
	assert_true(melee.running, "the part ran on the last held tick")
	_complete()

# The same rig with the button up: no tick, no hit and nothing paid.
func test_melee_needs_the_button() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var rig: ChChariotRuntime = set[0]
	var melee := _part_of(rig, [0])
	assert_true(melee != null and melee.behaviour != null, "the melee part mounted with its fixture behaviour")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	for _tick in 180:
		ctx.tick(TICK, [0.0, 0.0], [], RELEASED)
	assert_eq(counts["hit"], 0, "no hold, no HIT")
	assert_eq(counts["fired"], 0, "and no PART_FIRED")
	assert_near(rig.energy.spent, 0.0, 0.0001, "and nothing was paid")
	assert_true(not melee.running, "the part did not run")
	_complete()

# A beam differs from melee in one place: it announces PART_FIRED once when it switches on, then hits
# each second silently. Releasing switches it off, so holding again announces once more.
func test_beam_fires_once_and_hits_each_second() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_beam_def()], [[[0], &"test_beam"]])
	var rig: ChChariotRuntime = set[0]
	var beam := _part_of(rig, [0])
	assert_true(beam != null and beam.behaviour != null, "the beam part mounted with its fixture behaviour")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	_hold(ctx, 180)
	assert_eq(counts["hit"], 3, "180 held ticks land three HITs")
	assert_eq(counts["fired"], 1, "a beam announces PART_FIRED once, on switch-on")
	_hold(ctx, 30, false)
	assert_eq(counts["fired"], 1, "a release announces nothing")
	_hold(ctx, 2)
	assert_eq(counts["fired"], 2, "holding again switches it back on, so one more PART_FIRED")
	_complete()

# The hold's price: 2/s while held. One second of it takes 2.0 off the pool, on top of the body's 1/s
# regen, so the pool ends a net 1.0 short of where it started.
func test_continuous_pays_per_second() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def()], [[[0], &"test_melee"]], BODY_CAP, 1.0)
	var rig: ChChariotRuntime = set[0]
	# Below cap, so the second of regen is not clamped away by the pool's own ceiling.
	rig.energy.value = 50.0
	var ctx: ChBattleContext = set[2]
	_hold(ctx, 60)
	assert_near(rig.energy.value, 50.0 - PER_SECOND + 1.0, 0.01, "one second of 2/s, plus 1/s regen")
	_complete()

# The continuous step runs the dearest energy_per_second first, as the volley does for cost. A pool
# that buys only the dearest part's frame must pay that part and leave the cheap one dark; an ascending
# sort would buy the cheap one first.
func test_continuous_pays_the_dearest_first() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var cheap := _melee_def()
	cheap.id = &"test_cheap"
	cheap.energy_per_second = 1.0
	var dear := _melee_def()
	dear.id = &"test_dear"
	dear.energy_per_second = 3.0
	# The cheap part is mounted first, so an ascending sort would pay it before the dear one.
	var set := _arena(world, [cheap, dear], [[[0], &"test_cheap"], [[1], &"test_dear"]])
	var rig: ChChariotRuntime = set[0]
	var cheap_part := _part_of(rig, [0])
	var dear_part := _part_of(rig, [1])
	assert_true(cheap_part != null and dear_part != null, "both continuous parts mounted")
	# Exactly one frame of the dearest part, and nothing for the cheap one behind it.
	rig.energy.value = dear.energy_per_second * TICK
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_true(dear_part.running, "the pool bought the dearest part's frame")
	assert_true(not cheap_part.running, "and the cheap part went unpaid")
	assert_eq(counts["hit"], 1, "the dearest part landed the frame's tick")
	assert_near(rig.energy.spent, dear.energy_per_second * TICK, 0.0001, "the pool paid only the dearest")
	_complete()


# Review Focus 2: a held part the pool cannot pay simply does not run that frame. Nothing goes
# negative, and the beam announces PART_FIRED again when it next runs.
func test_unpaid_part_does_not_run() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_beam_def()], [[[0], &"test_beam"]])
	var rig: ChChariotRuntime = set[0]
	var beam := _part_of(rig, [0])
	assert_true(beam != null and beam.behaviour != null, "the beam part mounted with its fixture behaviour")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	_hold(ctx, 60)
	assert_eq(counts["hit"], 1, "one second of holding lands one HIT")
	assert_eq(counts["fired"], 1, "and the beam is on")
	assert_true(beam.running, "so the part ran")
	# An empty pool cannot pay one frame's 2/60, so the next held frame pays nothing and lands nothing.
	rig.energy.value = 0.0
	ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_eq(counts["hit"], 1, "an unpaid tick lands no HIT")
	assert_eq(counts["fired"], 1, "and announces nothing new")
	assert_true(not beam.running, "the beam did not run")
	assert_near(rig.energy.value, 0.0, 0.0001, "and the pool did not go negative")
	# Refilling it buys the beam again: running was false, so its switch-on announces once more.
	rig.energy.value = BODY_CAP
	ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_eq(counts["fired"], 2, "a refilled pool switches the beam back on")
	assert_true(beam.running, "the part runs again")
	_complete()

# The global rule: the drive is paid before anything else. A pool that covers only the drive pays it,
# the wheel's motor turns, and the held melee behind it simply does not run this frame.
func test_drive_and_volley_pay_first() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def(), _wheel_def()],
		[[[0], &"test_melee"], [[1], &"test_wheel"]])
	var rig: ChChariotRuntime = set[0]
	var melee := _part_of(rig, [0])
	assert_true(melee != null and melee.behaviour != null, "the melee part mounted with its fixture behaviour")
	var wheels := rig.wheels()
	assert_eq(wheels.size(), 1, "one wheel is mounted")
	assert_near(rig.drive_cost(), 1.0, 0.001, "and it costs 1.0 a second to drive")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	rig.energy.value = rig.drive_cost() * TICK
	ctx.tick(TICK, [1.0, 0.0], [], HELD)
	assert_eq(counts["hit"], 0, "the drive took the whole pool, so the held melee did not run")
	assert_true(not melee.running, "the part is not running")
	assert_true(wheels[0].joint.enable_motor, "the drive was paid, so the wheel's motor runs")
	assert_near(rig.energy.spent, rig.drive_cost() * TICK, 0.0001, "only the drive was paid")
	assert_near(rig.energy.value, 0.0, 0.0001, "and the pool is not negative")
	_complete()

# Review Focus 1: tapping must not beat the rate. Alternating held and released every other frame for
# 3 s is only 1.5 s of running, so at most two ticks land. The timer is never reset by the release.
func test_tapping_cannot_beat_the_rate() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	for at in 180:
		ctx.tick(TICK, [0.0, 0.0], [], [at % 2 == 0, false])
	assert_true(counts["hit"] <= 2, "1.5 s of running lands at most two HITs, got %d" % counts["hit"])
	_complete()

# The statuses scale the timer exactly as they scale a cooldown: Speedup x2 means a tick every half
# second, Slow x0.5 a tick every two. The status is re-given every frame because it decays per second.
func test_speedup_and_slow_scale_ticks() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var fast_set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var fast_part := _part_of(fast_set[0], [0])
	assert_true(fast_part != null and fast_part.behaviour != null, "the speedup melee mounted")
	var fast_ctx: ChBattleContext = fast_set[2]
	var fast_counts := _counters(fast_ctx)
	for _tick in 120:
		# Extra stacks, so the status second's decay cannot take it away for the tick it hits on.
		fast_part.statuses.stacks[ChStatuses.SPEEDUP] = 5
		fast_ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_eq(fast_counts["hit"], 4, "2 s of Speedup lands four HITs")
	var slow_set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var slow_part := _part_of(slow_set[0], [0])
	assert_true(slow_part != null and slow_part.behaviour != null, "the slow melee mounted")
	var slow_ctx: ChBattleContext = slow_set[2]
	var slow_counts := _counters(slow_ctx)
	for _tick in 120:
		# Extra stacks, so the status second's decay cannot take it away for the tick it hits on.
		slow_part.statuses.stacks[ChStatuses.SLOW] = 5
		slow_ctx.tick(TICK, [0.0, 0.0], [], HELD)
	assert_eq(slow_counts["hit"], 1, "2 s of Slow lands one HIT")
	_complete()

# Review Focus 3: a frozen continuous part does not run, does not pay and does not count down. Its
# timer is left exactly where it was, so a thaw resumes rather than restarts.
func test_freeze_stops_a_continuous_part() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _arena(world, [_melee_def()], [[[0], &"test_melee"]])
	var rig: ChChariotRuntime = set[0]
	var melee := _part_of(rig, [0])
	assert_true(melee != null and melee.behaviour != null, "the melee part mounted with its fixture behaviour")
	melee.tick_left = 0.5
	melee.statuses.stacks[ChStatuses.FREEZE] = 100
	assert_true(melee.is_frozen(), "the part is frozen")
	assert_true(not melee.can_run(), "so it cannot run")
	var ctx: ChBattleContext = set[2]
	var counts := _counters(ctx)
	_hold(ctx, 60)
	assert_eq(counts["hit"], 0, "a frozen part lands no HIT")
	assert_eq(counts["fired"], 0, "and announces none")
	assert_near(rig.energy.spent, 0.0, 0.0001, "and pays nothing")
	assert_near(melee.tick_left, 0.5, 0.0001, "its timer is unchanged across the freeze")
	assert_true(not melee.running, "and it is not running")
	_complete()

# The spec's "a part is skipped in a volley" trigger: a ready part the pool refuses is announced, with
# the cost it could not pay. The dearest part pays first, so the 1-cost one is the skipped one.
func test_skipped_part_is_announced() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var defs: Array[ChPartDef] = [_gun_def(&"gun_hi", 3), _gun_def(&"gun_lo", 1)]
	var catalog := ChCatalog.from_defs(defs, [_body(3)])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"gun_hi"], [[1], &"gun_lo"]]), catalog, 0, ORIGIN, false)
	var high := _part_of(rig, [0])
	var low := _part_of(rig, [1])
	assert_true(high != null and low != null, "both guns mounted")
	high.cooldown_left = 0.0
	low.cooldown_left = 0.0
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx := _battle(world, catalog, rigs)
	var skipped: Array[ChEvent] = []
	var sink := skipped
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_SKIPPED, func(event: ChEvent): sink.append(event))
	var fired := ctx.tick(TICK, [0.0], [true])
	assert_eq(fired, [1], "the 3-cost part fired")
	assert_eq(skipped.size(), 1, "exactly one part was announced as skipped")
	if skipped.size() == 1:
		assert_true(skipped[0].source == low, "the 1-cost part is the one the pool refused")
		assert_eq(skipped[0].data.get("cost"), 1, "and the payload carries its cost")
	assert_near(rig.energy.value, 0.0, 0.0001, "the pool paid the dearest part")
	_complete()

# Task 1: a passive-mode part never joins the volley, even if its def still carries a cooldown.
func test_cooldown_mode_gates_the_volley() -> void:
	var part := ChPartRuntime.new()
	var def := ChPartDef.new()
	def.id = &"passive_gun"
	def.mode = ChPartDef.MODE_PASSIVE
	def.cooldown = 2.0
	def.energy_cost = 1
	def.integrity = 100
	part.def = def
	assert_true(not part.is_ready(), "a passive part is never ready, cooldown or not")
	_complete()
