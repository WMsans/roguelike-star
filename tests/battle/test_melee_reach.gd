extends ChTest

# Task 4: melee reach is proven by contact. Every attacker/defender pair of the three catalog bodies
# (nine pairs) drives the real arena toward each other through ChBattle; the attacker holds the
# button from the start, and the pair passes when the melee part on its front slot lands one tick
# within 10 s. The part is the Task 2 fixture at MELEE_REACH cells, plus every catalog def whose mode
# is melee (none on disk today, so that loop is the fixture alone until Stage 4 lands them).
#
# Harness: ChBattle over the real arena, the way test_bodies.gd drives two chariots, not
# ChTest.make_world with flat rock ground. A drive moves a wheel only on the world's own physics
# frame, and ChBattle awaits one process_frame per tick, so its ticks are the frames the sim steps on;
# a test's own ctx.tick loop (test_continuous.gd) never awaits one, so the same rigs never move.
# shortcut: the fight is a real arena, so its sand and bumps are part of the proof; a body that tips
# on them is reported rather than fixed by the harness.

const BODY_IDS: Array[StringName] = [&"cutter", &"dozer", &"corsair"]
const MELEE_REACH := 24.0  # cells from the part's edge; the sweep settles this number
const MELEE_FIXTURE := "res://tests/battle/fixtures/ch_fixture_melee.gd"
const MELEE_ID := &"test_melee_reach"
const MELEE_DAMAGE := 10
const MELEE_PER_SECOND := 2.0
const FIGHT_TICKS := 600  # 10 s at 60 fps: the reach the brief gives a pair to land a tick
const TALL_HP := 100000  # neither hull can die, so only this test's own end stops the fight
const SEED := 12345


func _melee_def(reach: float) -> ChPartDef:
	# The Task 2 fixture with this test's reach: the def the sweep's number lives on.
	var def := ChPartDef.new()
	def.id = MELEE_ID
	def.mode = ChPartDef.MODE_MELEE
	def.energy_per_second = MELEE_PER_SECOND
	def.damage = MELEE_DAMAGE
	def.reach = reach
	def.integrity = 100
	def.size = Vector2i(2, 2)
	def.charges = -1
	# Loaded rather than preloaded: a broken fixture fails this test by name, not the whole file.
	def.behaviour = load(MELEE_FIXTURE)
	return def


func _catalog(reach: float) -> ChCatalog:
	# The slice's defs plus the fixture, with every body at TALL_HP so a fight the test has not ended
	# never ends itself. A fresh catalog per run keeps a def on disk untouched.
	var loaded := ChCatalog.load_default()
	var parts: Array[ChPartDef] = [_melee_def(reach)]
	for def in loaded.parts.values():
		parts.append(def)
	var bodies: Array[ChBodyDef] = []
	for def in loaded.bodies.values():
		bodies.append(_body_with_hp(def, TALL_HP))
	return ChCatalog.from_defs(parts, bodies)


func _weapon_ids(catalog: ChCatalog) -> Array[StringName]:
	# Every melee def the catalog holds: the fixture plus whatever part data says melee. Today that
	# is the fixture alone (Stage 4 lands the real melee weapons, and this loop then covers them).
	var ids: Array[StringName] = []
	for def in catalog.parts.values():
		if def.mode == ChPartDef.MODE_MELEE:
			ids.append(def.id)
	return ids


func _wheel_slots(body: ChBodyDef) -> Array[int]:
	# The two lowest slots: the deepest y wins, which is where a body's wheels sit on every catalog
	# hull (a barge's 5, a wedge's 4.5, a tower's 15).
	var order: Array[int] = []
	for index in body.slots.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return body.slots[a].y > body.slots[b].y)
	return [order[0], order[1]]


func _front_slot(body: ChBodyDef, wheels: Array[int]) -> int:
	# The part that leads the hull: the non-wheel slot with the largest x. That is the edge a melee
	# weapon has to reach the enemy from, so it is where the fixture mounts.
	var best := -1
	for index in body.slots.size():
		if index in wheels:
			continue
		if best < 0 or body.slots[index].x > body.slots[best].x:
			best = index
	return best


func _layout(body_id: StringName, catalog: ChCatalog, weapon: StringName) -> ChChariotLayout:
	var body: ChBodyDef = catalog.body(body_id)
	assert_true(body != null, "%s has a body def" % body_id)
	var wheels: Array[int] = _wheel_slots(body)
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	for index in wheels:
		assert_true(layout.place(_typed_path([index]), &"roller"), "%s wheel at slot %d" % [body_id, index])
	if weapon != &"":
		var front := _front_slot(body, wheels)
		assert_true(layout.place(_typed_path([front]), weapon), "%s mounts %s at its front slot %d" % [body_id, weapon, front])
	return layout


func _part_at(chariot: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in chariot.parts:
		if part.path == steps:
			return part
	return null


func _fight(attacker: StringName, defender: StringName, weapon: StringName,
		catalog: ChCatalog) -> Dictionary:
	# One pair: side 0 on the left holds the button and drives right, side 1 on the right is mirrored
	# as ChBattle builds enemies (so its parts face left) and drives left, so they close on each other.
	# The fight is ended on the first HIT from the front part, or at FIGHT_TICKS, by zeroing the
	# defender's HP: a battle may only be freed after `finished` (ChBattle.start's contract).
	var attacker_layout := _layout(attacker, catalog, weapon)
	var defender_layout := _layout(defender, catalog, &"")
	var front := _front_slot(catalog.body(attacker), _wheel_slots(catalog.body(attacker)))
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	battle.pressers = [func(_b, _s): return false, func(_b, _s): return false]
	battle.holders = [func(_b, _s): return true, func(_b, _s): return false]
	battle.drivers = [func(_b, _s): return 1.0, func(_b, _s): return -1.0]
	Engine.get_main_loop().get_root().add_child(battle)
	# "short" is the least gap seen between the reach box's leading edge and the defender's hull, in
	# cells: a positive answer is how far the front part stayed out of reach, which is the sweep's
	# measurement. "ran" and "rot" separate a reach miss from a part that never ran or a body that fell
	# over. A Dictionary is a reference, so the lambdas below write through it.
	var seen := {"hit": false, "first": 0, "ticks": 0, "ran": false, "short": INF, "rot": 0.0,
		"target": "none"}
	var sink := seen
	var subscribed := [false]
	battle.stepped.connect(func(ctx: ChBattleContext):
		sink["ticks"] += 1
		# No status seconds: this proves reach, and the terrain's statuses are not part of it.
		ctx.status_clock = 0.0
		var melee := _part_at(ctx.chariots[0], [front])
		var hull: ChChariotRuntime = ctx.chariots[1]
		sink["rot"] = maxf(sink["rot"], absf(wrapf(ctx.chariots[0].chassis.global_rotation, -PI, PI)))
		if melee != null and melee.can_run():
			sink["ran"] = true
		if melee != null and melee.behaviour != null:
			# The reach box is the production geometry the swing measures, read straight off the part.
			var box: Rect2 = melee.behaviour._reach_box()
			var hull_size := Vector2(hull.body_def.size)
			var hull_left: float = hull.chassis.global_position.x - hull_size.x * 0.5
			sink["short"] = minf(sink["short"], hull_left - box.end.x)
		if not subscribed[0]:
			# The first HIT with the front part as its source lands the tick. Subscribed on the first
			# tick, when the context the fight built is in hand.
			subscribed[0] = true
			ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent):
				if event.source != melee:
					return
				if not sink["hit"]:
					sink["hit"] = true
					sink["first"] = sink["ticks"]
					# What the swing found: the hull, or a part of the defender's that leads it.
					var struck = event.data.get("target_part")
					sink["target"] = struck.def.id if struck != null else "hull"
				ctx.chariots[1].hp = 0)
		if sink["ticks"] >= FIGHT_TICKS:
			hull.hp = 0)
	await battle.start(attacker_layout, defender_layout, catalog, SEED)
	battle.free()
	return seen


func test_melee_reach_lands_for_every_body_pair() -> void:
	var catalog := _catalog(MELEE_REACH)
	for weapon in _weapon_ids(catalog):
		for attacker in BODY_IDS:
			for defender in BODY_IDS:
				var seen := await _fight(attacker, defender, weapon, catalog)
				var short: float = seen["short"]
				print("melee_reach %.1f: %s holds %s at %s -> %s on %s (ran=%s, ticks=%d, closest hull shortfall %.1f cells, tip %.2f)" % [
					MELEE_REACH, attacker, weapon, defender,
					"HIT on tick %d" % seen["first"] if seen["hit"] else "no HIT", seen["target"],
					seen["ran"], seen["ticks"], short, seen["rot"]])
				assert_true(seen["hit"],
					"%s lands %s on %s within %d ticks (ran=%s, closest shortfall %.1f cells, tip %.2f)"
					% [attacker, weapon, defender, FIGHT_TICKS, seen["ran"], short, seen["rot"]])
	_complete()
