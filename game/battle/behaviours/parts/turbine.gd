extends ChBehaviour

# The Turbine (U50): an enemy part's Slow gains 1 energy.
const ENERGY := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	# The row says enemy part, so the enemy hull's own Slow does not count. A broken part gains no
	# status at all (give_status drops it), so the part that gains here is always unbroken.
	if event.data.get("status") != ChStatuses.SLOW or event.side == part.side \
			or not (event.source is ChPartRuntime):
		return
	ctx.gain_energy(ctx.own(part), ENERGY)
