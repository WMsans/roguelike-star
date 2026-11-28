extends ChBehaviour

# The Sharpener (C34): a melee-tagged neighbour's hit gets +3, through the same hook every passive
# near the source is asked.
const BONUS := 3

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source == null or source == part or source.def == null \
			or not source.def.tags.has("melee"):
		return
	if ctx.near(part, source):
		hit["bonus"] = int(hit["bonus"]) + BONUS
