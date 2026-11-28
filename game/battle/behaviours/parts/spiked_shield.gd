extends ChBehaviour

# The Spiked Shield (U25): a hit that deals damage equal to the body's own Block.

func fire(ctx: ChBattleContext) -> void:
	_hit_enemy_body(ctx, ctx.own(part).statuses.count(ChStatuses.BLOCK))
