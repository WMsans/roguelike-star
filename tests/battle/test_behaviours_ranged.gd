extends ChTest

# Task 13: the ranged parts. World-backed, on the real part defs, so the behaviour scripts the
# .tres files name are the ones under test rather than a double.
# The rigs sit on ChTest's arena with a rock floor, as the melee suite does. Unlike the melee
# suite, these fights await engine frames: ChProjectile moves on Godot physics frames and the
# world's Box2D sim ticks on them too, so a synchronous ctx.tick loop cannot fly a projectile.
# shortcut: rig numbers are literals per def below; the slice's tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # the player's rig origin (Task 9's spawn ruling)
const APART := 40  # rig origins this far apart, so the chassis sit 24 cells apart
const TICK := 1.0 / 60.0  # the fight's clock per awaited frame
const PRESS := [true, true]  # both sides press every tick: a part fires the moment it is ready
const SETTLE := 90  # awaited frames that let a rig join the world and fall onto the floor

# The rig body every test's chariot sits on: a 10x10 hull so the settled chassis spans the launch
# line, and three slots, the outer one 8 cells out and 3 below the centre so the flight line runs
# just above the rock floor, which is the ground a blast can dig.
func _rig() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = 100
	def.energy_cap = 20
	def.energy_regen = 0.0
	def.size = Vector2i(10, 10)
	def.slots = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(8, 3)])
	return def

# The three ranged defs come off res://game/data/parts, so a build reads the weapons' numbers
# (cost, cooldown, charges, damage) off the .tres and gets the behaviour the .tres names.
func _catalog() -> ChCatalog:
	var loaded := ChCatalog.load_default()
	var defs: Array[ChPartDef] = []
	for id in [&"cutter_rocket", &"firebolt_launcher", &"corsair_harpoon", &"strut"]:
		var def: ChPartDef = loaded.part(id)
		assert_true(def != null, "%s loads from res://game/data/parts" % id)
		defs.append(def)
	var catalog := ChCatalog.from_defs(defs, [_rig()])
	for pair in [[&"cutter_rocket", true], [&"firebolt_launcher", true], [&"corsair_harpoon", true], [&"strut", false]]:
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

# The awaited-frame loop every projectile test runs: the fight's clock stays in fight seconds
# (FIRE_WINDOW of ctx ticks) while the engine's physics frames keep flying the projectile.
const TICKS_TO_FIRE := 100  # 1.67 s of fight clock: a 1.5 s cooldown goes ready, one fire only
const FLIGHT_FRAMES := 150  # awaited frames for the flight, which the fight clock does not bound
const HOOK_TICKS := 330  # 5.5 s of fight clock: a 5 s cooldown goes ready and fires once
const PULL_TICKS := 90  # 1.5 s of fight clock: the harpoon's attach window
const HUNT_FRAMES := 520  # awaited frames covering the fire and the whole attach window
const LOB_FRAMES := 620  # awaited frames for the fire and the flight to the foe's hull

# The band the bolt has to land in: around the foe's hull. Nothing else in the test can set it
# alight, so fire cells there are the impact's own fill_circle.
const LOB_BAND := Rect2i(140, 130, 40, 30)  # around the foe's hull, where the flat shot lands

# The Line2D the harpoon hangs under the world while its line is attached.
func _attached(ctx: ChBattleContext) -> bool:
	for child in ctx.world.get_children():
		if child is Line2D:
			return true
	return false

# The rocket flies straight along facing(), so the test hangs it 3 cells below the hull's centre:
# the flight line then runs just above the rock floor, which is the ground the blast can dig.
# A blast in open air removes nothing (measured: explode(200,130) r6 in air -> 0 cells removed),
# so the dug cells are the readback that proves the blast went off.
func test_rocket_explodes_and_damages() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"cutter_rocket"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var rocket := _part_of(at, [2])
	assert_true(rocket != null and rocket.behaviour != null, "the rocket mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChEvent] = []
	var sink := hits
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): sink.append(event))
	# The rigs have to join the world before a ray or a blast reads them (Task 9's ruling).
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var half := foe.body_def.size.y * 0.5
	assert_true(rocket.anchor_world().y > foe.chassis.global_position.y - half
		and rocket.anchor_world().y < foe.chassis.global_position.y + half,
		"the flight line crosses the foe's hull, so the segment can meet it")
	var foe_hp := foe.hp
	var impact := Vector2i(roundi(foe.chassis.global_position.x - foe.body_def.size.x * 0.5),
		roundi(rocket.anchor_world().y))
	var rock_before: int = world.count_materials(Rect2i(impact.x - 6, GROUND_TOP, 13, 6)).get(&"rock", 0)
	# The fight's clock stays inside one fire window while the engine's frames fly the projectile.
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
	assert_eq(hits.size(), 1, "one fire, one landed hit")
	assert_true(hits[0].source == rocket, "the rocket dealt it")
	# A bare rig answers no part, so ChDamage puts the whole damage on the chassis' HP.
	assert_true(hits[0].data["target_part"] == null, "a rig with no parts takes a chassis hit")
	assert_eq(foe.hp, foe_hp - rocket.def.damage, "the rocket paid its damage")
	var rock_after: int = world.count_materials(Rect2i(impact.x - 6, GROUND_TOP, 13, 6)).get(&"rock", 0)
	assert_true(rock_after < rock_before, "the blast opened the floor under the impact")
	_complete()

# A hand-built CAUGHT_FIRE in ChPartRuntime._emit's shape: side, source and position are what the
# bus's proximity filter reads, and the rocket subscribes with no range, so it hears either side.
# Same helper as tests/battle/test_behaviours_melee.gd's _catch_fire.
func _catch_fire(ctx: ChBattleContext, part: ChPartRuntime) -> void:
	var event := ChEvent.new()
	event.type = ChEvent.CAUGHT_FIRE
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	ctx.bus.emit(event)

# Point-blank: the same shot with the foe's hull 7 cells from the launcher (rig origins 20 apart)
# pays a quarter (ch_rocket.gd POINT_BLANK 20, POINT_BLANK_SHARE 0.25; the 27-cell hit above pays in full), so a Rocket pressed into a
# chariot that drove onto it is no longer the best gun in the game.
func test_rocket_point_blank_pays_a_quarter() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"cutter_rocket"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(20, 0), false)
	var rocket := _part_of(at, [2])
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChEvent] = []
	var sink := hits
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): sink.append(event))
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var foe_hp := foe.hp
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
	assert_eq(hits.size(), 1, "one fire, one landed hit")
	assert_eq(foe.hp, foe_hp - roundi(rocket.def.damage * 0.25), "a point-blank hit pays a quarter")
	_complete()

# Ignition: every CAUGHT_FIRE, from either side, halves the rocket's own countdown. The fire is
# hand-built (the melee suite's helper) because what is under test is the subscription and the
# halving, not ChPartRuntime's burning transition, which that suite already pins.
func test_rocket_ignition_halves_cooldown() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"cutter_rocket"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var rocket := _part_of(at, [2])
	var burner := _part_of(foe, [0])
	assert_true(rocket != null and rocket.behaviour != null and burner != null,
		"the rocket behaves and the foe's part can carry the fire")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var fired: Array[ChEvent] = []
	var sink := fired
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(event: ChEvent): sink.append(event))
	# No awaited frames here: the cooldown is the fight's clock, and ChBattleContext owns its ticks.
	# Tick until the first fire (90 ticks of 1/60 can sum a hair short of 1.5 s), and stop on that tick
	# so the countdown still reads the reset the loop gave it.
	for _tick in 91:
		ctx.tick(TICK, [0.0, 0.0], PRESS)
		if fired.size() == 1:
			break
	assert_eq(fired.size(), 1, "one fire in the first 1.5 s of clock")
	assert_near(rocket.cooldown_left, rocket.def.cooldown, 0.0001,
		"the fire reset the countdown, which the loop owns")
	var before := rocket.cooldown_left
	_catch_fire(ctx, burner)
	assert_near(rocket.cooldown_left, before * 0.5, 0.0001,
		"Ignition: the caught fire halved the countdown to 0.75 s")
	# Past the halved countdown the rocket is ready again well before its full 1.5 s cooldown.
	for _tick in 46:
		ctx.tick(TICK, [0.0, 0.0], PRESS)
	assert_eq(fired.size(), 2, "the halved countdown paid for a second fire 0.77 s after the first")
	_complete()

# The Firebolt is the charge-limited part: charges_left counts down once per fire (the battle loop
# owns that), and at 0 the part is no longer ready (ChPartRuntime.is_ready), so a press neither pays
# nor fires it and no PART_FIRED announces a shot that never happened.
# The pool's value and the PART_FIRED count are the two reads of that rule.
func test_firebolt_charges_run_out() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"firebolt_launcher"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var bolt := _part_of(at, [2])
	assert_true(bolt != null and bolt.behaviour != null, "the firebolt mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var fired: Array[ChEvent] = []
	var sink := fired
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(event: ChEvent): sink.append(event))
	var shots := bolt.charges_left
	# No awaited frames: the charges are the fight's clock, so the ticks run synchronously.
	# 11 s of clock is one fire per 2 s cooldown, five fires, and no sixth (that needs 12 s).
	for _tick in int(11.0 / TICK):
		ctx.tick(TICK, [0.0, 0.0], PRESS)
	assert_eq(fired.size(), shots, "five fires, five PART_FIRED")
	assert_eq(bolt.charges_left, 0, "the charges ran out after five fires")
	assert_eq(at.energy.value, at.energy.cap - float(shots) * bolt.def.energy_cost, "five costs went out of the pool")
	# The 6th ready tick: the part is out of charges, so a press must not fire it. Two seconds of
	# clock past the 5th fire is where the reset 2 s cooldown goes ready again; the pool's value and
	# the PART_FIRED count are the evidence that no 6th cycle ran.
	for _tick in int(2.0 / TICK):
		ctx.tick(TICK, [0.0, 0.0], PRESS)
	assert_eq(at.energy.value, at.energy.cap - float(shots) * bolt.def.energy_cost,
		"and the 6th cycle paid nothing out of the pool")
	assert_eq(fired.size(), shots, "and no PART_FIRED announced a shot that never happened")
	assert_eq(bolt.charges_left, 0, "and the charges never go past 0 into the unlimited sentinel")
	_complete()

# The Firebolt lobs: 20 degrees up from facing at 150 cells per second under a gravity of 120, a
# flat arc that meets the foe's hull 24 cells out (measured: impact at (155, 150)). The fill it
# leaves is read back as fire cells around that hull, which is the brief's "fire or burning > 0 within 10
# ticks": the band is read on every awaited frame, so the reading is taken while it is still fire.
func test_firebolt_starts_fire() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"firebolt_launcher"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var bolt := _part_of(at, [2])
	assert_true(bolt != null and bolt.behaviour != null, "the firebolt mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var fired: Array[ChEvent] = []
	var sink := fired
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(event: ChEvent): sink.append(event))
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var before := world.count_materials(LOB_BAND)
	assert_eq(before.get(&"fire", 0) + before.get(&"burning", 0), 0, "the floor starts with no fire")
	var seen := 0
	for _frame in LOB_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < 3.5:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		var counts: Dictionary = world.count_materials(LOB_BAND)
		seen = maxi(seen, counts.get(&"fire", 0) + counts.get(&"burning", 0))
	assert_eq(fired.size(), 1, "one fire in the window")
	assert_true(seen > 0, "the impact left fire where the bolt landed")
	_complete()

# The Harpoon hooks an enemy hull inside its 120-cell line and reels both sides together for 1.5 s
# of fight clock: apply_force on the enemy body toward the anchor, and the mirror of that force on
# the firing chassis. A pair with no harpoon in the same world stays where it was, which is the
# control the brief asks for. Measured here: one impulse per tick closes the gap by seconds of cells
# at 8e3 and by nothing at 4e3, which is Box2D's own resistance (the hull's mass is 42).
func test_harpoon_pulls_enemy_closer() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"corsair_harpoon"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	# The control pair, far down the arena, outside the fight: nothing drives it and no behaviour
	# touches it, so what it measures is what two hulls do on their own over the same frames.
	var ctl: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 0, Vector2(330, 140), false)
	var ctl_foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, Vector2(330 + APART, 140), false)
	var harpoon := _part_of(at, [2])
	assert_true(harpoon != null and harpoon.behaviour != null, "the harpoon mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var foe_hp := foe.hp
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var gap_before := at.chassis.global_position.distance_to(foe.chassis.global_position)
	var ctl_before := ctl.chassis.global_position.distance_to(ctl_foe.chassis.global_position)
	assert_true(not _attached(ctx), "no line before the hook")
	var seen_line := false
	# The fight ticks once per awaited frame, so the pull window is HOOK_TICKS + PULL_TICKS of clock.
	for _frame in HUNT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < (HOOK_TICKS + PULL_TICKS) * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		seen_line = seen_line or _attached(ctx)
	assert_true(seen_line, "a Line2D drew while the line was attached")
	assert_true(not _attached(ctx), "and it went when the attach window ended")
	assert_eq(foe.hp, foe_hp - harpoon.def.damage, "the hook paid its 5 damage to the hull")
	var gap_after := at.chassis.global_position.distance_to(foe.chassis.global_position)
	var ctl_after := ctl.chassis.global_position.distance_to(ctl_foe.chassis.global_position)
	assert_near(ctl_after, ctl_before, 1.0, "the pair with no harpoon kept its distance")
	assert_true(gap_after < gap_before - 10.0,
		"the harpoon closed the distance the control pair still holds")
	_complete()

# The cook's Barge mounts its Harpoon behind its own Mace on the top row, so the line starts inside
# its own build. The hook looks past its own chariot's bodies (the chassis and the strut in front of
# it here) and lands on the enemy hull beyond them.
func test_harpoon_looks_past_its_own_parts() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"corsair_harpoon"], [[1], &"strut"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var harpoon := _part_of(at, [0])
	assert_true(harpoon != null and harpoon.behaviour != null, "the harpoon mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var foe_hp := foe.hp
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var seen_line := false
	for _frame in HUNT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < (HOOK_TICKS + PULL_TICKS) * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		seen_line = seen_line or _attached(ctx)
	assert_true(seen_line, "the line attached past its own strut and chassis")
	assert_eq(foe.hp, foe_hp - harpoon.def.damage, "and the hook paid its damage to the enemy hull")
	_complete()

# Out of range: the hull's face sits past the 120-cell line, so the raycast answers nothing, the
# hull pays no HP, both hulls keep their distance and no line is ever drawn. Measured: a face 27
# cells out hooks and a face 137 cells out does not, so 150 cells of origin gap is the miss case.
func test_harpoon_misses_out_of_range() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"corsair_harpoon"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(150, 0), false)
	var harpoon := _part_of(at, [2])
	assert_true(harpoon != null and harpoon.behaviour != null, "the harpoon mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var gap_before := at.chassis.global_position.distance_to(foe.chassis.global_position)
	var foe_hp := foe.hp
	var seen_line := false
	for _frame in HUNT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < (HOOK_TICKS + PULL_TICKS) * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		seen_line = seen_line or _attached(ctx)
	assert_true(not seen_line, "so no line was ever attached")
	assert_eq(foe.hp, foe_hp, "and the hull paid no damage")
	var gap_after := at.chassis.global_position.distance_to(foe.chassis.global_position)
	assert_near(gap_after, gap_before, 1.0, "and neither hull moved toward the other")
	_complete()

# A hooked hull that goes inside the attach window (a wrecked rig, a body freed for any other
# reason): the reel must stop with the body rather than read a freed position, and the rope must
# stop pointing at it. The hull goes the frame the line shows up, so ~1.4 s of the 1.5 s window is
# still to run -- a line still in the tree after a few frames is the rope on a dead hook, and the
# old code also prints an access-to-freed error here.
func test_harpoon_line_ends_when_the_hook_goes() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"corsair_harpoon"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(APART, 0), false)
	var harpoon := _part_of(at, [2])
	assert_true(harpoon != null and harpoon.behaviour != null, "the harpoon mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var hull: PixelRigidBody = foe.chassis
	var freed := false
	var since_free := 0
	var still_drawn := false
	for _frame in HUNT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < (HOOK_TICKS + PULL_TICKS) * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		if not freed and _attached(ctx):
			# The line is hooked, so the hull goes mid-window: queue_free lands at the frame's end.
			foe.chassis.queue_free()
			freed = true
		if freed:
			since_free += 1
			if since_free > 4:
				still_drawn = still_drawn or _attached(ctx)
	assert_true(freed, "the line hooked a hull, so there was an attach to end")
	assert_true(not is_instance_valid(hull), "the hooked hull left the tree")
	assert_true(not still_drawn, "the rope went with the hook rather than keeping its far end on it")
	_complete()

# The bolt's trail is emitted, not attached: each physics frame the bolt hands the world's particle
# pool a few pixels carrying a share of its own velocity, and never addresses them again, so the bolt
# outruns its own smoke. The core sprite is the one look that does ride the bolt, because a body is
# its own emitter; without it the bolt the old trail sheet used to draw is invisible.
func _bolt(world: PixelWorld) -> ChProjectile:
	for child in world.get_children():
		if child is ChProjectile:
			return child
	return null

# The world's own baked effects: a trail puff is one of these, the muzzle flash is another.
func _fx(world: PixelWorld) -> Array:
	var found: Array = []
	for child in world.get_children():
		if child is ChFx:
			found.append(child)
	return found

func _puffs(world: PixelWorld) -> Array:
	var found: Array = []
	for node in _fx(world):
		var path: String = node.texture.resource_path
		if path.ends_with("puff_fire.png") or path.ends_with("puff_smoke.png"):
			found.append(node)
	return found

# A settled rig firing its rocket once, handed back with the fight: [ctx, bolt], the bolt null if the
# shot never came out. Four tests need the same launch, and a copy each would be four places to drift.
func _rocket_shot(world: PixelWorld) -> Array:
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"cutter_rocket"]]), catalog, 0, ORIGIN, false)
	var rocket := _part_of(at, [2])
	assert_true(rocket != null and rocket.behaviour != null, "the rocket mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var bolt: ChProjectile = null
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		bolt = _bolt(world)
		if bolt != null:
			break
	return [ctx, bolt]

func test_bolt_trail_is_particles_and_the_bolt_stays_visible() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"cutter_rocket"]]), catalog, 0, ORIGIN, false)
	var rocket := _part_of(at, [2])
	assert_true(rocket != null and rocket.behaviour != null, "the rocket mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var bolt: ChProjectile = null
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		bolt = _bolt(world)
		if bolt != null:
			break
	assert_true(bolt != null, "the rocket fired and a bolt is flying")
	# The first pixels go on the bolt's first physics frame, which is the frame after it enters the tree.
	for _frame in 6:
		await Engine.get_main_loop().process_frame
	assert_true(is_instance_valid(bolt), "the bolt is still flying")
	var sprites := 0
	var sheets := 0
	for child in bolt.get_children():
		if child is Sprite2D:
			sprites += 1
		if child is ChFx:
			sheets += 1
	assert_eq(sprites, 1, "the bolt carries one core sprite of its own")
	assert_eq(sheets, 0, "no baked effect rides the bolt")
	assert_true(int(world.get_stats()["particles_visual"]) > 0, "the trail is in the world's particle pool")
	_complete()

# The trail's mass is baked, and baked effects live in the world: the bolt drops one every eight cells it
# flies and the puff is born where the bolt was. Distance rather than time, so the stream is evenly spaced
# whatever the bolt's speed, and the alternation of the two sheets is what makes it read smoke under flame.
const PUFF_EVERY := 8.0  # cells: the cadence both the drop and this test read

func test_bolt_drops_a_puff_every_eight_cells() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	# Flight time is physics time: headless idle frames run faster than the 60 Hz the bolt steps on.
	for _tick in 12:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() >= 2, "the bolt left puffs behind it (%d)" % puffs.size())
	assert_true(puffs[0].texture.resource_path != puffs[1].texture.resource_path, "the stream alternates flame and smoke")
	assert_near(puffs[1].position.distance_to(puffs[0].position), PUFF_EVERY, 0.5,
		"puffs sit %s cells apart" % PUFF_EVERY)
	_complete()

# The bug the emitter split fixed, pinned the other way round: emitted pixels must not ride the emitter.
# If a puff were parented to the bolt, turning the bolt would swing every puff already out of it.
func test_a_dropped_puff_never_moves_again() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 10:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() > 0, "a puff is out")
	var puff: ChFx = puffs[0]
	var dropped_at := puff.global_position
	var turned_at := puff.global_rotation
	bolt.global_rotation += 0.7
	bolt.bolt_velocity = bolt.bolt_velocity.rotated(0.5)
	for _tick in 4:
		await Engine.get_main_loop().physics_frame
	assert_true(is_instance_valid(puff), "the puff is still there")
	assert_true(puff.global_position.is_equal_approx(dropped_at), "the puff stays where it was dropped (%s, was %s)" % [puff.global_position, dropped_at])
	assert_true(is_equal_approx(puff.global_rotation, turned_at), "and keeps its own turn")
	_complete()

# Decoration gives way to the fight in the pool, and the trail is not pool particles: with the pool past
# ChFeedbackParticles' share the sparks stop, and the puffs must go on landing.
func test_puffs_appear_even_when_the_pool_is_full() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 4:
		await Engine.get_main_loop().physics_frame
	world.spawn_visual_particles(Color.WHITE, ORIGIN, Vector2.ZERO, int(world.get_max_particles()), 1.0, 0.5)
	assert_eq(ChFeedbackParticles.budget(world, 1), 0, "the pool is past the share decoration may spend")
	var before := _puffs(world).size()
	for _tick in 6:
		await Engine.get_main_loop().physics_frame
	assert_true(_puffs(world).size() > before, "a puff landed with no pool to spend")
	_complete()

# A puff is a one-shot with nobody holding it: once the bolt is gone nothing keeps its trail alive.
func test_puffs_free_themselves() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 6:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() > 0, "the bolt dropped puffs")
	var dropped: ChFx = puffs[0]
	bolt.queue_free()
	for _tick in 2:
		await Engine.get_main_loop().physics_frame
	assert_true(is_instance_valid(dropped), "the bolt's own free takes no puff with it")
	# A puff's own life is 22 frames at 30 fps, ~44 physics ticks: 70 is past the last one.
	for _tick in 70:
		await Engine.get_main_loop().physics_frame
	assert_eq(_puffs(world).size(), 0, "every puff freed itself")
	_complete()
