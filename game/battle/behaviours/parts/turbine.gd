extends ChBehaviour

# The Turbine (U50): an enemy holder's Slow gains 1 energy.
const ENERGY := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	# Any enemy holder, the body included: the event's side is the holder's.
	if event.data.get("status") != ChStatuses.SLOW or event.side == part.side:
		return
	ctx.gain_energy(ctx.own(part), ENERGY)
