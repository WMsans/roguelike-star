extends ChBehaviour

# The Cutter Chainsaw (spec §5.4): it cuts whatever stands inside the def's reach (14 cells), and
# every cut throws fire sparks that can light flammable ground. A cut through a part is a hit, so it
# goes through deal_hit like every other weapon; a cut with nothing in reach bites the ground at the
# tip. Reach numbers live here, not on ChPartDef: proximity_range is the reach in cells.
const SPARK_COUNT := 4
const SPARK_SPEED := 40.0  # cells per second the sparks fly
const SPARK_SPREAD := 0.6  # radians, the full cone
const CUT_RADIUS := 2
const CUT_POWER := 50.0

# The box the cut measures: reach cells out from the part's own edge along facing(), as tall as the
# part. A cell at (x, y) spans x .. x + 1, so the part's edge sits half a cell out from its anchor.
func _reach_box() -> Rect2:
	var dir := part.facing()
	var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
	var along := absf(dir.x) * size.x + absf(dir.y) * size.y
	var across := absf(dir.x) * size.y + absf(dir.y) * size.x
	var half_along := part.def.proximity_range + 0.5 + 0.5 * along
	var half_across := 0.5 * across
	var span := Vector2(absf(dir.x) * half_along + absf(dir.y) * half_across,
		absf(dir.y) * half_along + absf(dir.x) * half_across)
	return Rect2(part.anchor_world() - span, span * 2)

# The nearest enemy body whose box overlaps the reach box, as its body rather than a part: deal_hit
# resolves a body to a part hit or a chassis hit, which is ChDamage's own split.
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
# CELLS_CUT announces the cut the saw just made, with the sparks it threw: the pool has no count
# getter of its own, so the number spawn_particles returned is the only readback of the spark shot.
func _announce_cut(ctx: ChBattleContext, sparks: int) -> void:
	var event := ChEvent.new()
	event.type = ChEvent.CELLS_CUT
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	event.data = {"sparks": sparks}
	ctx.bus.emit(event)

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
	var box := _reach_box()
	var target := _nearest_enemy_body(ctx, box)
	var tip := part.anchor_world() + part.facing() * part.def.proximity_range
	var sparks := 0
	if ctx.world != null:
		# The brief's spark shot: 4 fire particles out along facing() at 40 cells/s over 0.6 rad.
		sparks = ctx.world.spawn_particles(&"fire", tip, part.facing() * SPARK_SPEED, SPARK_COUNT,
			SPARK_SPREAD)
	if target != null:
		# A cut through a part is a hit, so it pays through the fight's one damage entry point.
		ctx.deal_hit(part, target, part.def.damage)
		_announce_cut(ctx, sparks)
	elif ctx.world != null and ctx.world.get_material_at(Vector2i(tip)) != &"":
	# The tip stands in ground and nothing of the enemy reached the box, so the saw cuts the ground.
	# shortcut: any material counts as ground here; a saw that should not dig water wants a solid check.
		ctx.world.explode(Vector2i(tip), CUT_RADIUS, CUT_POWER)
		_announce_cut(ctx, sparks)
