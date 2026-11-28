extends ChBehaviour

# The Incinerator (U04): a straight shot that pays 5 for every Flame on the part it hits.
const SPEED := 400.0  # cells per second along facing()

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met == null or not is_instance_valid(met):
		return
	ctx.deal_hit(part, met, part.def.damage * _flame(ctx, met))

func _flame(ctx: ChBattleContext, body: Object) -> int:
	# The holder is the part hit, or the chariot body for a hull hit: deal_hit resolves the same split.
	var holder: Object = ctx.part_of_body(body)
	if holder == null:
		holder = ctx.chariot_of_body(body)
	return holder.statuses.count(ChStatuses.FLAME) if holder != null else 0
