extends ChBehaviour

# The Static Gears (U58): a neighbour's Speedup arms its next hit to throw sparks at the target.
var _armed: Array[ChPartRuntime] = []

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _hit(ctx, event))

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SPEEDUP or event.side != part.side:
		return
	if not (event.source is ChPartRuntime):
		return
	var holder: ChPartRuntime = event.source
	if _armed.has(holder) or not _neighbours(ctx).has(holder):
		return
	_armed.append(holder)

func _hit(ctx: ChBattleContext, event: ChEvent) -> void:
	var attacker: ChPartRuntime = event.source
	if attacker == null or not _armed.has(attacker):
		return
	_armed.erase(attacker)
	var target: ChPartRuntime = event.data.get("target_part")
	var at := target.anchor_world() if target != null else _target_centre(ctx, event)
	ctx.throw_sparks(part, at)

func _target_centre(ctx: ChBattleContext, event: ChEvent) -> Vector2:
	var side := int(event.data.get("target_side", -1))
	if side < 0 or side >= ctx.chariots.size() or ctx.chariots[side] == null:
		return Vector2.ZERO
	return ChBattle.hull_box(ctx.chariots[side]).get_center()
