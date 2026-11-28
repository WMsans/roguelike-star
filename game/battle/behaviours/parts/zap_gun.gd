extends ChBehaviour

# The Zap Gun (C22): a straight shot that pays 15 and throws sparks at the body it meets, which shock
# the holder through ChSparks' discharge.
const SPEED := 200.0  # cells per second along facing()

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.throw_sparks(part, Vector2(shot.get("position", part.anchor_world())))
