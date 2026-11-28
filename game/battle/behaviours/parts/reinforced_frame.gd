extends ChBehaviour

# The Reinforced Frame (C38): 100 more max HP, and the body starts with them.
const HP := 100

func setup(ctx: ChBattleContext) -> void:
	var chariot := ctx.own(part)
	if chariot == null:
		return
	chariot.max_hp += HP
	chariot.hp += HP
