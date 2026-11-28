class_name ChBehaviour extends RefCounted

# The base a part's behaviour script extends (Tasks 12-14 file one per part): `part` plus six
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

# Called by the continuous step once a held part's tick_left reaches 0, after the loop paid that
# frame's energy_per_second * delta. Answers whether the tick landed: true resets the timer to 1 s
# (and, for melee, announces PART_FIRED), false leaves it at 0 so the next frame tries again.
# shortcut: the base is no weapon, so it never lands.
func continuous_tick(ctx: ChBattleContext) -> bool:
	return false


# The melee geometry Tasks 12-14 share: a weapon's reach box and the enemy body its swing hits.
# ChPartDef.reach is the reach in cells, measured from the part's own edge along its facing;
# PixelRigidBody's per-body hit signal only fires on contact begin, so reach is measured geometrically
# instead (the brief's call). These read `part`, the part this behaviour drives, so a weapon measures
# from its own mount.
# The box the swing measures: reach cells out from the part's own edge along facing(), as tall as the
# part. A cell at (x, y) spans x .. x + 1, so the part's edge sits half a cell out from its anchor, and
# the part's own extent is def.size in cells.
func _reach_box() -> Rect2:
	var dir := part.facing()
	var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
	# The part's extent along facing and across it, so a turned or mirrored part keeps one box.
	var along := absf(dir.x) * size.x + absf(dir.y) * size.y
	var across := absf(dir.x) * size.y + absf(dir.y) * size.x
	var half_along := part.def.reach + 0.5 + 0.5 * along
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

# One continuous tick of a melee or beam weapon: the nearest enemy body in the reach box takes
# def.damage through deal_hit, the one damage path. Answers whether there was a body to strike,
# which is what lands the tick and resets the timer.
func _strike(ctx: ChBattleContext) -> bool:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage)
	return true


const LOB_GRAVITY := 60.0  # cells per second squared, the lob's fall

# Fire a bolt from the part's nose along facing() at `speed`, with `gravity` pulling it down, and
# hand the raycast dict to `on_impact`. `angle` turns the line off facing(), which is how the
# Shotgun fans its pellets. The bolt frees itself after ChProjectile.LIFE, so a target that is gone
# just ends the flight.
func _shoot(ctx: ChBattleContext, speed: float, gravity: float, on_impact: Callable,
		angle := 0.0) -> ChProjectile:
	return _launch(ctx, part.facing().rotated(angle), speed, gravity, on_impact)

# The lob: the same bolt, 45° up along facing, under LOB_GRAVITY. Up is the world's up, added to
# facing, so a mirrored part lobbing left still rises rather than falling.
func _lob(ctx: ChBattleContext, speed: float, on_impact: Callable) -> ChProjectile:
	return _launch(ctx, (part.facing() + Vector2.UP).normalized(), speed, LOB_GRAVITY, on_impact)

func _launch(ctx: ChBattleContext, dir: Vector2, speed: float, gravity: float,
		on_impact: Callable) -> ChProjectile:
	var bolt := ChProjectile.new()
	bolt.setup(ctx, part, dir * speed, gravity, on_impact)
	ctx.world.add_child(bolt)
	bolt.global_position = _nose(dir)
	return bolt

# The part's nose: half its extent along `dir`, plus half a cell, from its anchor.
func _nose(dir: Vector2) -> Vector2:
	var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
	var along := absf(dir.x) * size.x + absf(dir.y) * size.y
	return part.anchor_world() + dir * (0.5 * along + 0.5)

# The enemy body a beam reaches: the nearest one in the reach box.
func _beam_target(ctx: ChBattleContext) -> Object:
	return _nearest_enemy_body(ctx, _reach_box())

# The box a beam or a spray writes cells into: the reach box.
func _spray_box(ctx: ChBattleContext) -> Rect2:
	return _reach_box()

# The box a body occupies: def.size cells about its position, the same box as the holder's own
# status_box (ChPartRuntime's), so a weapon's reach and a status sample measure the same footprint.
func _part_box(foe: ChPartRuntime) -> Rect2:
	return foe.status_box()

# The hull's own box, the same reading as ChBattle.hull_box: ChBodyDef.size cells about the chassis.
func _hull_box(chariot: ChChariotRuntime) -> Rect2:
	return ChBattle.hull_box(chariot)

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

# Asked by ChBattleContext.stat to fold a stat: base returns the value unchanged, modifiers may
# raise or lower it. Only behaviours whose own script declares modify_stat are asked.
func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	return value

# Asked by ChBattleContext.give_status to fold a status gain before it lands: base returns the amount
# unchanged, modifiers may raise, lower or refuse it. A result of 0 or less adds nothing. Only
# behaviours whose own script declares modify_gain are asked.
func modify_gain(ctx: ChBattleContext, target: Object, status: StringName, amount: int,
		cause: StringName) -> int:
	return amount

# --- Scopes ---------------------------------------------------------------------------------
# All answer unbroken, non-benched own parts of this behaviour's part, other than `part` itself.

# The own parts within ctx.range_of(part) (or linked to it), in mount order.
func _neighbours(ctx: ChBattleContext, tag: StringName = "") -> Array[ChPartRuntime]:
	var out: Array[ChPartRuntime] = []
	for other in _own_parts(ctx, tag):
		if ctx.near(part, other):
			out.append(other)
	return out

# The nearest neighbour ahead of facing(), or null.
func _front_part(ctx: ChBattleContext, tag: StringName = "") -> ChPartRuntime:
	return _nearest_in_direction(ctx, tag, 1.0)

# The nearest neighbour behind facing(), or null.
func _back_part(ctx: ChBattleContext, tag: StringName = "") -> ChPartRuntime:
	return _nearest_in_direction(ctx, tag, -1.0)

# The parts bolted onto this one, unbroken.
func _mounted() -> Array[ChPartRuntime]:
	var out: Array[ChPartRuntime] = []
	for child in part.children:
		if not child.broken:
			out.append(child)
	return out

# This part's chariot's unbroken, non-benched parts other than part, matching tag if given.
func _own_parts(ctx: ChBattleContext, tag: StringName = "") -> Array[ChPartRuntime]:
	var out: Array[ChPartRuntime] = []
	var side := part.side
	var chariot := ctx.chariots[side] if side >= 0 and side < ctx.chariots.size() else null
	if chariot == null:
		return out
	for other in chariot.parts:
		if other == part or other.broken:
			continue
		if tag != "" and not other.def.tags.has(tag):
			continue
		out.append(other)
	return out

# The enemy chariot's unbroken, non-benched parts matching tag if given.
func _enemy_parts(ctx: ChBattleContext, tag: StringName = "") -> Array[ChPartRuntime]:
	var out: Array[ChPartRuntime] = []
	var side := part.side
	var chariot := ctx.chariots[1 - side] if side >= 0 and side < ctx.chariots.size() else null
	if chariot == null:
		return out
	for other in chariot.parts:
		if other.broken:
			continue
		if tag != "" and not other.def.tags.has(tag):
			continue
		out.append(other)
	return out

# The nearest enemy body in this part's reach box, as its body.
func _hit_enemy_body(ctx: ChBattleContext, damage: int) -> void:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target != null:
		ctx.deal_hit(part, target, damage)

# The base links nothing: a behaviour that links two parts overrides this.
func links(ctx: ChBattleContext, a: Object, b: Object) -> bool:
	return false

# The nearest own part in `direction` (+1 ahead, -1 behind) along facing, or null.
func _nearest_in_direction(ctx: ChBattleContext, tag: StringName = "", direction: float = 1.0) -> ChPartRuntime:
	var best: ChPartRuntime = null
	var best_d := 0.0
	var anchor := part.anchor_world()
	var facing := part.facing()
	for other in _own_parts(ctx, tag):
		var d := (other.anchor_world() - anchor).dot(facing)
		if d * direction > 0 and (best == null or absf(d) < best_d):
			best = other
			best_d = absf(d)
	return best
