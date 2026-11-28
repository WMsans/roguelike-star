extends ChBehaviour

# The Pulse Gun (U57): a straight shot that pays 20, and every neighbour gains 1 Speedup.
const SPEED := 200.0  # cells per second along facing()
const SPEEDUP := 1

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))
	for other in _neighbours(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
