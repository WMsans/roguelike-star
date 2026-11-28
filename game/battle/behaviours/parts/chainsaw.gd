extends ChBehaviour

# The Chainsaw (C03): a continuous melee weapon, so every tick of contact is one swing out to the
# def's reach (ChPartDef.reach, 24 cells here). The box the swing measures and the body it hits are
# ChBehaviour's, shared with every melee part.
func continuous_tick(ctx: ChBattleContext) -> bool:
	return _strike(ctx)
