extends ChBehaviour

# The Bunker Frame (U28): +1 inventory slot out of battle, and 30 Block on the body as one opens.
const BLOCK := 30
const SLOT := 1

func run_stat(_run: ChRun, _state: Dictionary, stat: StringName, value: int) -> int:
	if stat == ChRun.STAT_INVENTORY_CAPACITY:
		return value + SLOT
	return value

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent):
		ctx.give_status(ctx.own(part), ChStatuses.BLOCK, BLOCK))
