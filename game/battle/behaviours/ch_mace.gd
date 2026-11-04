extends ChBehaviour

# The Ice Cream Mace (spec §5.4): a melee swing out to the def's reach and the Shatter, which pays
# ChDamage's x3 to a frozen target and ends that freeze. The weapon's numbers live here: ChPartDef
# has no reach field, so proximity_range (6 cells for a mace) is its reach, because the engine's
# per-body hit signal only fires on contact begin and cannot give a reach.
# The box the swing measures: reach cells out from the part's own edge along facing(), as tall as
# the part. A cell at (x, y) spans x .. x + 1, so the part's edge sits half a cell out from its
# anchor, and the part's own extent is def.size in cells.
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

# The nearest enemy body whose box overlaps the reach box, as its body rather than a part: deal_hit
# resolves a body to a part hit or a chassis hit, which is ChDamage's own split. A broken part's body
# lies on the ground and belongs to no chariot, so deal_hit drops a hit on it; skipping it here keeps
# the swing from aiming at a wreck in the first place.
func _nearest_enemy_body(ctx: ChBattleContext, box: Rect2) -> Object:
	var at := part.anchor_world()
	var best: Object = null
	var best_at := INF
	for chariot in ctx.chariots:
		if chariot == null or chariot.side == part.side:
			continue
		var hulls: Array = []
		if chariot.chassis != null:
			hulls.append([chariot.chassis, _hull_box(chariot)])
		for foe in chariot.parts:
			if not foe.broken and foe.def != null:
				hulls.append([foe.body, _part_box(foe)])
		for entry in hulls:
			if entry[0] == null or not is_instance_valid(entry[0]):
				continue
			var aabb: Rect2 = entry[1]
			if not aabb.intersects(box):
				continue
			var near := aabb.get_center().distance_to(at)
			if near < best_at:
				best_at = near
				best = entry[0]
	return best

# The box a body occupies: def.size cells about its position. PixelRigidBody binds no bounds
# getter, so this is the footprint ChPartRuntime.sample_rect takes for a body, without that method's
# sample margin, which belongs to status sampling rather than to a weapon's reach.
func _part_box(foe: ChPartRuntime) -> Rect2:
	var size := Vector2(maxi(1, foe.def.size.x), maxi(1, foe.def.size.y))
	return Rect2(foe.anchor_world() - size * 0.5, size)

# The hull's own box, the same reading as _part_box: ChBodyDef.size cells about the chassis.
func _hull_box(chariot: ChChariotRuntime) -> Rect2:
	var size := Vector2(maxi(1, chariot.body_def.size.x), maxi(1, chariot.body_def.size.y))
	return Rect2(chariot.chassis.global_position - size * 0.5, size)

func fire(ctx: ChBattleContext) -> void:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target != null:
		# deal_hit is the fight's one damage entry point: it asks the passives near the source, then this
		# behaviour's modify_hit, then applies ChDamage.
		ctx.deal_hit(part, target, part.def.damage)

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	# deal_hit asks the source's own behaviour last, so the target is read off the hit rather than
	# measured again: this is the swing fire just made.
	var target: ChPartRuntime = hit["target_part"]
	if target == null or not target.is_frozen():
		return
	hit["multiplier"] = hit["multiplier"] * ChDamage.shatter_multiplier(true)
	target.freeze = 0.0
	# The Shatter ends the freeze it read, so THAWED names the target as its source, as ChPartRuntime's
	# own THAWED emission has it. ChBattleContext adds a pass's freeze after the modifiers, so a Freeze
	# Charge landing on the same hit leaves 0.5 rather than a re-frozen part.
	var event := ChEvent.new()
	event.type = ChEvent.THAWED
	event.side = target.side
	event.source = target
	event.position = target.anchor_world()
	ctx.bus.emit(event)
