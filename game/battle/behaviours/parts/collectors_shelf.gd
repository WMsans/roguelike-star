extends ChBehaviour

# The Collector's Shelf (U68): +1 inventory slot, and 10 Block on the body when a battle opens for
# each part the run carries. ChRun.player_layout puts that count on the battle's chariot.
const BLOCK := 10
const SLOT := 1

func run_stat(_run: ChRun, _state: Dictionary, stat: StringName, value: int) -> int:
	if stat == ChRun.STAT_INVENTORY_CAPACITY:
		return value + SLOT
	return value

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent):
		var chariot := ctx.own(part)
		if chariot != null:
			ctx.give_status(chariot, ChStatuses.BLOCK, BLOCK * chariot.inventory_count))
