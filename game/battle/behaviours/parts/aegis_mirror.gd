extends ChBehaviour

# The Aegis Mirror (R12): the body gains Block equal to its current HP.

func fire(ctx: ChBattleContext) -> void:
	var body := ctx.own(part)
	if body != null:
		ctx.give_status(body, ChStatuses.BLOCK, body.hp)
