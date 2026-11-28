extends ChBehaviour

# The Gear Train (U33): every 4th firing by a neighbouring melee weapon pays its chariot 1 energy.
const FIRES := 4
const ENERGY := 1

var _fires := 0  # melee-neighbour firings counted so far


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: Object = event.source
	if not (source is ChPartRuntime) or not _neighbours(ctx, "melee").has(source):
		return
	_fires += 1
	if _fires % FIRES == 0:
		ctx.gain_energy(ctx.own(part), ENERGY)
