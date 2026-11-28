extends ChBehaviour

# The Heat Shield (U03): while it burns, it turns its own Flame into Block once a second.
const SECONDS := 1.0

var left := 0.0  # seconds until the next second of Block

func process(ctx: ChBattleContext, delta: float) -> void:
	left += delta
	if left < SECONDS:
		return
	left -= SECONDS
	var flame := part.statuses.count(ChStatuses.FLAME)
	if flame > 0:
		ctx.give_status(part, ChStatuses.BLOCK, flame)
