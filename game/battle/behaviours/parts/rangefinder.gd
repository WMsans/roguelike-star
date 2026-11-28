extends ChBehaviour

# The Rangefinder (U39): a weapon neighbour's hit gets +1 for every 10 cells between the chariots.
const CELLS := 10.0

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source == null or source.def == null or not source.def.tags.has("weapon"):
		return
	if not ctx.near(part, source):
		return
	var own := ctx.own(part)
	var foe := ctx.enemy_of(part)
	if own == null or foe == null:
		return
	# |own.x - enemy.x|: the row measures the horizontal gap, not the straight line.
	var gap := absf(own.anchor_world().x - foe.anchor_world().x)
	hit["bonus"] = int(hit["bonus"]) + floori(gap / CELLS)
