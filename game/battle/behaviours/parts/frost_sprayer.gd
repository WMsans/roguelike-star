extends ChBehaviour

# The Frost Sprayer (C19): a straight shot that pays 15 on the body it meets and leaves frost cells
# over the part hit, which the status second turns into Freeze.
const SPEED := 200.0  # cells per second along facing()
const CELLS := 6  # frost cells over the part hit

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.spawn(part, &"frost", Vector2(shot.get("position", part.anchor_world())), CELLS)
