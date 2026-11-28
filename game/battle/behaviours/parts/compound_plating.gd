extends ChBehaviour

# The Compound Plating (U29): every 5 seconds the body gains 10% of its Block, but never less than 5.
const SECONDS := 5.0
const SHARE := 0.10
const MIN_BLOCK := 5

var left := 0.0  # seconds until the next gain

func process(ctx: ChBattleContext, delta: float) -> void:
	left += delta
	if left < SECONDS:
		return
	left -= SECONDS
	var body := ctx.own(part)
	if body == null:
		return
	var block: int = body.statuses.count(ChStatuses.BLOCK)
	ctx.give_status(body, ChStatuses.BLOCK, maxi(MIN_BLOCK, floori(block * SHARE)))
