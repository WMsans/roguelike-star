extends ChBehaviour

# The Gear Linkage (U54): the part behind this gaining Speedup gives the part in front 1.
const SPEEDUP := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SPEEDUP or event.side != part.side:
		return
	if not (event.source is ChPartRuntime) or event.source != _back_part(ctx):
		return
	var front := _front_part(ctx)
	if front != null:
		ctx.give_status(front, ChStatuses.SPEEDUP, SPEEDUP)
