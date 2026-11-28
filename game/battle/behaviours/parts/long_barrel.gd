extends ChBehaviour

# The Long Barrel (U41): the weapon in front deals +50 a hit and takes 3 s longer to reload.
const BONUS := 50
const COOLDOWN := 3.0

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source != null and source == _front_part(ctx, "weapon"):
		hit["bonus"] = int(hit["bonus"]) + BONUS

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if target == null or target != _front_part(ctx, "weapon"):
		return value
	if stat == ChBattleContext.STAT_COOLDOWN:
		return value + COOLDOWN
	return value
