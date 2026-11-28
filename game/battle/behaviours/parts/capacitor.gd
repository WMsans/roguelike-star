extends ChBehaviour

# The Capacitor (U17): a part within range that gains Shock, on either side, gives 1 energy.

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SHOCK:
		return
	var holder: Object = event.source
	if holder == null or holder.anchor_world().distance_to(part.anchor_world()) > ctx.range_of(part):
		return
	ctx.gain_energy(ctx.own(part), 1.0)
