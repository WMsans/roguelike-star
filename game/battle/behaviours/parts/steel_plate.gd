extends ChBehaviour

# The Steel Plate (C11): 40 Block on itself as the battle opens, and one extension slot under it.
const BLOCK := 40

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent):
		ctx.give_status(part, ChStatuses.BLOCK, BLOCK))
