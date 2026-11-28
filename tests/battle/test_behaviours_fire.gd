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
const PRESS := [true, true]  # both sides press every tick: a part fires the moment it is ready
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
# numbers (cost, cooldown, damage, reach) off the .tres and gets the behaviour
# the .tres names.
# damage_scale > 1 hands the Flamethrower and the Hearth a copy of their def with that many times the
# damage, so a test can show the pulses are cut from def.damage rather than from a constant.
func _catalog(damage_scale: int = 1) -> ChCatalog:
	var loaded := ChCatalog.load_default()
	var defs: Array[ChPartDef] = []
	for id in [&"flamethrower", &"hearth", &"ring_of_fire", &"ember_battery", &"strut"]:
		var def: ChPartDef = loaded.part(id)
		assert_true(def != null, "%s loads from res://game/data/parts" % id)
		if damage_scale != 1 and id in [&"flamethrower", &"hearth"]:
			var copy := _copy_def(def)
			copy.damage *= damage_scale
			def = copy
		if id == &"strut":
			# Task 5: the C42 Strut carries 50 integrity, which breaks inside the 9-pulse window, and a
			# broken part stops sampling the fire it stands in. The plain shell this test aims at is the
			# old 100-integrity mount, so the def is copied and raised rather than the shared .tres edited.
			var shell := _copy_def(def)
			shell.integrity = 100
			def = shell
		# The emitters stay unlimited-charge parts: the brief never spends charges on them.
		# A charge-limited emitter would read charges_left in process, and the loop's -1 sentinel
		# means unlimited, so a limited behaviour would have to park cooldown_left at INF (Task 13's
		# convention). Not tested here because no fire emitter in the slice is limited.
		defs.append(def)
	# The rig's HP grows with the scale, so a scaled burst still lands whole on a live target.
	var rig := _rig()
	rig.hp *= damage_scale
	var catalog := ChCatalog.from_defs(defs, [rig])
	for pair in [[&"flamethrower", true], [&"hearth", true], [&"ring_of_fire", true],
	 [&"ember_battery", true], [&"strut", true]]:
		# Every part carries its behaviour script, even one that does nothing: the emitters must carry
		# theirs as the .tres stand, or a fire would be no-ops.
		var has: bool = catalog.part(pair[0]).behaviour != null
		assert_eq(has, pair[1], "%s behaviour is%s as the .tres stand" % [pair[0], "" if pair[1] else " left out"])
	return catalog


# A field-by-field copy of a def: ChPartDef's fields are plain vars, which Resource.duplicate()
# does not copy, so a test that changes one field copies them all.
func _copy_def(def: ChPartDef) -> ChPartDef:
	var copy := ChPartDef.new()
	for prop in def.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(prop.name, def.get(prop.name))
	return copy


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

func test_fx_refuses_a_parent_that_moves() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var holder := _track(Node2D.new())
	assert_true(ChFx.spawn(world, &"muzzle", Vector2(100, 100)) != null, "the world takes a baked effect")
	assert_true(ChFx.spawn(holder, &"muzzle", Vector2.ZERO) == null, "a node that moves does not")
	_complete()


# A one-shot's frames fade themselves in and out, but a loop has no start or end of its own: taken off
# the tree mid-cycle it pops, which reads as the effect breaking rather than ending. So a loop comes up
# faded and its owner ends it with fade_out() instead of queue_free().
func test_looping_fx_fades_in_and_out() -> void:
	var world: PixelWorld = await make_world()
	var fx := ChFx.spawn(world, &"flamethrower", Vector2(120, 140), Vector2.RIGHT)
	assert_true(fx != null, "the looping sheet spawns")
	assert_true(fx.modulate.a < 1.0, "it comes in faded rather than popped on (%f)" % fx.modulate.a)
	for _tick in 20:
		fx._physics_process(TICK)
	assert_near(fx.modulate.a, 1.0, 0.0001, "and ramps up to full")
	fx.fade_out()
	fx._physics_process(ChFx.FADE_OUT * 0.5)
	assert_near(fx.modulate.a, 0.5, 0.01, "fade_out() takes it down over its own time, not at once")
	fx._physics_process(ChFx.FADE_OUT)
	assert_true(fx.is_queued_for_deletion(), "and it frees itself once faded")
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
	await _hearth_case(1)

# The pulses split the def's damage: twice the def damage pays twice per pulse.
func test_hearth_pulses_follow_def_damage() -> void:
	await _hearth_case(2)

func _hearth_case(scale: int) -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(scale)
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
		ctx.tick(TICK, [0.0, 0.0], PRESS)
	# Nothing of the charge may pay: the ring only opens once the 1 s charge is done.
	assert_eq(hits.size(), 0, "the charge dealt nothing")
	assert_eq(near.hp, near_hp, "so the touching hull is unharmed")
	assert_eq(far.hp, far_hp, "and so is the control hull")
	var peak := 0
	for _pulse in HEARTH_PULSE_TICKS:
		ctx.tick(TICK, [0.0, 0.0], PRESS)
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
	assert_eq(paid, 36 * scale, "the hearth's %d lands as 9 x %d" % [36 * scale, 4 * scale])
	# The band's fire cells give the near hull Flame too, which burns its HP past the pulses.
	assert_true(near.hp <= near_hp - 36 * scale, "all of it on the near hull (%d -> %d)" % [near_hp, near.hp])
	assert_eq(far.hp, far_hp, "and the control hull paid nothing")
	_complete()

# The ring of fire expands from the part's own anchor: radius 0 -> 36 in 1 s, fire into the air cells
# on the circumference every 0.1 s, and deal_hit once per enemy body the first time the ring crosses
# it. Its own chariot takes no hit (the balance pass's call: the ring killed its own chariot). The own
# hull's centre sits 6 cells out and the enemy's 15, so both are inside; the far hull's 55 never is.
# The water pool is not part of the rule: its Wet cancels the Flame the ring's fire gives the own
# chariot, so an unchanged own HP below shows the ring paid it nothing rather than hiding a burn,
# which the ember test reads separately. The ring still fills fire in air cells,
# which is why the pool sits inside the ring's reach and the ring's fill never replaces it.
# The ring's two hits are a pinned window total, and the walk each step takes (ChBehaviour._bodies)
# runs before the fill, so no part can break mid-window and drop a later crossing (see that helper's note).
# A doused part stays unburning whatever the ring writes next to it.
const RING_NEAR := 20  # origins apart, so the enemy hull's centre is 15 cells from the ring anchor
const RING_FAR := 60  # the control hull, 55 cells out, which the 36-cell ring never crosses
const RING_TICKS := 302  # 5.03 s: the 4 s cooldown's first fire, plus the 1 s ring
const RING_POOL := Rect2i(120, 132, 12, 12)  # water inside the ring's first steps

func test_ring_of_fire_hits_enemy_once_not_self() -> void:
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
	var ring_rect := Rect2i(Vector2i(anchor) - Vector2i(36, 36), Vector2i(73, 73))
	var peak := 0
	for _tick in RING_TICKS:
		ctx.tick(TICK, [0.0, 0.0], PRESS)
		# The ring's fill read back during the run: a post-loop read would miss consumed fire.
		peak = maxi(peak, world.count_materials(ring_rect).get(&"fire", 0))
	var paid := 0
	for hit in hits:
		paid += hit.data["hp_damage"]
	# The crossing distances the ring reads: the own hull's centre is 5.8 cells out (the part hangs on the
	# hull's own top row) and the enemy's 15.3, both inside the 36-cell radius; the control hull's centre
	# is 55, outside it. What the ring actually tests is the nearest point of each body box, so these
	# reads are the preconditions, not the crossing rule.
	assert_near(at.chassis.global_position.distance_to(anchor), 5.83, 0.01, "own hull centre is inside the ring")
	assert_near(foe.chassis.global_position.distance_to(anchor), 15.3, 0.1, "enemy hull centre is inside the ring")
	assert_true(ctl.chassis.global_position.distance_to(anchor) > 36.0, "the control hull never crosses")
	# The ring fills fire on the circumference, so the sim's own light sees it: the widest ring (36 cells
	# around the anchor) is read back as fire cells while the ring runs.
	assert_true(peak >= 1, "the ring left fire cells on its circumference (peak %d)" % peak)
	assert_eq(hits.size(), 1, "the ring crossed the enemy hull and no more")
	assert_eq(paid, ring.def.damage, "which paid once, at the def's damage")
	# The ring's fire cells give the enemy hull Flame too, which burns its HP past the hit.
	assert_true(foe.hp <= foe_hp - ring.def.damage, "on the enemy hull (%d -> %d)" % [foe_hp, foe.hp])
	assert_eq(at.hp, at_hp, "own chariot took nothing, though its hull is inside the ring")
	assert_eq(ctl.hp, ctl_hp, "the control hull paid nothing")
	assert_true(not ring.is_burning(), "the pool kept the mount unburning, so the own HP read is the ring's alone")
	_complete()

# Chain 3 (spec §5.6): a Hearth that heats its own chariot pays an Ember Battery on the same chariot.
# The hearth sits on the hull's top row, so its ring writes fire cells in the air 2 cells out, which
# is inside the sample rects: a holder catches (its first Flame), the battery hears
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
	var gained_amount: Array[float] = []
	var caught: Array[ChEvent] = []
	var fired_at: Array[float] = []
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.ENERGY_GAINED,
		func(event: ChEvent):
			gained_at.append(ctx.time)
			gained_amount.append(float(event.data.get("amount", -1.0))))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.STATUS_GAINED, func(event: ChEvent):
		if ChEvent.caught_fire(event):
			caught.append(event))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.PART_FIRED, func(event: ChEvent): fired_at.append(ctx.time))
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	# The pool starts below the cap so a gain lands visibly rather than clamped away.
	at.energy.value = 5.0
	var at_hp := at.hp
	var peak := 0
	var hull := Rect2(at.chassis.global_position - Vector2(at.body_def.size) * 0.5, Vector2(at.body_def.size))
	var band := Rect2i(hull.grow(float(RING)))
	for _tick in EMBER_TICKS:
		ctx.tick(TICK, [0.0, 0.0], PRESS)
		# The ring's fill read where the own parts sample it.
		peak = maxi(peak, world.count_materials(band).get(&"fire", 0))
	# Chain 3 read: the hearth's own ring lights the chariot, and the battery pays for that risk.
	assert_true(peak >= 1, "the ring left fire where the own parts sample it (peak %d)" % peak)
	assert_true(caught.size() >= 1, "the catch announced a first Flame stack")
	# The catch names the holder that went up, so the risk below is this chariot's own going alight
	# rather than a catch somewhere else in the fight.
	assert_true(caught[0].side == at.side, "and what caught sits on the hearth's own chariot")
	assert_true(gained_at.size() >= 1, "so the battery announced ENERGY_GAINED")
	assert_true(fired_at.size() >= 1 and gained_at[0] - fired_at[0] <= EMBER_WINDOW,
		"the gain fell within 3 s of the hearth's fire")
	assert_near(at.energy.value, 5.0, 0.0001, "the pool paid the hearth's 3 and gained the battery's 3")
	assert_near(gained_amount[0], 3.0, 0.0001, "the event carries the energy that landed")
	# The battery's cooldown keeps a second catch inside 0.5 s out, which Ember Battery's own test pins
	# in the melee suite; what this test adds is that the catch comes from the part's own side.
	# shortcut: a catch from the other side is that suite's subject, not this chain's.
	# The risk being paid for, pinned rather than claimed: the hearth spends energy (def.energy_cost 2),
	# never HP, and no body was deal_hit here (the foe hull sits 40 cells out, clear of the 2-cell ring),
	# so the only way this chariot loses HP is its body's Flame from the ring's own fire.
	assert_true(hits.size() == 0, "nothing was hit, so only the burn could move the HP (%d hits)" % hits.size())
	assert_true(at.hp < at_hp, "and the burn the catch started took HP off that chariot (%d -> %d)"
		% [at_hp, at.hp])
	_complete()
