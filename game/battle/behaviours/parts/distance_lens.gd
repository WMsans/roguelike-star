extends ChBehaviour

# The Distance Lens (R18): an own beam's hit gets +1 for every 5 cells between the chariots.
const CELLS := 5.0

func links(_ctx: ChBattleContext, a: Object, b: Object) -> bool:
	# The row's Rng is "—", so it is chariot-wide and claims every own beam as linked, which is what
	# lets deal_hit ask it for that beam's hits. Only when it is the pair's own first part, so it
	# claims no link between any other two.
	return a == part and b is ChPartRuntime and b.def != null and b.side == part.side \
			and b.def.tags.has("beam")

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source == null or source.def == null or source.side != part.side \
			or not source.def.tags.has("beam"):
		return
	var own := ctx.own(part)
	var foe := ctx.enemy_of(part)
	if own == null or foe == null:
		return
	var gap := own.anchor_world().distance_to(foe.anchor_world())
	hit["bonus"] = int(hit["bonus"]) + floori(gap / CELLS)
