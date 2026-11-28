extends ChBehaviour

# The Ball Lightning (U16): three slow orbs, each 10, each bursting into sparks where it lands.
const SPEED := 50.0  # cells per second along facing(), slow orbs
const SPREAD := 0.15  # radians each side of facing()
const ORBS := 3

func fire(ctx: ChBattleContext) -> void:
	for i in range(ORBS):
		_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot),
			(float(i) - 1.0) * SPREAD)

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.throw_sparks(part, Vector2(shot.get("position", part.anchor_world())))
