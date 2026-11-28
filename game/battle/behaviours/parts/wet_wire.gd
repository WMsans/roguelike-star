extends ChBehaviour

# The Wet Wire (U18): a Wet enemy part takes double the Shock a spark gives it.

func modify_gain(ctx: ChBattleContext, target: Object, status: StringName, amount: int,
		cause: StringName) -> int:
	if status != ChStatuses.SHOCK or cause != &"sparks":
		return amount
	if target is ChPartRuntime and target.side != part.side \
			and target.statuses.count(ChStatuses.WET) > 0:
		return amount * 2
	return amount
