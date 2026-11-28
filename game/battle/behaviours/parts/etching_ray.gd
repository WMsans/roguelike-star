extends ChBehaviour

# The Etching Ray (U23): a beam out to the def's reach (80 cells). Each tick is one strike, and the
# Block that soaks it is spent twice as fast as the HP behind it.
const BLOCK_MULT := 2.0  # what Block spends per point of the hit it soaks

func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _beam_target(ctx)
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage, {"block_mult": BLOCK_MULT})
	return true
