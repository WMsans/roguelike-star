extends ChBehaviour

# The Grinding Engine (R17): a neighbouring melee weapon pays no energy a second.
func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_ENERGY_PER_SECOND or not (target is ChPartRuntime):
		return value
	var weapon: ChPartRuntime = target
	if weapon == part or weapon.def == null or not weapon.def.tags.has("melee"):
		return value
	return 0.0 if ctx.near(part, weapon) else value
