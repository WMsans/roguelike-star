extends ChBehaviour

# The Smokestack (U49): when a Fire-tagged own part fires, it leaves a puff of smoke 4 cells in
# front of that part.
const CELLS := 8  # smoke cells in the puff
const AHEAD := 4.0  # cells in front of the part that fired

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))

func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var fired: ChPartRuntime = event.source
	if fired == null or fired.side != part.side or fired.def == null:
		return
	if not fired.def.tags.has("fire"):
		return
	ctx.spawn(part, &"smoke", fired.anchor_world() + fired.facing() * AHEAD, CELLS)
