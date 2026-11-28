extends ChBehaviour

# The Iron Will (R13): every 10 seconds, while the body's Block is greater than its HP, every own
# part gains 10 Speedup.
const SECONDS := 10.0
const SPEEDUP := 10

var left := 0.0  # seconds until the next check

func process(ctx: ChBattleContext, delta: float) -> void:
	left += delta
	if left < SECONDS:
		return
	left -= SECONDS
	var body := ctx.own(part)
	if body == null or body.statuses.count(ChStatuses.BLOCK) <= body.hp:
		return
	for other in _own_parts(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
	ctx.give_status(part, ChStatuses.SPEEDUP, SPEEDUP)
