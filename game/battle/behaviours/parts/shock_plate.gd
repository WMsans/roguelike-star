extends ChBehaviour

# The Shock Plate (U84): a hit on this part throws its sparks at the attacking part.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _shock(ctx, event))

func _shock(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("target_part") != part:
		return
	var attacker: ChPartRuntime = event.source
	if attacker == null or attacker.broken or attacker.body == null \
			or not is_instance_valid(attacker.body):
		return
	ctx.throw_sparks(part, attacker.anchor_world())
