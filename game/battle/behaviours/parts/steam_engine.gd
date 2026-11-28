extends ChBehaviour

# The Steam Engine (R31): when statuses cancel on an enemy part, it takes 5 damage for each stack
# cancelled.
const PER_STACK := 5

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_CANCELLED, func(event: ChEvent): _cancelled(ctx, event))

func _cancelled(ctx: ChBattleContext, event: ChEvent) -> void:
	var holder: Object = event.source
	if holder == null or not (holder is ChPartRuntime) or event.side == part.side:
		return
	var amount := int(event.data.get("amount", 0))
	if amount <= 0:
		return
	ctx.deal_hit(part, holder.body, PER_STACK * amount)