extends ChBehaviour

# The Eternal Flame (R02): an enemy part with Oil keeps its Flame.
func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.STAT_DECAY_FLAME and target is ChPartRuntime \
			and target.side != part.side and target.statuses.count(ChStatuses.OIL) > 0:
		return 0.0
	return value
