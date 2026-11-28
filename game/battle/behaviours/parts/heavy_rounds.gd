extends ChBehaviour

# The Heavy Rounds (C35): the weapon in front deals +20 a hit and costs +1 energy - or +1 a second
# when that weapon is continuous.
const BONUS := 20
const COST := 1

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source != null and source == _front_part(ctx, "weapon"):
		hit["bonus"] = int(hit["bonus"]) + BONUS

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if target == null or target != _front_part(ctx, "weapon"):
		return value
	var def: ChPartDef = target.def
	if def == null:
		return value
	if stat == ChBattleContext.STAT_ENERGY_COST and not def.is_continuous():
		return value + COST
	if stat == ChBattleContext.STAT_ENERGY_PER_SECOND and def.is_continuous():
		return value + COST
	return value
