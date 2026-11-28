extends ChBehaviour

# The Shield Battery (U26): a neighbouring part that gains Block gains 3 more. Its own top-up carries
# the `battery` cause, which it refuses to answer, so two Batteries near one neighbour stop after one
# round each instead of feeding each other up to the bus's delivery cap.
const BLOCK := 3
const CAUSE := &"battery"

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.BLOCK or not (event.source is ChPartRuntime):
		return
	if event.data.get("cause") == CAUSE:
		return
	var holder: ChPartRuntime = event.source
	if not ctx.near(part, holder):
		return
	ctx.give_status(holder, ChStatuses.BLOCK, BLOCK, 1, part, CAUSE)
