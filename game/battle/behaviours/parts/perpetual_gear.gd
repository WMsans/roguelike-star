extends ChBehaviour

# The Perpetual Gear (R25): its own Speedup gain (n) gives the part in front 2n.
const FACTOR := 2

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SPEEDUP or event.source != part:
		return
	var front := _front_part(ctx)
	if front != null:
		ctx.give_status(front, ChStatuses.SPEEDUP, int(event.data.get("amount", 0)) * FACTOR)
