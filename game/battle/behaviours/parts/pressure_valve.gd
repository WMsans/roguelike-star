extends ChBehaviour

# The Pressure Valve (U70): when Flame is put out on any holder, every own Fire and Ice part gains
# 1 Speedup.
const SPEEDUP := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_CANCELLED, func(event: ChEvent): _cancelled(ctx, event))

func _cancelled(ctx: ChBattleContext, event: ChEvent) -> void:
	if not _flame_out(event.data.get("status"), event.data.get("against")):
		return
	# Its own part included: the valve is one of your Fire and Ice parts.
	var parts: Array[ChPartRuntime] = [part]
	parts.append_array(_own_parts(ctx))
	for other in parts:
		if other.def != null and (other.def.tags.has("fire") or other.def.tags.has("ice")):
			ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)

# Flame meeting Wet or Freeze is the pair that puts it out.
func _flame_out(status: Variant, against: Variant) -> bool:
	return (status == ChStatuses.FLAME and (against == ChStatuses.WET or against == ChStatuses.FREEZE)) \
		or (against == ChStatuses.FLAME and (status == ChStatuses.WET or status == ChStatuses.FREEZE))