extends ChBehaviour

# The First Aid Kit (C15): 120 HP back, once a battle, the first time the body falls below half.
# A pool that cannot pay the 4 leaves the kit unpaid, so it tries again on every later loss while
# the body is still below half.
const HEAL := 120
const COST := 4

var paid := false  # whether the kit has spent its one heal this battle

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HP_LOST, func(event: ChEvent): _check(ctx, event))

func _check(ctx: ChBattleContext, event: ChEvent) -> void:
	if paid or event.side != part.side:
		return
	var chariot := ctx.own(part)
	if chariot == null:
		return
	if int(event.data.get("after", chariot.hp)) >= chariot.max_hp / 2:
		return
	if not ctx.pay_trigger(part, COST):
		return
	paid = true
	ctx.heal(chariot, HEAL)
