extends ChBehaviour

# The Gantry (U87): as the battle opens, every part mounted on it gains 10 Block. The mount tree is
# the whole scope, whatever the distance (ChBehaviour._mounted), so no proximity range is involved.
const BLOCK := 10


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent):
		for child in _mounted():
			ctx.give_status(child, ChStatuses.BLOCK, BLOCK))
