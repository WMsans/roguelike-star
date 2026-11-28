extends ChBehaviour

# The Shotgun (C08): seven pellets spread over ±SPREAD, and the kick that shoves both chariots -
# the shooter back along its own facing and the target away along it.
const PELLETS := 7
const SPREAD := 0.2  # radians either side of facing()
const SPEED := 200.0  # cells per second along the pellet's own line
const KNOCKBACK := 300.0  # the impulse each chariot takes

func fire(ctx: ChBattleContext) -> void:
	for i in PELLETS:
		# Pellets fan evenly from -SPREAD to +SPREAD, so the first and last sit on the edges.
		var angle := (float(i) / float(PELLETS - 1) * 2.0 - 1.0) * SPREAD
		_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot), angle)
	ctx.push(ctx.own(part), -part.facing() * KNOCKBACK)
	ctx.push(ctx.enemy_of(part), part.facing() * KNOCKBACK)

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
