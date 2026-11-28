extends ChBehaviour

# The Fuel Line (U02): a neighbour's fire cells come with oil cells of the same count.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.CELLS_SPAWNED, func(event: ChEvent): _spawned(ctx, event))

func _spawned(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("material") != &"fire":
		return
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx).has(source):
		return
	ctx.spawn(source, &"oil", event.data.get("at", source.anchor_world()), int(event.data.get("count", 0)))
