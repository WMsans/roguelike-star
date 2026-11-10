extends ChTest

# Task 10: the battle context — the per-tick loop, the single damage entry point (deal_hit), part
# breaking (ChChariotRuntime.break_part) and the behaviour base Tasks 12-14 subclass.
# World-backed: the rigs come out of ChChariotBuilder, so the joints break_part frees and the
# anchors deal_hit's proximity modifiers measure against are the real ones.
# The behaviours are test doubles: ContextBehaviour below has the shape game/battle/behaviours/
# ch_behaviour.gd ships (a `part` plus the five hooks), and each double overrides only the hook its
# test counts. ChPartRuntime.behaviour is Object-typed and the context calls the hooks off an
# untyped local, so a double stands in for the script Tasks 12-14 file on that seam.
# shortcut: rig numbers are literals per def below; the slice's tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # near the surface, per Task 9's spawn ruling
const FAR_ORIGIN := Vector2(320, 140)  # a second rig, clear of the first
const TICK := 1.0 / 60.0  # one 60 fps frame: the delta the live game ticks at
const PRESS := [true]  # the one rig presses every tick: a part fires the moment it is ready
const READY_TICKS := 78  # over 1 s: a 1 s cooldown has gone ready and asked for energy
const TWO_S_TICKS := 126  # 2.1 s: a 1 s cooldown gets two fires into this window
const AFTER_BREAK_TICKS := 60  # the ticks a fight keeps running after something broke
const THREE_S_TICKS := 186  # 3.1 s: a 1 s cooldown fires three times in this window
const BODY_HP := 100  # every rig's HP, so a hit's arithmetic reads
const DAMAGE := 20  # the damage every deal_hit below sends
const MODIFIER_RANGE := 24.0  # the Freeze Charge's range, in cells

# The behaviour base's shape: `part` plus the five hooks, all no-ops, so a double overrides only
# what its test counts and inherits the rest. The real base is game/battle/behaviours/ch_behaviour.
class ContextBehaviour:
	extends RefCounted

	# The doubles below leave this unset; the context reaches a behaviour through its part.
	var part: ChPartRuntime = null

	# Declared so an override can change one hook and inherit the rest.
	# shortcut: no-ops here, and a part with no behaviour at all is never asked.
	func setup(ctx) -> void: pass

	func fire(ctx) -> void: pass

	func process(ctx, delta) -> void: pass

	func modify_hit(ctx, hit) -> void: pass

	# A behaviour that held a looping fx would stop it here; these doubles hold none.
	func teardown() -> void: pass

# A double that counts the fires the loop owes it. Counting 2 fires in 2.1 s of ticks is the
# whole loop: asked for energy, paid it, called fire, and reset the cooldown to get back here.
class FireDouble:
	extends ContextBehaviour

	# Per-instance state: a script's vars belong to the instance, as the probe of this shape showed.
	var fired := 0

	func fire(ctx) -> void: fired += 1

# A double whose fire takes another part out of the fight, the way a shot can break or freeze a
# part mid-volley: the volley must not then pay for or fire that part.
class BreakerDouble:
	extends FireDouble

	var victim: ChPartRuntime = null

	func fire(ctx) -> void:
		fired += 1
		victim.broken = true

# A double that subscribes where a real behaviour subscribes (in setup, listener = self) and
# counts what it still hears. break_part unsubscribes that listener, so the count stays empty.
class ListenerDouble:
	extends ContextBehaviour

	# What this listener heard; the test reads it back after the break.
	var heard: Array[StringName] = []

	func setup(ctx) -> void: _listen(ctx)

	func _listen(ctx) -> void:
		# A lambda captures locals only, so sink aliases the member array; an Array is a
		# reference, so the appends land in heard. Same shape as test_part_runtime.gd's _hears.
		var sink := heard
		(ctx.bus).subscribe(self, ChEvent.PART_BROKEN, func(event: ChEvent): sink.append(event.type))

# A passive double of the Freeze Charge's shape: it changes a hit travelling from a part near it.
class ModifierDouble:
	extends ContextBehaviour

	# The hit dict is the same object deal_hit built, so mutating a key is the interface.
	# shortcut: the base declares modify_hit, so this double inherits setup/fire/process instead.
	func modify_hit(ctx, hit) -> void: hit["multiplier"] = 2.0

# One part def with the numbers a test needs: cost 0 and cooldown 0 is a passive part, which never
# asks for energy at all. extensions is how many things can bolt onto it, which is what a child
# mount needs ChPartDef.extension_slots to own.
func _part(id: StringName, cost: int, cooldown: float, integrity: int, extensions: int,
	reach := 0.0) -> ChPartDef:
	var def := ChPartDef.new()
	# The catalog keys on this id, and a layout's part_id looks it back up, so the id is the wire.
	def.id = id
	def.energy_cost = cost
	def.cooldown = cooldown
	def.damage = DAMAGE
	def.integrity = integrity
	# A 2x2 footprint keeps sample_rect at 6 cells, which the burn test's fire blob covers.
	def.size = Vector2i(2, 2)
	# proximity_range is a passive's reach in cells; 0 means it modifies nothing.
	def.proximity_range = reach
	def.charges = -1
	var slots: PackedVector2Array = []
	for at in range(extensions):
		# Extension slots hang 4 cells above the anchor, +x being the facing direction.
		slots.append(Vector2(4 * at, -4))
	def.extension_slots = slots
	return def

# The body every rig sits on: four slots, 6 and 12 cells from the first (inside the modifier's
# range) and 30 (outside it), so a test picks a range case by picking a slot.
func _body(cap: int) -> ChBodyDef:
	# energy_cap is what the chariot starts its pool at, so 0 leaves a ready part unpaid by a press
	# instead of firing, which is what Review Focus 3 sets up.
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = BODY_HP
	def.energy_cap = cap
	def.energy_regen = 0.0
	def.size = Vector2i(10, 6)
	# The hull material stamps a body PixelRigidBody can join; these defs leave material empty,
	# which the builder turns into wood rather than joining nothing.
	def.slots = PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(12, 0), Vector2(30, 0)])
	return def

# One layout mounting [[path, part_id]] in mount order; place() takes Array[int].
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	# The id has to match _body's, or anchor_of answers ZERO for every part and the distances below
	# read 0 rather than the slot numbers.
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout

func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps

# The defs a rig mounts, keyed by id: from_defs is how a hand-built catalog gets built in code.
func _catalog(cap: int) -> ChCatalog:
	# cap is what ChEnergy starts its pool at, so 0 is the starved rig the break test wants.
	var parts: Array[ChPartDef] = [
		_part(&"strut", 0, 0.0, 100, 2),
		_part(&"gun", 1, 1.0, 100, 0),
		_part(&"child", 1, 1.0, 100, 0),
		_part(&"modifier", 0, 0.0, 100, 0, MODIFIER_RANGE),
		_part(&"target", 0, 0.0, 10, 0),
	]
	return ChCatalog.from_defs(parts, [_body(cap)])

# The floor the chariots stand on; fill_rect returns the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")

# The part the builder put at a layout path; runtime.parts keeps every part's own path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null

# A battle context over `rigs` (index = side), with every mounted behaviour getting the setup
# call that subscribes it. bus is the battle's one bus, so it is what break_part unsubscribes.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	# A fresh bus per test, so no subscription from one test is still heard in the next.
	# shortcut: nothing frees it; it is RefCounted and the test's callbacks die with it.
	ctx.world = world
	# time is the fight's clock, which a timed behaviour counts against rather than keeping.
	# shortcut: no test below reads ctx.time; the HUD test in Task 15 does.
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	# index = side is the interface's own note, so rigs arrive in side order.
	# shortcut: these tests hand one rig each, so the index is the rig's own side.
	ctx.chariots = rigs
	for rig in rigs:
		for part in rig.parts:
			# setup is where a behaviour subscribes, before the first tick can emit anything.
			# shortcut: a part with no behaviour has nothing to subscribe, which is most parts here.
			if part.behaviour != null:
				part.behaviour.setup(ctx)
	return ctx

# A ready part fires on a press and is paid for it. Two fires in 2.1 s is the whole loop: pressed,
# paid, called fire, then reset the cooldown. A cooldown left at 0 would report ready every tick
# after the first, so the count of 2 is also the proof of the reset.
func test_ready_part_fires_on_press() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(20)
	var layout := _mount([[[0], &"gun"]])
	# The gun is the rig's only part: cost 1, cooldown 1 s, so it goes ready just after 1 s.
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	# The double counts the fires; the loop calls fire only for a part whose cost it just paid.
	var gun := _part_of(rig, [0])
	var double := FireDouble.new()
	gun.behaviour = double
	# ChBattleContext.chariots is a typed array, so the rigs arrive typed: an untyped Array is
	# refused on assignment, which is the runner's "Invalid assignment of property" error.
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	# ChEnergy.new starts the pool at cap, which the builder calls from the body def.
	assert_near(rig.energy.value, 20.0, 0.001, "the pool starts at cap")
	for _tick in TWO_S_TICKS:
		ctx.tick(TICK, [0.0], PRESS)
	assert_eq(double.fired, 2, "two fires in 2.1 s of ticks")
	_complete()

# Review Focus 3. The rig's pool cap is 0, so the strut's child is ready but cannot pay its 1
# energy. Breaking the strut breaks the child too and frees both joints; 60 more pressed ticks
# of the fight raise nothing and fire nothing, because a broken part is not ready.
func test_break_cascades_and_broken_parts_stay_quiet() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(0)
	var layout := _mount([[[0], &"strut"], [[0, 0], &"child"]])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	var strut := _part_of(rig, [0])
	var child := _part_of(rig, [0, 0])
	# _part_of records and answers null, so a mount that failed says so before the reads below.
	assert_true(strut != null and child != null, "the strut and its child both mounted")
	# The builder sets parent/children both ways, which is the tree break_part recurses into.
	assert_eq(child.parent, strut, "the child hangs off the strut")
	assert_eq(strut.children.size(), 1, "and the strut carries it")
	var strut_double := ListenerDouble.new()
	strut_double.part = strut
	strut.behaviour = strut_double
	# The rig's pool starts at cap 0 with 0 regen, so nothing here can pay any cost.
	var ctx: ChBattleContext = _battle(world, catalog, [rig])
	var watcher := RefCounted.new()
	var events: Array[ChEvent] = []
	var sink := events
	(ctx.bus).subscribe(watcher, ChEvent.PART_BROKEN, func(event: ChEvent): sink.append(event))
	for _tick in READY_TICKS:
		# The child's 1 s cooldown counts down here; past 0 it is ready but cannot pay its 1 energy.
		# shortcut: the same call runs again after the break below, which is what has to be proven
		# quiet: a broken part must never fire.
		ctx.tick(TICK, [0.0], PRESS)
	assert_true(child.is_ready(), "the child is ready and unpaid")
	assert_near(child.cooldown_left, 0.0, 0.0001, "it reached ready and stayed there")
	# The pool cannot pay it: cap 0, 0 regen, and no direction held to spend the drive cost.
	assert_near(rig.energy.value, 0.0, 0.0001, "the pool is empty")
	# Review Focus 3: a part breaking mid-fight with a queued child hanging off it.
	# shortcut: the brief names break_part(part); the ctx argument is provisional, since the steps
	# it owes need the bus for unsubscribe_all and emit.
	rig.break_part(strut, ctx)
	assert_true(strut.broken, "the strut is broken")
	assert_true(child.broken, "the child broke with it, from the recursion")
	assert_true(not (child.is_ready()), "a broken child is no longer ready")
	assert_eq(events.size(), 2, "one PART_BROKEN each for the strut and its child")
	# The strut's own behaviour unsubscribed before the emit, so it heard neither event.
	# shortcut: zero rather than one is the ordering's observable, as noted above.
	assert_eq(strut_double.heard, [], "the broken part's behaviour heard nothing, so it is unsubscribed")
	for _tick in AFTER_BREAK_TICKS:
		# shortcut: the world steps too, so the freed joints are processed and the bodies fall.
		await Engine.get_main_loop().process_frame
		world.step(1)
		var fired := ctx.tick(TICK, [0.0], PRESS)
		assert_eq(fired, [0], "a broken part never fires")
	assert_true(not is_instance_valid(strut.joint), "the strut's joint is freed")
	assert_true(not is_instance_valid(child.joint), "and so is the child's, so no joint is orphaned")
	_complete()

# deal_hit is the single damage entry point: a passive whose def's proximity_range covers the
# source is asked to change the hit before ChDamage applies it. The double sets multiplier = 2, so
# an in-range modifier costs the target twice the HP and an out-of-range one costs it once.
# shortcut: the same hit also wears the part's integrity and breaks it at 0, which is the entry
# point's other half. ChDamage keeps the multiplier off the wear, so the wear assert reads the
# unmultiplied half of a 20-damage hit against a 10-integrity target.
func test_deal_hit_applies_modifiers_in_range() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(20)
	# slot 0 is the source gun, slot 1 the near modifier (6 cells), slot 2 the part that gets hit.
	# No world.step here: nothing drives these rigs, so the anchors stay where the builder put them
	# and the distances below are the slot numbers. Task 9's settle tests cover a rig standing up.
	var near_layout := _mount([[[0], &"gun"], [[1], &"modifier"], [[2], &"target"]])
	var near: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), near_layout, catalog, 0, ORIGIN, false)
	var near_gun := _part_of(near, [0])
	var near_mod := _part_of(near, [1])
	var near_target := _part_of(near, [2])
	# _part_of records a miss and answers null, so a mount that failed says so before these reads.
	assert_true(near_gun != null and near_mod != null and near_target != null, "the near rig mounted")
	# The modifier's double is the passive: it changes the multiplier of a hit from a part near it.
	near_mod.behaviour = ModifierDouble.new()
	# The source keeps no behaviour, so the source's own hook is optional: deal_hit reads a null
	# slot there and asks nothing. Every other part here is behaviour-less too, so the same rule
	# covers them, which is what the wheel and the strut do in the slice as well.
	var near_rigs: Array[ChChariotRuntime] = [near]
	var ctx_near: ChBattleContext = _battle(world, catalog, near_rigs)
	# 6 cells is inside the 24-cell range, so the modifier is asked and doubles the hit's HP damage.
	assert_near(near_mod.anchor_world().distance_to(near_gun.anchor_world()), 6.0, 0.001, "the modifier sits inside its 24-cell range")
	var hp_before := near.hp
	ctx_near.deal_hit(near_gun, near_target.body, DAMAGE)
	assert_eq(near.hp, hp_before - 2 * DAMAGE, "the in-range modifier doubled the HP damage")
	assert_eq(near_target.integrity, 0, "the part wore the unmultiplied half of the damage")
	assert_true(near_target.broken, "a part at 0 integrity breaks, which deal_hit owes")
	# A second rig on the enemy's side, same three parts, its modifier in body slot 3: 30 cells from
	# the source, outside the 24-cell range, so it is asked nothing and the hit costs 1x damage.
	var far_layout := _mount([[[0], &"gun"], [[2], &"target"], [[3], &"modifier"]])
	var far: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), far_layout, catalog, 1, FAR_ORIGIN, false)
	var far_gun := _part_of(far, [0])
	var far_target := _part_of(far, [2])
	var far_mod := _part_of(far, [3])
	assert_true(far_gun != null and far_target != null and far_mod != null, "the far rig mounted")
	var far_rigs: Array[ChChariotRuntime] = [far]
	var ctx_far: ChBattleContext = _battle(world, catalog, far_rigs)
	far_mod.behaviour = ModifierDouble.new()
	assert_near(far_mod.anchor_world().distance_to(far_gun.anchor_world()), 30.0, 0.001, "the modifier sits outside its 24-cell range")
	var far_hp := far.hp
	ctx_far.deal_hit(far_gun, far_target.body, DAMAGE)
	assert_eq(far.hp, far_hp - DAMAGE, "an out-of-range modifier left the hit at 1x damage")
	# The near rig's chassis takes a hit too, which resolves to no part: ChDamage's hit_body rule.
	var chassis_before := near.hp
	ctx_near.deal_hit(near_gun, near.chassis, DAMAGE)
	assert_eq(near.hp, chassis_before - 2 * DAMAGE, "the multiplier reaches a chassis hit the same way")
	_complete()

# Burning is chariot-wide, not per part: while any of a chariot's parts burns, its HP loses one
# dps * delta tick, so two burning parts burn no harder than one. Both parts here stand in fire, so
# one second of ticks costs about 5 HP rather than about 10.
# shortcut: the window is a range because a partial point pays nothing, which is what the runtime's
# float accumulator keeps and the assert below reads back: hp is an int per the plan, so the
# fraction cannot live in it.
func test_burning_damages_hp_once() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(20)
	# Two passive parts, cost 0 and cooldown 0, so neither ever asks for energy: nothing but the
	# burn can move this rig's HP.
	var layout := _mount([[[0], &"strut"], [[1], &"modifier"]])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	# Settle first, so the sample rects asserted below are the rects apply_sample then reads.
	# shortcut: no ctx.tick while settling, so no status is sampled before the fire exists.
	for _tick in 30:
		await Engine.get_main_loop().process_frame
		world.step(1)
	var strut := _part_of(rig, [0])
	var modifier := _part_of(rig, [1])
	assert_true(strut != null and modifier != null, "both parts mounted")
	assert_true(strut.sample_rect().has_point(Vector2i(strut.anchor_world())), "the strut's rect covers itself")
	assert_true(modifier.sample_rect().has_point(Vector2i(modifier.anchor_world())), "and so does the modifier's")
	# Two burning parts, so a per-part burn would pay a double window: the assert below reads one.
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	var hp_before := rig.hp
	# The fire is re-filled every tick because the sim decides what becomes of a fire cell on its
	# own, and what this test reads is what the parts saw, not what the sand kept.
	# shortcut: fill_circle writes into air cells only, so the blob cannot bury a standing part.
	for _tick in 60:
		world.fill_circle(Vector2i(strut.anchor_world()), 3, &"fire")
		world.fill_circle(Vector2i(modifier.anchor_world()), 3, &"fire")
		await Engine.get_main_loop().process_frame
		world.step(1)
		ctx.tick(TICK, [0.0], PRESS)
		# hp is an int per the plan, so a fraction reaching it would be a house-rule break.
		# shortcut: the fraction reaching hp would also leave the accumulator at 0 below.
		assert_eq(rig.hp, int(rig.hp), "hp stays an int, so the fraction lives elsewhere")
	assert_true(rig.hp <= hp_before - 4 and rig.hp >= hp_before - 6, "one burn ticked for the chariot")
	# The fraction that has not reached a whole point stays behind, which is the reason the
	# accumulator exists: a per-tick round would have left 0 behind and burned slower.
	# shortcut: the field's name is ChChariotRuntime's own, so a rename wants this assert renamed.
	assert_true(rig.burn_damage_left > 0.0 and rig.burn_damage_left < 1.0, "a partial point stays held back")
	_complete()

# Finding 1: ChPartRuntime.charges_left reads -1 as unlimited, so `>= 0` in the loop drove a part
# that ran out of charges from 0 straight into that sentinel. is_ready now gates on the counter, so
# this test pins it: it stops at 0 and never equals the unlimited sentinel.
func test_charges_stop_at_zero_never_become_unlimited() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	# _part pins def.charges = -1, so this test moves the charge count onto its own def rather than
	# widening a helper every other test below calls.
	var limited := _part(&"gun", 1, 1.0, 100, 0)
	limited.charges = 1
	var catalog := ChCatalog.from_defs([limited], [_body(20)])
	var layout := _mount([[[0], &"gun"]])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	var gun := _part_of(rig, [0])
	assert_true(gun != null, "the gun mounted")
	assert_eq(gun.charges_left, 1, "the builder copied def.charges into the runtime")
	var double := FireDouble.new()
	gun.behaviour = double
	var rigs: Array[ChChariotRuntime] = [rig]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _tick in THREE_S_TICKS:
		ctx.tick(TICK, [0.0], PRESS)
	# One charge buys one fire: at 0 charges the part is no longer ready, so presses stop paying it.
	assert_eq(double.fired, 1, "one charge, one fire in 3.1 s of presses")
	assert_eq(gun.charges_left, 0, "the counter stopped at the last charge rather than at -1")
	assert_true(gun.charges_left != -1, "so it never reads as unlimited to Tasks 12-14 or the HUD")
	_complete()

# Finding 2: break_part leaves the part in chariot.parts with its body still in the world, so the
# scans that resolve a body by identity used to find a fallen wreck, and deal_hit paid chariot HP
# and re-wore integrity on it. The part.broken skip in both scans is what makes the comment true.
func test_hit_on_a_fallen_wreck_pays_nothing() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(20)
	# A gun plus a 10-integrity target: one 20-damage hit wears the target's 10 integrity (ChDamage
	# halves the damage for wear) down to 0, which is what makes deal_hit break it.
	var layout := _mount([[[0], &"gun"], [[1], &"target"]])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	var gun := _part_of(rig, [0])
	var target := _part_of(rig, [1])
	assert_true(gun != null and target != null, "the gun and the target mounted")
	var ctx: ChBattleContext = _battle(world, catalog, [rig])
	var hits: Array[StringName] = []
	var sink := hits
	(ctx.bus).subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): sink.append(event.type))
	var hp_before := rig.hp
	ctx.deal_hit(gun, target.body, DAMAGE)
	assert_eq(rig.hp, hp_before - DAMAGE, "a live part pays the chariot HP")
	assert_eq(target.integrity, 0, "and wears its 10 integrity to 0")
	assert_true(target.broken, "which is what deal_hit breaks it with")
	assert_eq(hits.size(), 1, "the live hit announced one HIT")
	# The same body, now a wreck hanging off the chariot by nothing: break_part freed the joint (this
	# part is a body slot, so it never had one) but left the body in the world, so a second hit
	# arrives at it. It must resolve to nobody and go nowhere.
	var hp_after_wreck := rig.hp
	ctx.deal_hit(gun, target.body, DAMAGE)
	assert_eq(rig.hp, hp_after_wreck, "the wreck paid no HP, so the hit resolved through no chariot")
	assert_eq(target.integrity, 0, "and wore no integrity again")
	assert_true(ctx.part_of_body(target.body) == null, "a broken part resolves to no part")
	assert_true(ctx.chariot_of_body(target.body) == null, "and to no chariot, so deal_hit drops the hit")
	assert_eq(hits.size(), 1, "so no second HIT was announced for the wreck")
	_complete()


# The balance runner's need: a HIT says which chariot it landed on, so a part that hurts its own
# hull (Ring of Fire pays its chassis as it grows) is not counted as damage dealt to the enemy.
func test_hit_names_the_side_it_landed_on() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog(20)
	var layout := _mount([[[0], &"gun"], [[1], &"target"]])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), layout, catalog, 0, ORIGIN, false)
	var ctx: ChBattleContext = _battle(world, catalog, [rig])
	var sides: Array = []
	(ctx.bus).subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): sides.append(event.data.get("target_side")))
	ctx.deal_hit(_part_of(rig, [0]), _part_of(rig, [1]).body, DAMAGE)
	assert_eq(sides, [0], "a hit on its own chariot names side 0")
	_complete()

# --- The volley: a press fires every ready part the pool can pay, dearest first ---

# A rig whose gun-like parts have the given costs, mounted in the given order, over a pool of
# `pool` energy and 0 regen. Parts hang off one strut with enough extension slots.
func _volley_rig(world: PixelWorld, costs: Array, pool: int) -> Array:
	var defs: Array[ChPartDef] = [_part(&"strut", 0, 0.0, 100, costs.size())]
	var mounts := [[[0], &"strut"]]
	for at in costs.size():
		var id := StringName("p%d" % at)
		defs.append(_part(id, costs[at], 1.0, 100, 0))
		mounts.append([[0, at], id])
	var catalog := ChCatalog.from_defs(defs, [_body(pool)])
	var rig: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount(mounts), catalog, 0, ORIGIN, false)
	var doubles: Array = []
	for at in costs.size():
		var part := _part_of(rig, [0, at])
		part.cooldown_left = 0.0
		var double := FireDouble.new()
		part.behaviour = double
		doubles.append(double)
	var rigs: Array[ChChariotRuntime] = [rig]
	return [rig, _battle(world, catalog, rigs), doubles]

func test_no_press_fires_nothing() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [1], 10)
	var rig: ChChariotRuntime = set[0]
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], [false])
	assert_eq(fired, [0], "no press, no fire")
	assert_eq(_part_of(rig, [0, 0]).cooldown_left, 0.0, "the part is still ready")
	assert_eq(rig.energy.value, 10.0, "the pool is unchanged")
	_complete()

func test_press_fires_every_ready_part() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [2, 1], 10)
	var rig: ChChariotRuntime = set[0]
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], PRESS)
	assert_eq(fired, [2], "both ready parts fired")
	assert_near(rig.energy.value, 7.0, 0.0001, "10 minus 2 and 1")
	for at in 2:
		assert_eq(_part_of(rig, [0, at]).cooldown_left, 1.0, "cooldown reset to def.cooldown")
	_complete()

func test_press_pays_dearest_first_and_skips() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	# The 3 is mounted second; the 2 is skipped once the 3 has paid and leaves 1.
	var set := _volley_rig(world, [2, 3, 1], 4)
	var rig: ChChariotRuntime = set[0]
	var doubles: Array = set[2]
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], PRESS)
	assert_eq(fired, [2], "the 3 and the 1 fired")
	assert_eq([doubles[0].fired, doubles[1].fired, doubles[2].fired], [0, 1, 1], "the 2 did not")
	assert_eq(_part_of(rig, [0, 0]).cooldown_left, 0.0, "the skipped part stays ready")
	assert_near(rig.energy.value, 0.0, 0.0001, "the pool is spent")
	_complete()

func test_unpaid_part_does_not_fire_later_without_press() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [2, 3, 1], 4)
	var ctx: ChBattleContext = set[1]
	var rig: ChChariotRuntime = set[0]
	ctx.tick(TICK, [0.0], PRESS)
	rig.energy.regen = 5.0
	var counts := {"n": 0}
	var watcher := RefCounted.new()
	ctx.bus.subscribe(watcher, ChEvent.PART_FIRED, func(_event: ChEvent): counts["n"] += 1)
	for _tick in 120:
		ctx.tick(TICK, [0.0], [false])
	assert_eq(counts["n"], 0, "nothing is remembered between presses")
	assert_eq((set[2][0] as FireDouble).fired, 0, "the 2-cost part has still not fired")
	_complete()

func test_press_skips_frozen_broken_and_spent() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [1, 1, 1], 10)
	var rig: ChChariotRuntime = set[0]
	_part_of(rig, [0, 0]).freeze = 100.0
	_part_of(rig, [0, 1]).broken = true
	_part_of(rig, [0, 2]).charges_left = 0
	assert_true(_part_of(rig, [0, 0]).is_frozen(), "the first part is frozen")
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], PRESS)
	assert_eq(fired, [0], "none of the three is ready")
	assert_eq(rig.energy.value, 10.0, "the pool is unchanged")
	_complete()

func test_volley_cost_sums_ready_parts() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [3, 1, 2], 10)
	var rig: ChChariotRuntime = set[0]
	_part_of(rig, [0, 2]).cooldown_left = 1.0
	assert_eq((set[1] as ChBattleContext).volley_cost(rig), 4, "3 and 1; the cooling 2 is left out")
	_complete()

func test_drive_is_paid_before_the_volley() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var set := _volley_rig(world, [2, 3], 10)
	var rig: ChChariotRuntime = set[0]
	# The 0.001 absorbs float rounding in (drive + 2) - drive, which would land a hair under 2.
	rig.energy.value = rig.energy.drive_cost * TICK + 2.0 + 0.001
	var fired := (set[1] as ChBattleContext).tick(TICK, [1.0], PRESS)
	assert_eq(fired, [1], "one part fired")
	assert_eq([set[2][0].fired, set[2][1].fired], [1, 0], "the 2-cost fired, the 3-cost could not")
	assert_near(rig.energy.value, 0.001, 0.0001, "drive and the 2 took the rest")
	_complete()

func test_press_ties_break_on_mount_order() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	# Three parts of equal cost over a pool for two: the first two mounted pay, the third does not.
	var set := _volley_rig(world, [2, 2, 2], 4)
	var doubles: Array = set[2]
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], PRESS)
	assert_eq(fired, [2], "two of the three fired")
	assert_eq([doubles[0].fired, doubles[1].fired, doubles[2].fired], [1, 1, 0], "in mount order")
	_complete()

func test_part_taken_out_mid_volley_is_not_paid() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	# The 3 fires first and breaks the 1, which was ready when the press began.
	var set := _volley_rig(world, [3, 1], 10)
	var rig: ChChariotRuntime = set[0]
	var breaker := BreakerDouble.new()
	breaker.victim = _part_of(rig, [0, 1])
	_part_of(rig, [0, 0]).behaviour = breaker
	var fired := (set[1] as ChBattleContext).tick(TICK, [0.0], PRESS)
	assert_eq(fired, [1], "only the 3 fired")
	assert_eq((set[2][1] as FireDouble).fired, 0, "the broken 1 did not fire")
	assert_near(rig.energy.value, 7.0, 0.0001, "and was not paid for")
	_complete()
