extends ChBehaviour

# The Shield Battery (U26): a neighbouring part that gains Block gains 3 more. Its own top-up is
# given with `from = part`, so the Battery answers a neighbour's gain but never its own.
const BLOCK := 3

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.BLOCK or not (event.source is ChPartRuntime):
		return
	var holder: ChPartRuntime = event.source
	if event.data.get("from") == part or not ctx.near(part, holder):
		return
	ctx.give_status(holder, ChStatuses.BLOCK, BLOCK, 1, part)
