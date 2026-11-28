extends ChBehaviour

# The Thermal Plating (U30): when this part gains Block, every neighbouring weapon spawns one more
# fire cell per hit for the rest of the battle.
const CELLS := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.BLOCK or event.source != part:
		return
	for other in _neighbours(ctx, "weapon"):
		other.fire_cells_per_hit += CELLS
