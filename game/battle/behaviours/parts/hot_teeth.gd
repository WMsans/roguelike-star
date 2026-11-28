extends ChBehaviour

# The Hot Teeth (U32): a neighbouring melee weapon's firing spawns one fire cell where that weapon's
# last hit landed. The melee step deals the hit and then announces the firing, so the HIT that gave
# the position has already been delivered when the PART_FIRED arrives.
const CELLS := 1

var _hit_at := {}  # weapon -> the position its last HIT struck


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _remember(ctx, event))
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _remember(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx, "melee").has(source):
		return
	# What the weapon hit: its part, or the hull for a body hit, read off the HIT payload.
	var target: ChPartRuntime = event.data.get("target_part")
	if target != null:
		_hit_at[source] = target.anchor_world()
		return
	var side := int(event.data.get("target_side", -1))
	if side >= 0 and side < ctx.chariots.size() and ctx.chariots[side] != null:
		_hit_at[source] = ctx.chariots[side].anchor_world()


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _hit_at.has(source) or not _neighbours(ctx, "melee").has(source):
		return
	ctx.spawn(part, &"fire", _hit_at[source], CELLS)
