extends ChBehaviour

# The Lightning Bolt (R08): a straight shot that pays 150. Where it lands the 150 has already been
# dealt as the hit, so the large blast that follows carries no damage of its own.
const SPEED := 200.0  # cells per second along facing()
const BLAST_SIZE := &"large"
const BLAST_DIG := 6  # a large blast digs hardness 6

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var at := Vector2(shot.get("position", part.anchor_world()))
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.explode(part, Vector2i(roundi(at.x), roundi(at.y)), BLAST_SIZE, 0, BLAST_DIG)
	ctx.throw_sparks(part, at)
