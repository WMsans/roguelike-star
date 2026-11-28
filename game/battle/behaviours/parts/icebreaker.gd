extends ChBehaviour

# The Icebreaker (U09): 100 on the body, and an enemy holder's Freeze gives this 1 Speedup.
const SPEEDUP := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func fire(ctx: ChBattleContext) -> void:
	_hit_enemy_body(ctx, part.def.damage)

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	# Any enemy holder, the body included: the event's side is the holder's.
	if event.data.get("status") != ChStatuses.FREEZE or event.side == part.side:
		return
	ctx.give_status(part, ChStatuses.SPEEDUP, SPEEDUP)