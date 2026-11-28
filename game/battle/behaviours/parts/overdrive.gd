extends ChBehaviour

# The Overdrive (R26): Speedup on your parts runs cooldowns at triple speed instead of double.
const SPEEDUP_RATE := 3.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.STAT_TICK_RATE and target is ChPartRuntime \
			and target.side == part.side and is_equal_approx(value, 2.0):
		return SPEEDUP_RATE
	return value
