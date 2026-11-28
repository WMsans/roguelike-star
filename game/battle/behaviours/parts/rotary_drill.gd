extends ChBehaviour

# The Rotary Drill (U35): a continuous melee weapon that chews the ground at its tip once a second
# and gains 1 Block for every cell it takes out. Like the Drill, the dig is on the part's own clock
# rather than the tick's, so it still cuts while nothing is in reach.
const DIG_RADIUS := 2  # cells
const DIG_HARDNESS := 7  # steel, and nothing harder
const DIG_SECONDS := 1.0
const BLOCK_PER_CELL := 1

var dig_left := 0.0  # seconds until the tip digs again


func continuous_tick(ctx: ChBattleContext) -> bool:
	return _strike(ctx)


func process(ctx: ChBattleContext, delta: float) -> void:
	if not part.running:
		return
	dig_left -= delta
	if dig_left > 0.0:
		return
	dig_left += DIG_SECONDS
	if ctx.world == null:
		return
	# The tip is the far edge of the reach box along facing(), the point the bit stands at.
	var box := _reach_box()
	var tip: Vector2 = box.get_center() + box.size * 0.5 * part.facing()
	# dig answers the cells the CELLS_DUG event reports, so the Block counts this part's own dig.
	var dug := ctx.dig(Vector2i(tip), DIG_RADIUS, DIG_HARDNESS)
	if dug > 0:
		ctx.give_status(part, ChStatuses.BLOCK, dug * BLOCK_PER_CELL)
