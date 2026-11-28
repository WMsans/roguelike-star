extends ChBehaviour

# The Rampart (U27): 15 Block on itself and on every neighbour when it fires.
const BLOCK := 15

func fire(ctx: ChBattleContext) -> void:
	ctx.give_status(part, ChStatuses.BLOCK, BLOCK)
	for other in _neighbours(ctx):
		ctx.give_status(other, ChStatuses.BLOCK, BLOCK)
