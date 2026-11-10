class_name ChBehaviour extends RefCounted

# The base a part's behaviour script extends (Tasks 12-14 file one per part): `part` plus five
# hooks, all no-ops here, so a behaviour overrides only the ones it needs. A part with no behaviour
# (ChPartDef.behaviour left null until Tasks 12-14 set it) is never asked any of them.
# A behaviour is also the listener its subscriptions are keyed on: ChBattleContext calls setup so
# the behaviour subscribes itself, and ChChariotRuntime.break_part unsubscribes that same listener
# when the part it drives breaks.

var part: ChPartRuntime = null  # the part this behaviour drives

# Subscribe to ctx.bus here, with self as the listener. Tasks 12-14 do the subscribing: a passive
# that listens for a nearby event, a weapon that listens for a status, both go through here.
# shortcut: the base subscribes nothing, so a behaviour that needs no listener stays a no-op.
func setup(ctx: ChBattleContext) -> void:
	pass

# Called once when the part breaks, after break_part has taken this behaviour off the bus and
# before the part's PART_BROKEN goes out: whatever the behaviour holds that outlives process - a
# looping fx riding the world - is stopped here, since the tick no longer calls process.
# shortcut: the base holds nothing, so it does nothing; a behaviour that owns a node overrides it.
func teardown() -> void:
	pass

# Called once ChBattleContext.tick has paid this part's energy cost. The loop resets the cooldown
# and spends a charge right after this, so a behaviour cannot skip either.
# shortcut: the base does nothing, and a part with no behaviour is never asked in the first place.
func fire(ctx: ChBattleContext) -> void:
	pass


# The melee geometry Tasks 12-14 share: a weapon's reach box and the enemy body its swing hits. ChPartDef
# has no reach field, so def.proximity_range doubles as the reach in cells - PixelRigidBody's per-body
# hit signal only fires on contact begin, so reach is measured geometrically instead (the brief's call).
# These read `part`, the part this behaviour drives, so a weapon measures from its own mount.
# The box the swing measures: reach cells out from the part's own edge along facing(), as tall as the
# part. A cell at (x, y) spans x .. x + 1, so the part's edge sits half a cell out from its anchor, and
# the part's own extent is def.size in cells.
func _reach_box() -> Rect2:
	var dir := part.facing()
	var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
	# The part's extent along facing and across it, so a turned or mirrored part keeps one box.
	var along := absf(dir.x) * size.x + absf(dir.y) * size.y
	var across := absf(dir.x) * size.y + absf(dir.y) * size.x
	var half_along := part.def.proximity_range + 0.5 + 0.5 * along
	var half_across := 0.5 * across
	var span := Vector2(absf(dir.x) * half_along + absf(dir.y) * half_across,
		absf(dir.y) * half_along + absf(dir.x) * half_across)
	var at := part.anchor_world()
	return Rect2(at - span, span * 2)

# The live bodies in the fight, as [chariot, body, box] entries: each chariot's chassis plus its
# unbroken parts, measured with ChBehaviour's own footprints. The emitters (Tasks 12-14) and the
# melee scan below all want this same walk, so it exists once here and the side filter stays with
# the caller that has one.
# A broken part is out of the walk for the same reason ChBattleContext.part_of_body and chariot_of_body
# skip it: its body lies on the ground and belongs to no chariot, so deal_hit drops a hit on it rather
# than paying bare HP. A step takes this walk before it writes any cell, so what a step fills cannot
# decide which bodies that step pays; a part broken by an earlier step stops paying for the rest of the
# window, which is why a pinned window total holds while the target cannot break inside that window.
func _bodies(ctx: ChBattleContext) -> Array:
	var bodies: Array = []
	for chariot in ctx.chariots:
		if chariot == null:
			continue
		if chariot.chassis != null and is_instance_valid(chariot.chassis):
			bodies.append([chariot, chariot.chassis, _hull_box(chariot)])
		for foe in chariot.parts:
			if foe.broken or foe.def == null:
				continue
			# A part the builder never joined has no body to pay, so it never joins the walk.
			# shortcut: is_instance_valid is the engine's own liveness check; a body freed later
			# reads here once more per step rather than per caller.
			if foe.body == null or not is_instance_valid(foe.body):
				continue
			bodies.append([chariot, foe.body, _part_box(foe)])
	return bodies

# The nearest enemy body whose box overlaps the reach box, as its body rather than a part: deal_hit
# resolves a body to a part hit or a chassis hit, which is ChDamage's own split. A broken part's body
# lies on the ground and belongs to no chariot, so deal_hit drops a hit on it; skipping it here keeps
# the swing from aiming at a wreck in the first place.
func _nearest_enemy_body(ctx: ChBattleContext, box: Rect2) -> Object:
	var at := part.anchor_world()
	var best: Object = null
	var best_at := INF
	for entry in _bodies(ctx):
		# The walk carries the chariot so the side filter stays here: a weapon hits the other sides.
		if entry[0].side == part.side:
			continue
		var aabb: Rect2 = entry[2]
		if not aabb.intersects(box):
			continue
		var near := aabb.get_center().distance_to(at)
		if near < best_at:
			best_at = near
			best = entry[1]
	return best

# The box a body occupies: def.size cells about its position. PixelRigidBody binds no bounds getter,
# so this is the footprint ChPartRuntime.sample_rect takes for a body, without that method's sample
# margin, which belongs to status sampling rather than to a weapon's reach.
func _part_box(foe: ChPartRuntime) -> Rect2:
	var size := Vector2(maxi(1, foe.def.size.x), maxi(1, foe.def.size.y))
	return Rect2(foe.anchor_world() - size * 0.5, size)

# The hull's own box, the same reading as _part_box: ChBodyDef.size cells about the chassis.
func _hull_box(chariot: ChChariotRuntime) -> Rect2:
	var size := Vector2(maxi(1, chariot.body_def.size.x), maxi(1, chariot.body_def.size.y))
	return Rect2(chariot.chassis.global_position - size * 0.5, size)

# Called every tick, fired or not: a timed behaviour counts its own seconds against ctx.time or the
# delta, which is the same delta every part, cooldown and energy pool in the fight gets.
func process(ctx: ChBattleContext, delta: float) -> void:
	pass


# Passives alter an outgoing hit here, before ChBattleContext applies any of it: the hit is the
# same Dictionary the entry point built, so a mutation travels (a Freeze Charge adds hit["freeze"],
# a Mace doubles hit["multiplier"]). The keys are source, target_part, target_chariot, damage,
# multiplier, freeze and thaw.
func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	# shortcut: no key is required, and a behaviour that changes nothing answers by doing nothing.
	pass
