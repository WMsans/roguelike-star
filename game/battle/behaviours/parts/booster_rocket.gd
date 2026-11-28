extends ChBehaviour

# The Booster Rocket (U74): the press launches its own chariot along the chassis' facing. The chassis
# is the body that carries the build, so its rotation is what "forward" means.

const LAUNCH := 900.0  # impulse along the chassis facing


func fire(ctx: ChBattleContext) -> void:
	var own := ctx.own(part)
	if own == null or own.chassis == null or not is_instance_valid(own.chassis):
		return
	ctx.push(own, Vector2.RIGHT.rotated(own.chassis.global_rotation) * LAUNCH)
