extends ChTest

# Task 14: the fire emitters. World-backed and on the real part defs, so the behaviour scripts the
# .tres files name are the ones under test rather than a double.
# The fights advance the engine deterministically: one `world.step(1)` per fight tick, as
# tests/battle/test_context.gd and tests/battle/test_builder.gd do, so the sim's fire cells and the
# fight's clock stay in
# step no matter how fast the headless run goes. Settling a rig still needs awaited frames, since
# a PixelRigidBody joins on the engine's own physics tick (Task 9's ruling).
# shortcut: rig numbers are literals per def below; the parts' tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # the player's rig origin (Task 9's spawn ruling)
const TICK := 1.0 / 60.0  # the fight's clock per engine tick
const SETTLE := 90  # awaited frames that let a rig join the world and fall onto the floor

# The rig body every test's chariot sits on: a 10x6 hull with four slots, so the distances the
# reach and ring tests read are slot numbers. Slot 1 is the hull's forward end at +x.
func _rig() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = 100
	def.energy_cap = 20
	def.energy_regen = 0.0
	def.size = Vector2i(10, 6)
	def.slots = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(0, -3), Vector2(-30, -3)])
	return def


# The real defs from res://game/data/parts under that rig body, so a build reads the emitters'
# numbers (cost, cooldown, damage, proximity_range as reach) off the .tres and gets the behaviour
# the .tres names.
func _catalog() -> ChCatalog:
	var loaded := ChCatalog.load_default()
	var defs: Array[ChPartDef] = []
	for id in [&"flamethrower", &"hearth", &"ring_of_fire", &"ember_battery", &"strut"]:
		var def: ChPartDef = loaded.part(id)
		assert_true(def != null, "%s loads from res://game/data/parts" % id)
		# The emitters stay unlimited-charge parts: the brief never spends charges on them.
		# A charge-limited emitter would read charges_left in process, and the loop's -1 sentinel
		# means unlimited, so a limited behaviour would have to park cooldown_left at INF (Task 13's
		# convention). Not tested here because no fire emitter in the slice is limited.
		defs.append(def)
	var catalog := ChCatalog.from_defs(defs, [_rig()])
	for pair in [[&"flamethrower", true], [&"hearth", true], [&"ring_of_fire", true],
	 [&"ember_battery", true], [&"strut", false]]:
		# A part the brief leaves behaviour-less (the strut) stays a plain mountable shell.
		# The emitters must carry their scripts as the .tres stand, or a fire would be no-ops.
		var has: bool = catalog.part(pair[0]).behaviour != null
		assert_eq(has, pair[1], "%s behaviour is%s as the .tres stand" % [pair[0], "" if pair[1] else " left out"])
	return catalog


# A build from [[path, part_id]] in mount order on the rig body; place() takes Array[int].
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	# shortcut: one layout per test; a test that wants different rigs calls _mount twice.
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout

func _typed_path(path) -> Array[int]:
	# place() wants a typed path, so the literal slot indices get converted here.
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

# A battle over both sides, with every mounted behaviour getting the setup call that subscribes
# it: nothing in game/ calls setup yet (Task 15 owns that), so a behaviour whose subscriptions are
# never set up stays dead. The emitters' timers live in process, which ctx.tick calls anyway, so a
# missing setup only silences the subscriptions that need it.
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

# The rig gap the flamethrower test uses: 40 cells between origins, so the enemy's part (its rig's
# slot 0 at -5) sits 30 cells out from the flamethrower's own anchor (slot 1 at +5), the far end of
# the brief's "an enemy part within 30 cells". The burn has to prove itself there, not at 10 cells.
# ChBehaviour._reach_box measures def.proximity_range, which the flamethrower's def leaves 0, so the
# behaviour grows that box out to its own 40-cell reach: the enemy sits well inside it.
const FLAME_GAP := 40
const FLAME_TICKS := 272  # 3.03 s to the first fire (def.cooldown 3.0) plus 1.5 s of burn window

# A flamethrower burst is 3 fire particles a tick for 1 s along facing(). Measured on the engine:
# count_materials answers 0 fire while the particles are in the pool, and they write grid cells once
# something blocks them (ParticlePool::land, up to LAND_SEARCH cells back along the path, then up).
# Where they land is gravity's, so the speed that reaches the brief's 30 cells is this file's and the
# behaviour's, measured together: at the behaviour's PARTICLE_SPEED the 1 s burst writes fire cells
# past 30 cells out, which is what the peak and the catch below read back.
# Fix-wave item 7 measured how much room that pin has, running this shape with the rig gap varied and
# reading the peak fire-cell count the target's own sample_rect sees: 7 cells at 20 apart, 6 at the 30
# this test pins, 5 at 34, and 3 - ChPartRuntime's own threshold, no margin - at 38. So the jet stops
# reaching somewhere past 34 cells part to part, and the brief's 30 sits inside it with a 3-cell
# cushion rather than on the edge. Nothing here is weakened; the numbers are recorded so a future
# tuning change to PARTICLE_SPEED knows what it is moving.
func test_flamethrower_sets_target_burning() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"flamethrower"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, ORIGIN + Vector2(FLAME_GAP, 0), false)
	var flame := _part_of(at, [1])
	var foe_part := _part_of(foe, [0])
	assert_true(flame != null and flame.behaviour != null and foe_part != null, "the flamethrower behaves and the foe's part carries the fire")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChEvent] = []
	var caught: Array[ChEvent] = []
	var fired_at: Array[float] = []
	# A lambda reads an Array by reference, so the sinks are arrays rather than scalars.
	# shortcut: same capture shape as tests/battle/test_behaviours_melee.gd's sinks.
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.CAUGHT_FIRE, func(event: ChEvent): caught.append(event))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED,
		func(event: ChEvent): fired_at.append(ctx.time))
	# The fight's clock at the fire, which the burn window is measured against.
	# shortcut: ctx.time is the fight's clock, which the PART_FIRED callback reads directly.
	for _settle in SETTLE:
		# A rig has to join the world before anything reads it (Task 9's ruling).
		await Engine.get_main_loop().process_frame
		world.step(1)
	var peak := 0
	var burn_at := -1.0
	for _tick in FLAME_TICKS:
		# The sim and the fight tick together, one step per fight tick: no awaited frames here,
		# so a physics frame cannot add an extra sim tick and make the fire read frame-rate dependent.
		world.step(1)
		ctx.tick(TICK, [0.0, 0.0])
		var counts: Dictionary = world.count_materials(foe_part.sample_rect())
		# The peak is what ChPartRuntime's 3-cell threshold gets to see, so the assert below names it.
		peak = maxi(peak, counts.get(&"fire", 0) + counts.get(&"lava", 0) + counts.get(&"burning", 0))
		if burn_at < 0.0 and foe_part.burning:
			burn_at = ctx.time
	var paid := 0
	for hit in hits:
		paid += hit.data["hp_damage"]
	assert_true(peak >= 3, "the burst landed at least 3 fire cells in the target's sample_rect (peak %d)" % peak)
	assert_true(caught.size() >= 1, "the catch announced CAUGHT_FIRE")
	assert_true(burn_at >= 0.0, "the target read as burning during the window")
	assert_true(fired_at.size() == 1 and burn_at >= 0.0 and burn_at - fired_at[0] <= 1.5,
		"the target caught within 1.5 s of the burst")
	assert_eq(hits.size(), 9, "the burst spends 9 damage pulses")
	assert_eq(paid, 45, "the 45 direct damage lands as 9 x 5")
	assert_true(hits[0].data["target_part"] == foe_part, "the pulses went to the enemy's part")
	assert_true(foe_part.def != null and foe_part.integrity == foe_part.def.integrity - 27,
		"the part wore ChDamage's half of each pulse (9 x round(5 x 0.5))")
	assert_true(foe.chassis.global_position.distance_to(flame.anchor_world()) <= 40.0,
		"the enemy stayed inside the flamethrower's 40-cell reach")
	_complete()

# The hearth charges for 1 s, then rings fire into the air cells 2 cells out from the own hull
# every 0.25 s and pays the bodies that overlap that ring. The near hull's box touches the ring
# (its own hull 10 cells out from the hearth's hull) and the far hull 40 cells out does not,
# so only the near one pays. No enemy part is mounted, so no enemy status can move the HP count.
# A mid-window break cannot move these totals: each pulse takes its body walk before it fills (ChBehaviour._bodies),
# and a broken part's body belongs to no chariot, so a later pulse drops rather than switching to bare HP.
const HEARTH_GAP := 10  # origins apart, so the near hull's box meets the 2-cell ring
const HEARTH_FAR := 40  # the control hull, clear of the ring, which has to pay nothing
const HEARTH_CHARGE_TICKS := 295  # 4.92 s: the 4 s cooldown fired and the 1 s charge is not done
const HEARTH_PULSE_TICKS := 135  # 2.25 s: 9 pulses at 0.25 s plus margin
const RING := 2  # cells the ring sits out from the own hull, the brief's number

func test_hearth_damages_touching_enemy_only_after_charge() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"hearth"]]), catalog, 0, ORIGIN, false)
	var near: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(HEARTH_GAP, 0), false)
	var far: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(HEARTH_FAR, 0), false)
	var hearth := _part_of(at, [0])
	assert_true(hearth != null and hearth.behaviour != null, "the hearth mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, near, far]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	var hull := Rect2(at.chassis.global_position - Vector2(at.body_def.size) * 0.5, Vector2(at.body_def.size))
	var band := hull.grow(float(RING))
	var near_hp := near.hp
	var far_hp := far.hp
	for _charge in HEARTH_CHARGE_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
	# Nothing of the charge may pay: the ring only opens once the 1 s charge is done.
	assert_eq(hits.size(), 0, "the charge dealt nothing")
	assert_eq(near.hp, near_hp, "so the touching hull is unharmed")
	assert_eq(far.hp, far_hp, "and so is the control hull")
	var peak := 0
	for _pulse in HEARTH_PULSE_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
		# The ring's own readback: fire cells inside the band the hearth fills.
		peak = maxi(peak, world.count_materials(Rect2i(band)).get(&"fire", 0))
	var paid := 0
	for hit in hits:
		paid += hit.data["hp_damage"]
	# The ring band is 2 cells wide, so a hull whose box meets it pays and one 30 cells clear does not.
	var near_box := Rect2(near.chassis.global_position - Vector2(near.body_def.size) * 0.5,
		Vector2(near.body_def.size))
	assert_true(Rect2(band).intersects(near_box) and not Rect2(hull).encloses(near_box),
		"the near hull's box sits in the ring band (hull %s band %s near %s)"
		% [hull.get_center(), band, near_box])
	assert_true(peak >= 1, "the ring left fire cells in the band (peak %d)" % peak)
	assert_eq(hits.size(), 9, "9 pulses paid the touching hull")
	assert_eq(paid, 45, "the hearth's 45 lands as 9 x 5")
	assert_eq(near.hp, near_hp - 45, "all of it on the near hull")
	assert_eq(far.hp, far_hp, "and the control hull paid nothing")
	_complete()

# The ring of fire expands from the part's own anchor: radius 0 -> 24 in 1 s, fire into the air cells
# on the circumference every 0.1 s, and deal_hit once per body the first time the ring crosses it,
# on both sides including the chassis the part hangs on. The own hull's centre sits 12 cells out and
# the enemy's 15, so both cross; the far hull's 40 never does.
# The water pool is not part of the rule: it keeps the ring's own part out of ChPartRuntime's burning
# transition (6 water cells douse), so the own HP below is the ring's hit alone rather than a hit plus
# the chariot-wide burn, which the ember test reads separately. The ring still fills fire in air cells,
# which is why the pool sits inside the ring's reach and the ring's fill never replaces it.
# The ring's two hits are a pinned window total, and the walk each step takes (ChBehaviour._bodies)
# runs before the fill, so no part can break mid-window and drop a later crossing (see that helper's note).
# shortcut: DOUSE_CELLS is ChPartRuntime's own 6-cell rule, pinned by tests/battle/test_part_runtime.gd.
# A doused part stays unburning whatever the ring writes next to it.
const RING_NEAR := 20  # origins apart, so the enemy hull's centre is 15 cells from the ring anchor
const RING_FAR := 40  # the control hull, 35 cells out, which the 24-cell ring never crosses
const RING_TICKS := 422  # 4.03 s to the 6 s cooldown's first fire, plus the 1 s ring
const RING_POOL := Rect2i(120, 132, 12, 12)  # water inside the ring's first steps

func test_ring_of_fire_hits_self_and_enemy_once_each() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[1], &"ring_of_fire"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(RING_NEAR, 0), false)
	var ctl: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(RING_FAR, 0), false)
	var ring := _part_of(at, [1])
	assert_true(ring != null and ring.behaviour != null, "the ring mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at, foe, ctl]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	# Water around the ring's own mount keeps it out of the burning transition (see the note above).
	# shortcut: the pool is written before the settle, so the sim cannot have moved it by the reads below.
	# A water cell survives the sim, so the douse holds for the whole ring window.
	assert_eq(world.fill_rect(RING_POOL, &"water"), 12 * 12, "water pool laid around the ring's mount")
	var at_hp := at.hp
	var foe_hp := foe.hp
	var ctl_hp := ctl.hp
	var anchor := ring.anchor_world()
	var ring_rect := Rect2i(Vector2i(anchor) - Vector2i(24, 24), Vector2i(49, 49))
	var peak := 0
	for _tick in RING_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
		# The ring's fill read back during the run: a post-loop read would miss consumed fire.
		peak = maxi(peak, world.count_materials(ring_rect).get(&"fire", 0))
	var paid := 0
	for hit in hits:
		paid += hit.data["hp_damage"]
	# The crossing distances the ring reads: the own hull's centre is 5.8 cells out (the part hangs on the
# hull's own top row) and the enemy's 15.3, both inside the 24-cell radius; the control hull's centre
	# is 35, outside it. What the ring actually tests is the nearest point of each body box, so these
	# reads are the preconditions, not the crossing rule.
	assert_near(at.chassis.global_position.distance_to(anchor), 5.83, 0.01, "own hull centre is inside the ring")
	assert_near(foe.chassis.global_position.distance_to(anchor), 15.3, 0.1, "enemy hull centre is inside the ring")
	assert_true(ctl.chassis.global_position.distance_to(anchor) > 24.0, "the control hull never crosses")
	# The ring fills fire on the circumference, so the sim's own light sees it: the widest ring (24 cells
	# around the anchor) is read back as fire cells while the ring runs.
	assert_true(peak >= 1, "the ring left fire cells on its circumference (peak %d)" % peak)
	assert_eq(hits.size(), 2, "the ring crossed two bodies and no more")
	assert_eq(paid, 2 * ring.def.damage, "each body paid once, at 10")
	assert_eq(at.hp, at_hp - ring.def.damage, "own chariot took it, since the ring is not friendly")
	assert_eq(foe.hp, foe_hp - ring.def.damage, "and so did the enemy hull")
	assert_eq(ctl.hp, ctl_hp, "the control hull paid nothing")
	assert_true(at.hp == at_hp - 10 and ring.burning == false, "the pool kept the mount unburning, so the 10 is the hit alone")
	_complete()

# Chain 3 (spec §5.6): a Hearth that heats its own chariot pays an Ember Battery on the same chariot.
# The hearth sits on the hull's top row, so its ring writes fire cells in the air 2 cells out, which
# is inside ChPartRuntime's 5-cell sample_rect: the part catches, CAUGHT_FIRE fires, the battery hears
# it (its subscription carries no proximity) and the own pool gains 3.
# The pool is preset to 5 so the gain is visible below the cap rather than clamped away.
const EMBER_GAP := 40  # the enemy is only there to keep the fight two-sided
const EMBER_TICKS := 432  # 7.2 s: the 4 s cooldown, the 1 s charge, the ring and the gain
const EMBER_WINDOW := 3.0  # seconds of the ring the gain has to fall inside

func test_ember_battery_pays_for_own_hearth() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[0], &"hearth"], [[1], &"ember_battery"]]), catalog, 0, ORIGIN, false)
	var foe: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([]), catalog, 1, ORIGIN + Vector2(EMBER_GAP, 0), false)
	var hearth := _part_of(at, [0])
	var battery := _part_of(at, [1])
	assert_true(hearth != null and battery != null and hearth.behaviour != null and battery.behaviour != null,
		"the hearth and the battery mounted and behave")
	var rigs: Array[ChChariotRuntime] = [at, foe]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var gained_at: Array[float] = []
	var caught: Array[ChEvent] = []
	var fired_at: Array[float] = []
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.ENERGY_GAINED,
		func(event: ChEvent): gained_at.append(ctx.time))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.CAUGHT_FIRE, func(event: ChEvent): caught.append(event))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(event: ChEvent): fired_at.append(ctx.time))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	# The pool starts below the cap so a gain lands visibly rather than clamped away.
	at.energy.value = 5.0
	var at_hp := at.hp
	var peak := 0
	var hull := Rect2(at.chassis.global_position - Vector2(at.body_def.size) * 0.5, Vector2(at.body_def.size))
	var band := Rect2i(hull.grow(float(RING)))
	for _tick in EMBER_TICKS:
		ctx.tick(TICK, [0.0, 0.0])
		# The ring's fill read where the own parts sample it.
		peak = maxi(peak, world.count_materials(band).get(&"fire", 0))
	# Chain 3 read: the hearth's own ring lights the chariot, and the battery pays for that risk.
	assert_true(peak >= 3, "the ring left fire where the own parts sample it (peak %d)" % peak)
	assert_true(caught.size() >= 1, "the catch announced CAUGHT_FIRE")
	# The catch names the part that went up, so the risk below is this chariot's own part going alight
	# rather than a catch somewhere else in the fight.
	assert_true(caught[0].source == hearth or caught[0].source == battery,
		"and the part that caught sits on the hearth's own chariot")
	assert_true(gained_at.size() >= 1, "so the battery announced ENERGY_GAINED")
	assert_true(fired_at.size() >= 1 and gained_at[0] - fired_at[0] <= EMBER_WINDOW,
		"the gain fell within 3 s of the hearth's fire")
	assert_near(at.energy.value, 6.0, 0.0001, "the pool paid the hearth's 2 and gained the battery's 3")
	# The battery's cooldown keeps a second catch inside 0.5 s out, which Ember Battery's own test pins
	# in the melee suite; what this test adds is that the catch comes from the part's own side.
	# shortcut: a catch from the other side is that suite's subject, not this chain's.
	# The risk being paid for, pinned rather than claimed: the hearth spends energy (def.energy_cost 2),
	# never HP, and no body was deal_hit here (the foe hull sits 40 cells out, clear of the 2-cell ring),
	# so the only way this chariot loses HP is ChDamage.burn_tick, which the loop runs once a part burns.
	assert_true(hits.size() == 0, "nothing was hit, so only the burn could move the HP (%d hits)" % hits.size())
	assert_true(at.hp < at_hp, "and the burn the catch started took HP off that chariot (%d -> %d)"
		% [at_hp, at.hp])
	_complete()
