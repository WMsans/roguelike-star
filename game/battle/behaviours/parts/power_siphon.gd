extends ChBehaviour

# The Power Siphon (U62): a straight shot that pays 20, and 3 energy when the part it hits holds Shock.
const SPEED := 200.0  # cells per second along facing()
const ENERGY := 3

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met == null or not is_instance_valid(met):
		return
	# The holder is read before the hit lands, so a part the shot breaks still answers with its Shock.
	var struck := ctx.part_of_body(met)
	ctx.deal_hit(part, met, part.def.damage)
	if struck != null and struck.statuses.count(ChStatuses.SHOCK) > 0:
		ctx.gain_energy(ctx.own(part), ENERGY)
