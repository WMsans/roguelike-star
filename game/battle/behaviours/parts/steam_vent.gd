extends ChBehaviour

# The Steam Vent (U51): a burst of 20 steam cells 6 cells in front.
const CELLS := 20  # steam cells in the burst
const AHEAD := 6.0  # cells in front of the part the burst starts at

func fire(ctx: ChBattleContext) -> void:
	ctx.spawn(part, &"steam", part.anchor_world() + part.facing() * AHEAD, CELLS)
