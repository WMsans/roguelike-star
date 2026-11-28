extends ChBehaviour

# The Gust Cannon (U48): one blast down a 20-cell box ahead. The nearest enemy body in the box pays
# 10, the enemy chariot is shoved along facing(), and the box's gases are blown 20 cells forward.
# The row's Rng cell is empty, so the box's length is this part's own number rather than def.reach.
const REACH := 20.0  # cells from the part's edge along its facing
const BLOW := 20  # cells the gas in the box moves
const KNOCKBACK := 600.0  # impulse the enemy chariot takes

func fire(ctx: ChBattleContext) -> void:
	var box := _reach_box(REACH)
	var target := _nearest_enemy_body(ctx, box)
	if target != null:
		ctx.deal_hit(part, target, part.def.damage)
	ctx.push(ctx.enemy_of(part), part.facing() * KNOCKBACK)
	ctx.blow(Rect2i(box), Vector2i(part.facing() * BLOW))
