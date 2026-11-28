extends ChBehaviour

# The Retribution (R35): Block absorbing a hit on any of your holders pays that much back to the
# attacker.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BLOCK_ABSORBED, func(event: ChEvent): _absorbed(ctx, event))

func _absorbed(ctx: ChBattleContext, event: ChEvent) -> void:
	var holder: Object = event.source
	if holder == null or holder.side != part.side:
		return
	var attacker: ChPartRuntime = event.data.get("attacker")
	if attacker == null or attacker.broken or attacker.body == null \
			or not is_instance_valid(attacker.body):
		return
	ctx.deal_hit(part, attacker.body, int(event.data["amount"]))
