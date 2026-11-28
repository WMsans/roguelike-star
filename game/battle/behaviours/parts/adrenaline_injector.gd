extends ChBehaviour

# The Adrenaline Injector (U78): the first time HP falls below half each battle, every own part
# gains 5 Speedup.
const SPEEDUP := 5

var crossed := false  # the first fall below half this battle is the only one

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HP_LOST, func(event: ChEvent): _lost(ctx, event))

func _lost(ctx: ChBattleContext, event: ChEvent) -> void:
	if crossed or event.side != part.side:
		return
	var chariot := ctx.own(part)
	if chariot == null:
		return
	# The loss that starts and ends either side of half: one that begins below half is no crossing.
	var before := int(event.data["before"])
	var after := int(event.data["after"])
	if before * 2 < chariot.max_hp or after * 2 >= chariot.max_hp:
		return
	crossed = true
	for other in _own_parts(ctx):
		ctx.give_status(other, ChStatuses.SPEEDUP, SPEEDUP)
	ctx.give_status(part, ChStatuses.SPEEDUP, SPEEDUP)
