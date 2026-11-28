extends ChBehaviour

# The Juggernaut (R32): while its chariot drives, its own parts other than wheels cost no energy —
# neither the press's energy_cost nor a running part's energy_per_second. A wheel keeps paying, which
# is the driving cost itself.


func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_ENERGY_COST and stat != ChBattleContext.STAT_ENERGY_PER_SECOND:
		return value
	if not target is ChPartRuntime:
		return value
	var other: ChPartRuntime = target
	if other.side != part.side or other.def == null or other.def.is_wheel():
		return value
	var own := ctx.own(part)
	if own == null or not own.driving:
		return value
	return 0.0
