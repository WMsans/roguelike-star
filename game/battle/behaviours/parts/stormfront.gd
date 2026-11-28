extends ChBehaviour

# The Stormfront (R24): an enemy part's Slow gives every own part the same amount of Speedup.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	# The row says enemy part, so the enemy hull's own Slow does not count. A broken part gains no
	# status at all (give_status drops it), so the part that gains here is always unbroken.
	if event.data.get("status") != ChStatuses.SLOW or event.side == part.side \
			or not (event.source is ChPartRuntime):
		return
	var amount := int(event.data.get("amount", 0))
	if amount <= 0:
		return
	var parts: Array[ChPartRuntime] = [part]
	parts.append_array(_own_parts(ctx))
	for other in parts:
		ctx.give_status(other, ChStatuses.SPEEDUP, amount)
