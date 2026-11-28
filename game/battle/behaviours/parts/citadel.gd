extends ChBehaviour

# The Citadel (R14): damage to any own part spends the body's Block first. A hull hit already does.
func modify_incoming(ctx: ChBattleContext, hit: Dictionary) -> void:
	if hit.get("target_part") != null:
		hit["block_holder"] = ctx.own(part)
