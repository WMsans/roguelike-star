extends ChBehaviour

# The Rocket Pod (C01): a straight shot along facing() that pays its damage on the body it meets.
# The numbers live on the def (cost, cooldown, damage); only the flight is the behaviour's.
const SPEED := 160.0  # cells per second along facing()

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	# The raycast dict the projectile hands back: "collider" answers the body the segment met, and
	# is null for terrain, which a rocket does not pay for.
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
