extends ChBehaviour

# The Glacier Engine (R06): an enemy part's Freeze puts 3 frost cells on it and on every part it
# touches. The Freeze those cells give arrives as &"cells" a status second later, so this runs once a
# second rather than in a loop.
const CELLS := 3

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.FREEZE \
			or event.data.get("cause") == &"glacier" or event.side == part.side:
		return
	var holder: Object = event.source
	if holder == null or not (holder is ChPartRuntime):
		return
	ctx.spawn(part, &"frost", holder.anchor_world(), CELLS)
	for other in ctx.touching(holder):
		ctx.spawn(part, &"frost", other.anchor_world(), CELLS)