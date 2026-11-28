extends ChBehaviour

# The Spare Cell (C36): 5 more energy capacity, and the pool starts full.
const CAPACITY := 5

func setup(ctx: ChBattleContext) -> void:
	var chariot := ctx.own(part)
	if chariot == null or chariot.energy == null:
		return
	chariot.energy.cap += CAPACITY
	chariot.energy.value += CAPACITY
