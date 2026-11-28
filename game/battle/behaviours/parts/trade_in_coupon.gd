extends ChBehaviour

# The Trade-In Coupon (U67): the first reroll in each shop phase is free. The shop folds its price
# through ChRun.STAT_REROLL_PRICE and resets run.rerolls_this_shop when it opens.
func run_stat(run: ChRun, _state: Dictionary, stat: StringName, value: int) -> int:
	if stat == ChRun.STAT_REROLL_PRICE and run.rerolls_this_shop == 0:
		return 0
	return value
