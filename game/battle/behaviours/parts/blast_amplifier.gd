extends ChBehaviour

# The Blast Amplifier (R22): every blast its side causes is one size bigger, and its own chariot pays
# neither its own blasts nor unowned terrain ones. A blast the other side caused is neither of those,
# so it is paid in full.
const SIZE_UP := 1.0

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat == ChBattleContext.STAT_OWN_BLAST_TAKEN or stat == ChBattleContext.STAT_ENV_BLAST_TAKEN:
		var own := ctx.own(part)
		return 0.0 if own != null and target == own else value
	if stat == ChBattleContext.STAT_BLAST_SIZE:
		var side: Variant = target.get("side") if target != null else null
		if side != null and int(side) == part.side:
			return value + SIZE_UP
	return value
