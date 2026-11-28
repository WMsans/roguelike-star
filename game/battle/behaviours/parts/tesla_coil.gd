extends ChBehaviour

# The Tesla Coil (U14): a straight shot that pays 40 and throws sparks at the part it meets, and 1
# Speedup whenever a neighbour fires.
const SPEED := 200.0  # cells per second along facing()

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.throw_sparks(part, Vector2(shot.get("position", part.anchor_world())))

func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	# A neighbour is an own part within range, so the coil's own PART_FIRED never counts.
	if event.side != part.side:
		return
	var source: Object = event.source
	if source is ChPartRuntime and _neighbours(ctx).has(source):
		ctx.give_status(part, ChStatuses.SPEEDUP, 1)
