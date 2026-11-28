extends ChBehaviour

# The Spiked Armour (U82): a hit on this part pays its damage back to the attacking part.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _hit_back(ctx, event))

func _hit_back(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("target_part") != part:
		return
	var attacker: ChPartRuntime = event.source
	if attacker == null or attacker.broken or attacker.body == null \
			or not is_instance_valid(attacker.body):
		return
	ctx.deal_hit(part, attacker.body, part.def.damage)
