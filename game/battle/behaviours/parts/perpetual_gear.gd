extends ChBehaviour

# The Perpetual Gear (R25): its own Speedup gain (n) gives the part in front 2n. Its hand-out carries
# the `perpetual` cause, which it refuses to answer, so two adjacent gears facing each other stop
# after one round instead of doubling until the int64 wraps.
const FACTOR := 2
const CAUSE := &"perpetual"

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SPEEDUP or event.source != part \
			or event.data.get("cause") == CAUSE:
		return
	var front := _front_part(ctx)
	if front != null:
		ctx.give_status(front, ChStatuses.SPEEDUP, int(event.data.get("amount", 0)) * FACTOR,
			1, part, CAUSE)
