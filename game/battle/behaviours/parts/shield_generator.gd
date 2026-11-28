extends ChBehaviour

# The Shield Generator (C12): 30 Block on the chariot body, not on itself.
const BLOCK := 30

func fire(ctx: ChBattleContext) -> void:
	ctx.give_status(ctx.own(part), ChStatuses.BLOCK, BLOCK)
