extends ChBehaviour

# The Bloodsaw (R16): 15 a tick and 1 more for every tick it has already landed this battle.
var ticks := 0  # landed ticks this battle


func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage + ticks)
	ticks += 1
	return true
