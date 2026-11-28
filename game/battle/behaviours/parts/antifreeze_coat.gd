extends ChBehaviour

# The Antifreeze Coat (U10): own parts within range lose Freeze twice as fast.
const FASTER := 2.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.STAT_DECAY_FREEZE and target is ChPartRuntime \
			and target.side == part.side and ctx.near(part, target):
		return value * FASTER
	return value