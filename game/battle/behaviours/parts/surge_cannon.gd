extends ChBehaviour

# The Surge Cannon (U63): spends the whole pool and deals 15 damage an energy spent. The volley has
# already paid the def's 1 energy, so that point counts as spent too; a forced fire paid nothing, so
# only the pool counts.
const SPEED := 200.0  # cells per second along facing()

func fire(ctx: ChBattleContext) -> void:
	var spent := 0.0
	var own := ctx.own(part)
	if own != null and own.energy != null:
		spent += own.energy.value
		own.energy.spent += own.energy.value
		own.energy.value = 0.0
	if part.paid:
		spent += 1.0
	var damage := roundi(part.def.damage * spent)
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot, damage))

func _impact(ctx: ChBattleContext, shot: Dictionary, damage: int) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, damage)
