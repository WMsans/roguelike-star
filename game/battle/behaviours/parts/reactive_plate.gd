extends ChBehaviour

# The Reactive Plate (U83): Block on this part absorbing a hit gives every neighbouring weapon
# 1 Speedup.
const SPEEDUP := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BLOCK_ABSORBED, func(event: ChEvent): _absorbed(ctx, event))

func _absorbed(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.source != part:
		return
	for other in _neighbours(ctx, "weapon"):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
