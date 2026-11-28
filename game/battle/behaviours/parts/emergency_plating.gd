extends ChBehaviour

# The Emergency Plating (U79): the first time each battle the body would die, it survives at 1 HP
# and the body gains 50 Block.
const BLOCK := 50

var used := false  # the save is once a battle

func prevent_death(ctx: ChBattleContext, chariot: ChChariotRuntime) -> bool:
	if used:
		return false
	used = true
	ctx.give_status(chariot, ChStatuses.BLOCK, BLOCK)
	return true
