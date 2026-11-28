extends ChBehaviour

# The Drill (C04): a continuous melee weapon that also digs the ground at its tip once a second
# while it runs. The dig is on the part's own clock rather than the tick's, because a drill with
# nothing in reach still runs (and still digs) while the button is held.
const DIG_RADIUS := 2  # cells
const DIG_HARDNESS := 5  # the ground the tip can chew
const DIG_SECONDS := 1.0

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
	ctx.dig(Vector2i(tip), DIG_RADIUS, DIG_HARDNESS)
