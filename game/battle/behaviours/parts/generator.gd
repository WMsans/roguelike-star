extends ChBehaviour

# The Generator (C37): 1 more energy regenerated every second.
const REGEN := 1.0

func setup(ctx: ChBattleContext) -> void:
	var chariot := ctx.own(part)
	if chariot != null and chariot.energy != null:
		chariot.energy.regen += REGEN
