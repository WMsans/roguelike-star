extends ChBehaviour

# The Permafrost (R05): an enemy part that is Wet keeps its Freeze.
func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.STAT_DECAY_FREEZE and target is ChPartRuntime \
			and target.side != part.side and target.statuses.count(ChStatuses.WET) > 0:
		return 0.0
	return value