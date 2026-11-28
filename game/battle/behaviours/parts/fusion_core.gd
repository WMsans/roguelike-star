extends ChBehaviour

# The Fusion Core (R27): while the pool is at its cap, the next part to fire gets a forced second fire.
# The forced fire carries `forced` in its payload, so the core never answers itself or another core.

var armed := false


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func process(ctx: ChBattleContext, _delta: float) -> void:
	var own := ctx.own(part)
	armed = own != null and own.energy != null and own.energy.value >= own.energy.cap


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var fired: ChPartRuntime = event.source
	if not armed or event.side != part.side or fired == null:
		return
	if event.data.get("forced", false):
		return
	armed = false
	ctx.force_fire(fired, part)
