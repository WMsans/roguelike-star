extends ChBehaviour

# The Excavator (U47): a continuous melee weapon that also cuts a column straight down under itself
# while it runs. The column is 3 cells wide, every row of it is cut, and it reaches down to hardness 6,
# so the way to lava stays open. A cut digs 4 cells deeper, and each of those rows is a blast centre:
# a radius-1 dig's rim is ragged (the engine's noise can leave a cell that is only on the rim), so a
# cut issues one dig per cell for every row it descends, and a cell that is a blast's centre always
# goes. The row names no width, so for the record: the 3 centres plus the radius-1 dig make the hole
# about 5 cells wide at its ragged edges. The dig is on the part's own clock rather than the tick's,
# because the excavator still digs with nothing in reach (the Drill's rule).
const DIG_RADIUS := 1  # cells: a 3-wide column
const DIG_STEP := 4  # cells deeper each cut, per the brief's "down 4 cells more each time"
const HARDNESS := 6
const DIG_SECONDS := 0.5

var _next := DIG_SECONDS  # ctx.time the next cut is due
var _depth := 0  # cells below the anchor the column has reached

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
	var at := Vector2i(part.anchor_world())
	# Every row of the cut is a blast centre in each of the column's cells, so the rows a cut adds
	# always clear and the next cut picks up where this one stopped.
	for dx in range(-DIG_RADIUS, DIG_RADIUS + 1):
		for dy in range(_depth - DIG_STEP + 1, _depth + 1):
			ctx.dig(at + Vector2i(dx, dy), DIG_RADIUS, HARDNESS)
