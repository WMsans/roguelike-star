extends ChBehaviour

# The Universal Solvent (R10): Acid on an enemy part also costs the enemy HP. `_status_damage` reads
# the stat and pays the Acid it deals to a part's integrity through lose_hp.
func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if stat != ChBattleContext.STAT_ACID_TO_HP or not (target is ChPartRuntime):
		return value
	return 1.0 if target.side != part.side else value
