extends ChBehaviour

# The Turbo Booster (C32): every neighbour gains 1 Speedup.
const SPEEDUP := 1

func fire(ctx: ChBattleContext) -> void:
	for other in _neighbours(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
