extends ChBehaviour

# The Mirror Plating (U85): a neighbour's Block running out pays its damage back to the attacker.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_LOST, func(event: ChEvent): _lost(ctx, event))

func _lost(ctx: ChBattleContext, event: ChEvent) -> void:
	# Acid eats Block too, but only a hit names the attacker, and only a neighbour's Block counts.
	if event.data.get("status") != ChStatuses.BLOCK or not event.data.has("attacker"):
		return
	var holder: Object = event.source
	if not (holder is ChPartRuntime) or not _neighbours(ctx).has(holder):
		return
	var attacker: ChPartRuntime = event.data["attacker"]
	if attacker == null or attacker.broken or attacker.body == null \
			or not is_instance_valid(attacker.body):
		return
	ctx.deal_hit(part, attacker.body, part.def.damage)
