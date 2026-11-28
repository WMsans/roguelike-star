extends ChBehaviour

# The Earthquake (R21): collapses a 30-wide, 40-deep rect of ground straight under the enemy hull,
# down to hardness 8 (obsidian; concrete still never moves). ctx.dig cuts a disc, so the rect is
# tiled with discs that overlap; the outer row and column overrun the rect by one radius.
const WIDTH := 30  # cells across
const DEPTH := 40  # cells down from the hull's bottom edge
const RADIUS := 4  # cells per dig
const STEP := 2  # cells between dig centres: the engine's rim noise bites up to a quarter of a radius,
# so the discs overlap by half and every cell of the rect is inside one.
const HARDNESS := 8

func fire(ctx: ChBattleContext) -> void:
	var foe := ctx.enemy_of(part)
	if foe == null or ctx.world == null:
		return
	var hull := _hull_box(foe)
	var left := roundi(hull.get_center().x) - WIDTH / 2
	var top := roundi(hull.end.y)
	for y in range(top, top + DEPTH, STEP):
		for x in range(left, left + WIDTH, STEP):
			ctx.dig(Vector2i(x, y), RADIUS, HARDNESS)
