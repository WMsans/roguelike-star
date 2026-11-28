extends ChBehaviour

# The Coolant Pump (U56): neighbours lose Slow twice as fast.
const FASTER := 2.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.decay_stat(ChStatuses.SLOW) and target is ChPartRuntime \
			and target.side == part.side and ctx.near(part, target):
		return value * FASTER
	return value
