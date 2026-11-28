extends ChBehaviour

# The Chain Lightning (U15): a straight shot that pays 30 and throws sparks at the part it meets.
# The Shock those sparks carry is the one that jumps an extra hop: the hops travel with this
# discharge only.
const SPEED := 200.0  # cells per second along facing()
const HOPS := 2  # jumps the sparks' Shock makes

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.throw_sparks(part, Vector2(shot.get("position", part.anchor_world())), HOPS)
