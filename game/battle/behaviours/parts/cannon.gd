extends ChBehaviour

# The Cannon (C02): a heavy shell that falls as it flies, so it drops onto the hull it is aimed at.
const SPEED := 120.0  # cells per second along facing()
const GRAVITY := 20.0  # cells per second squared, the shell's fall

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, GRAVITY, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
