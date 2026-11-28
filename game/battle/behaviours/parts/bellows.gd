extends ChBehaviour

# The Bellows (U06): a neighbour's fire cells give every neighbour 1 Speedup.
const SPEEDUP := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.CELLS_SPAWNED, func(event: ChEvent): _spawned(ctx, event))

func _spawned(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("material") != &"fire":
		return
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx).has(source):
		return
	for other in _neighbours(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
