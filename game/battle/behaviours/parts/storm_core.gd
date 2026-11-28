extends ChBehaviour

# The Storm Core (R07): the enemy's Shock keeps jumping. The jump budget is a stat, so an enemy
# holder reads 99 hops; the halving in ChBattleContext.give_status is what ends the chain.

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_SHOCK_HOPS or target == null:
		return value
	var side: Variant = target.get("side")
	if side != null and int(side) != part.side:
		return 99.0
	return value
