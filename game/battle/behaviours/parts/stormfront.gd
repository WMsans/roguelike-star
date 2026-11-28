extends ChBehaviour

# The Stormfront (R24): an enemy holder's Slow gives every own part the same amount of Speedup.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	# Any enemy holder, the body included: the event's side is the holder's.
	if event.data.get("status") != ChStatuses.SLOW or event.side == part.side:
		return
	var amount := int(event.data.get("amount", 0))
	if amount <= 0:
		return
	var parts: Array[ChPartRuntime] = [part]
	parts.append_array(_own_parts(ctx))
	for other in parts:
		ctx.give_status(other, ChStatuses.SPEEDUP, amount)
