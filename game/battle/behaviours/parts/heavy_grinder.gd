extends ChBehaviour

# The Heavy Grinder (U34): 20 a tick, and 2 more for every second of unbroken contact. A tick that
# finds nothing ends the contact, so the next landed tick starts from the base damage again.
const RAMP := 2

var seconds := 0  # consecutive landed ticks


func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target == null:
		seconds = 0
		return false
	ctx.deal_hit(part, target, part.def.damage + RAMP * seconds)
	seconds += 1
	return true
