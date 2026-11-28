extends ChBehaviour

# The Wrecking Gear (R33): when its chariot rams, every own melee weapon fires 3 times. The firing is
# the fight's forced fire, so it pays nothing and leaves each weapon's own clock alone.

const FIRES := 3


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.RAMMED, func(event: ChEvent): _rammed(ctx, event))


func _rammed(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.side != part.side:
		return
	for weapon in _own_parts(ctx, "melee"):
		for _fire in FIRES:
			ctx.force_fire(weapon, part)
