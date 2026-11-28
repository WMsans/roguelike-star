extends ChBehaviour

# The Ram Spike (U73): when its chariot rams, the part it met takes 40. The ram names the target; a
# contact that met only the hull pays the hull.

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.RAMMED, func(event: ChEvent): _rammed(ctx, event))


func _rammed(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.side != part.side:
		return
	var target: ChPartRuntime = event.data.get("target_part")
	var body: Object = target.body if target != null else null
	if body == null:
		var foe := ctx.enemy_of(part)
		body = foe.chassis if foe != null else null
	if body == null:
		return
	ctx.deal_hit(part, body, part.def.damage)
