extends ChBehaviour

# The Lightning Rod (C24): sparks meant for another own part within range are drawn here instead.
# The gain hook sees every Shock gain on both sides, so the Rod takes the neighbour's stacks and
# refuses them for the neighbour.
func modify_gain(ctx: ChBattleContext, target: Object, status: StringName, amount: int,
		cause: StringName) -> int:
	if status != ChStatuses.SHOCK or cause != &"sparks":
		return amount
	if target is ChPartRuntime and target != part and ctx.near(part, target):
		ctx.give_status(part, ChStatuses.SHOCK, amount, 1, null, &"rod")
		return 0
	return amount
