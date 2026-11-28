extends ChBehaviour

# The Ice Scope (U13): a neighbouring weapon's hit gets +25 when the holder it strikes has Freeze.
const BONUS := 25

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source == null or source == part or source.def == null \
			or not source.def.tags.has("weapon"):
		return
	# The holder the hit lands on: the part struck, or the body for a hull hit.
	var holder: Object = hit.get("target_part")
	if holder == null:
		holder = hit.get("target_chariot")
	if holder == null or holder.statuses.count(ChStatuses.FREEZE) == 0:
		return
	if ctx.near(part, source):
		hit["bonus"] = int(hit["bonus"]) + BONUS