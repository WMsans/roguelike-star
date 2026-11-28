extends ChBehaviour

# The Death Wish (R34): every second while HP is below half, every own part gains 1 Speedup.
const SPEEDUP := 1
const SECONDS := 1.0

var left := 0.0  # seconds until the next check

func process(ctx: ChBattleContext, delta: float) -> void:
	left += delta
	if left < SECONDS:
		return
	left -= SECONDS
	var chariot := ctx.own(part)
	if chariot == null or chariot.hp * 2 >= chariot.max_hp:
		return
	for other in _own_parts(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
	ctx.give_status(part, ChStatuses.SPEEDUP, SPEEDUP)
