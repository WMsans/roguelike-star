extends ChBehaviour

# The Smoke Bomb (C31): a cloud of 30 smoke cells 6 cells ahead, which the status second turns into
# Slow for whatever stands in it.
const CELLS := 30
const AHEAD := 6.0  # cells in front of the part the cloud starts at

func fire(ctx: ChBattleContext) -> void:
	ctx.spawn(part, &"smoke", part.anchor_world() + part.facing() * AHEAD, CELLS)
