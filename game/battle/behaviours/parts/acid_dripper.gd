extends ChBehaviour

# The Acid Dripper (C26): 3 acid cells just under the hull's bottom centre every 2 seconds. The drip
# is on the part's own clock, so a passive with nothing to aim at still drips.
const CELLS := 3  # acid cells a drip
const SECONDS := 2.0

var left := 0.0  # seconds until the next drip

func process(ctx: ChBattleContext, delta: float) -> void:
	left += delta
	if left < SECONDS:
		return
	left -= SECONDS
	var chariot := ctx.own(part)
	if chariot == null or ctx.world == null:
		return
	var box := ChBattle.hull_box(chariot)
	ctx.spawn(part, &"acid", Vector2(box.get_center().x, box.end.y + 1.0), CELLS)
