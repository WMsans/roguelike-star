extends ChBehaviour

# The Bumper (C13): 5 Block on itself every time a hit lands on it.
const BLOCK := 5

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent):
		if event.data.get("target_part") == part:
			ctx.give_status(part, ChStatuses.BLOCK, BLOCK))
