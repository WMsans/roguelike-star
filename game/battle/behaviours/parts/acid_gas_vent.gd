extends ChBehaviour

# The Acid Gas Vent (U22): a cloud of 20 acid gas cells 6 cells in front.
const CELLS := 20  # acid gas cells in the cloud
const AHEAD := 6.0  # cells in front of the part the cloud starts at

func fire(ctx: ChBattleContext) -> void:
	ctx.spawn(part, &"acid_gas", part.anchor_world() + part.facing() * AHEAD, CELLS)
