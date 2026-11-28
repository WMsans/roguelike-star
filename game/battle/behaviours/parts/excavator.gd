extends ChBehaviour

# The Excavator (U47): a continuous melee weapon that also cuts a column straight down under itself
# while it runs. The column is 3 cells wide and each cut reaches 4 cells deeper than the last, down to
# hardness 6, so it opens the way to lava in time. The dig is on the part's own clock rather than the
# tick's, because the excavator still digs with nothing in reach (the Drill's rule).
const DIG_RADIUS := 1  # cells: a 3-wide column
const DIG_STEP := 4  # cells deeper each cut
const HARDNESS := 6
const DIG_SECONDS := 0.5

var _next := DIG_SECONDS  # ctx.time the next cut is due
var _depth := 0.0  # cells below the anchor the column has reached

func continuous_tick(ctx: ChBattleContext) -> bool:
	return _strike(ctx)

func process(ctx: ChBattleContext, _delta: float) -> void:
	if not part.running or ctx.time < _next:
		return
	# The clock restarts from now rather than adding a period, so a pause never pays out a backlog of
	# cuts in one frame.
	_next = ctx.time + DIG_SECONDS
	if ctx.world == null:
		return
	_depth += DIG_STEP
	ctx.dig(Vector2i(part.anchor_world() + Vector2.DOWN * _depth), DIG_RADIUS, HARDNESS)
