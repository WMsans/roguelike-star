extends ChBehaviour

# The Blood Cell (R28): a part the volley cannot afford may pay anyway, and the shortfall costs HP.
# The volley reads the pay as a stat, so this only turns it on for its own side's parts.
const BLOOD_PAY := 1.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_BLOOD_PAY or not (target is ChPartRuntime):
		return value
	return BLOOD_PAY if target.side == part.side else value
