extends ChBehaviour

# The Stabiliser (U40): while the chariot stands still, every weapon neighbour gains 1 Speedup
# every 3 seconds of the fight.
const SPEEDUP := 1
const PERIOD := 3.0

var _next := PERIOD  # ctx.time the next gain is due


func process(ctx: ChBattleContext, _delta: float) -> void:
	var own := ctx.own(part)
	if own == null or own.driving or ctx.time < _next:
		return
	# A period missed while driving is dropped rather than banked, so a release never pays out the
	# whole backlog in consecutive frames; the next gain is a whole period after this one.
	_next = ctx.time + PERIOD
	for other in _neighbours(ctx, "weapon"):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
