extends ChBehaviour

# The Spinning Blade (C06): a square reach box, def.reach cells out on every side of the part, so it
# hits whatever stands around it - upside down or airborne, with no facing to turn away from.
func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _nearest_enemy_body(ctx, _square_box())
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage)
	return true

func _square_box() -> Rect2:
	var reach: float = part.def.reach
	var at := part.anchor_world()
	return Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
