extends ChBehaviour

# The Cutter Chainsaw (spec §5.4): it cuts whatever stands inside the def's reach (14 cells), and
# every cut throws fire sparks that can light flammable ground. A cut through a part is a hit, so it
# goes through deal_hit like every other weapon; a cut with nothing in reach bites the ground at the
# tip. Reach numbers live here, not on ChPartDef: proximity_range is the reach in cells. The box it
# measures and the body it hits are ChBehaviour's, shared with every melee part.
const SPARK_COUNT := 4
const SPARK_SPEED := 40.0  # cells per second the sparks fly
const SPARK_SPREAD := 0.6  # radians, the full cone
const CUT_RADIUS := 2
const CUT_POWER := 50.0
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

func fire(ctx: ChBattleContext) -> void:
	var box := _reach_box()
	var target := _nearest_enemy_body(ctx, box)
	var dir := part.facing()
	# The tip is the far edge of the reach box along facing(), the point the cut reaches: the box starts
	# at the part's edge and already carries the part's own extent, so the tip is not anchor + reach.
	var tip: Vector2 = box.get_center() + box.size * 0.5 * dir
	# shortcut: get_material_at answers &"" for air, so any material counts as cuttable ground here;
	# a saw that should not dig water wants a solid-material check.
	var ground := ctx.world != null and ctx.world.get_material_at(Vector2i(tip)) != &""
	if target == null and not ground:
		# The swing met neither a body nor the ground, so it cut nothing: the sparks belong to a cut, so an
		# empty swing throws no fire that could light flammables for free and announces no CELLS_CUT.
		return
	var sparks := 0
	if ctx.world != null:
		# The brief's spark shot: 4 fire particles out along facing() at 40 cells/s over a 0.6 rad cone.
		sparks = ctx.world.spawn_particles(&"fire", tip, dir * SPARK_SPEED, SPARK_COUNT, SPARK_SPREAD)
	ChFx.spawn(ctx.world, &"spark_hit", tip, dir)
	if target != null:
		# A cut through a part is a hit, so it pays through the fight's one damage entry point.
		ctx.deal_hit(part, target, part.def.damage)
		_announce_cut(ctx, sparks)
	elif ground:
		# The tip stands in ground and nothing of the enemy reached the box, so the saw cuts the ground.
		ctx.world.explode(Vector2i(tip), CUT_RADIUS, CUT_POWER)
		_announce_cut(ctx, sparks)
