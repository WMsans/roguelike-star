extends ChBehaviour

# The Overdrive Clutch (U36): every 10th firing by a neighbouring melee weapon gives that weapon
# 3 Speedup.
const FIRES := 10
const SPEEDUP := 3

var _fires := 0  # melee-neighbour firings counted so far


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or not _neighbours(ctx, "melee").has(source):
		return
	_fires += 1
	if _fires % FIRES == 0:
		ctx.give_status(source, ChStatuses.SPEEDUP, SPEEDUP)
