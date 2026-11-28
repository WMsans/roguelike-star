extends ChBehaviour

# The Blast Shield (U44): an explosion within its range gives every neighbour 10 Block. The listener
# is chariot-wide, so the distance is measured here against range_of(part), the same range a
# neighbour has to sit inside to be one.
const BLAST_BLOCK := 10

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.EXPLOSION, func(event: ChEvent): _blast(ctx, event))

func _blast(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.position.distance_to(part.anchor_world()) > ctx.range_of(part):
		return
	for other in _neighbours(ctx):
		ctx.give_status(other, ChStatuses.BLOCK, BLAST_BLOCK, 1, part, &"blast")
