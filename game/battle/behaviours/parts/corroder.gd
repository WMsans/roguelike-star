extends ChBehaviour

# The Corroder (U21): a neighbouring melee weapon's hit drips one acid cell on what it hit each tick.
const CELLS := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _hit(ctx, event))

func _hit(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx, "melee").has(source):
		return
	ctx.spawn(source, &"acid", _target_position(ctx, event), CELLS)

func _target_position(ctx: ChBattleContext, event: ChEvent) -> Vector2:
	# What the weapon hit: its part, or the hull for a body hit, read off the HIT payload.
	var target: ChPartRuntime = event.data.get("target_part")
	if target != null:
		return target.anchor_world()
	var side := int(event.data.get("target_side", -1))
	if side >= 0 and side < ctx.chariots.size() and ctx.chariots[side] != null:
		return ctx.chariots[side].anchor_world()
	return event.position
