extends ChBehaviour

# The Overflow Valve (U59): every second the pool is at its cap, the body gains 3 Block.
const BLOCK := 3
const PERIOD := 1.0

var _next := PERIOD  # ctx.time the next gain is due


func process(ctx: ChBattleContext, _delta: float) -> void:
	var own := ctx.own(part)
	if own == null or own.energy == null or own.energy.value < own.energy.cap or ctx.time < _next:
		return
	# A period missed while the pool was not full is dropped rather than banked, so coming back to
	# full never pays out a backlog in consecutive frames; the next gain is a whole period after this.
	_next = ctx.time + PERIOD
	ctx.give_status(own, ChStatuses.BLOCK, BLOCK)
