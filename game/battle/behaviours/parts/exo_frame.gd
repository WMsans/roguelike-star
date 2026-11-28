extends ChBehaviour

# The Exo-Frame (R38): every part mounted on it has one size more range, so S 12 becomes M 20, M 20
# becomes L 32, and L 32 stays L. A part with no proximity range (0) keeps it: "no range" has no
# smaller size to grow from. Folding STAT_RANGE reaches range_of, which every scope measures with.

func modify_stat(_ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_RANGE or not (target is ChPartRuntime):
		return value
	if target.parent != part or value <= 0.0:
		return value
	# S (12) is below M, M (20) is below L; L (32) and anything larger stays at L.
	if value < 20.0:
		return 20.0
	return 32.0
