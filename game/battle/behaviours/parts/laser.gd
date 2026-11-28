extends ChBehaviour

# The Laser (C07): a beam out to the def's reach (120 cells). Each tick is one strike on the body
# the beam reaches; the loop announces the switch-on and pays the energy per second.
func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _beam_target(ctx)
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage)
	return true
