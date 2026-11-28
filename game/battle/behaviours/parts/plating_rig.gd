extends ChBehaviour

# The Plating Rig (C14): 3 Block on the neighbour that just fired.
const BLOCK := 3

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent):
		# A neighbour is another unbroken own part within ctx.range_of(part), which is what near reads.
		if event.source != null and event.source != part and ctx.near(part, event.source):
			ctx.give_status(event.source, ChStatuses.BLOCK, BLOCK))
