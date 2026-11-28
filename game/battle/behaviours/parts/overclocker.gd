extends ChBehaviour

# The Overclocker (U53): a press gives the part in front 2 Speedup.
const SPEEDUP := 2

func fire(ctx: ChBattleContext) -> void:
	var front := _front_part(ctx)
	if front != null:
		ctx.give_status(front, ChStatuses.SPEEDUP, SPEEDUP)
