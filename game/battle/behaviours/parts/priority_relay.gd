extends ChBehaviour

# The Priority Relay (U60): its neighbours are paid first in a volley, ahead of the dearest-first
# order. The volley reads the priority as a stat, so this only raises it for the parts in range.
const PRIORITY := 1.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_VOLLEY_PRIORITY or not (target is ChPartRuntime):
		return value
	return PRIORITY if ctx.near(part, target) else value
