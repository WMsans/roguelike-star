extends ChBehaviour

# The Sandbag (C29): 20 Block on itself as the battle opens, and 10 more when an explosion lands
# within 30 cells of it. The blast listener is chariot-wide, so the distance is measured here.
const BLOCK := 20
const BLAST_BLOCK := 10
const BLAST_RANGE := 30.0  # cells from the Sandbag's anchor

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent): _opened(ctx))
	ctx.bus.subscribe(self, ChEvent.EXPLOSION, func(event: ChEvent): _blast(ctx, event))

func _opened(ctx: ChBattleContext) -> void:
	ctx.give_status(part, ChStatuses.BLOCK, BLOCK)

func _blast(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.position.distance_to(part.anchor_world()) <= BLAST_RANGE:
		ctx.give_status(part, ChStatuses.BLOCK, BLAST_BLOCK)
