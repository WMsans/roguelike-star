extends ChBehaviour

# The Acid Cannon (U20): a straight shot that pays 20 and splashes acid cells over the part hit,
# which the status second turns into Acid.
const SPEED := 200.0  # cells per second along facing()
const CELLS := 8  # acid cells over the part hit

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.spawn(part, &"acid", Vector2(shot.get("position", part.anchor_world())), CELLS)
