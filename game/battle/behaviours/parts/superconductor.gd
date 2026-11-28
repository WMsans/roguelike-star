extends ChBehaviour

# The Superconductor (R09): the enemy side's Shock deals double damage (the Shock this part inflicts
# sits on enemy parts), and an own part cannot gain Shock at all. The body is no part, so it can still
# be shocked, at the normal rate.

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_SHOCK_DAMAGE:
		return value
	return value * 2.0 if not _own(target) else value

func modify_gain(ctx: ChBattleContext, target: Object, status: StringName, amount: int,
		cause: StringName) -> int:
	if status == ChStatuses.SHOCK and target is ChPartRuntime and target.side == part.side:
		return 0
	return amount

func _own(target: Object) -> bool:
	if target == null:
		return false
	var side: Variant = target.get("side")
	return side != null and int(side) == part.side
