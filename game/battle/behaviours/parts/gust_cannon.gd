extends ChBehaviour

# The Gust Cannon (U48): one blast down a 20-cell box ahead. The nearest enemy body in the box pays
# 10, the enemy chariot is shoved along facing(), and the box's gases are blown 20 cells forward.
# The row's Rng cell is empty, so the box's length is this part's own number rather than def.reach.
const REACH := 20.0  # cells from the part's edge along its facing
const BLOW := 20  # cells the gas in the box moves
const KNOCKBACK := 600.0  # impulse the enemy chariot takes

func fire(ctx: ChBattleContext) -> void:
	var box := _blast_box()
	var target := _nearest_enemy_body(ctx, box)
	if target != null:
		ctx.deal_hit(part, target, part.def.damage)
	ctx.push(ctx.enemy_of(part), part.facing() * KNOCKBACK)
	ctx.blow(Rect2i(box), Vector2i(part.facing() * BLOW))

# The reach box for this part's own length: ChBehaviour._reach_box reads def.reach, which the row
# leaves at 0 because its Rng cell is empty.
func _blast_box() -> Rect2:
	var dir := part.facing()
	var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
	var along := absf(dir.x) * size.x + absf(dir.y) * size.y
	var across := absf(dir.x) * size.y + absf(dir.y) * size.x
	var half_along := REACH + 0.5 + 0.5 * along
	var half_across := 0.5 * across
	var span := Vector2(absf(dir.x) * half_along + absf(dir.y) * half_across,
		absf(dir.y) * half_along + absf(dir.x) * half_across)
	var at := part.anchor_world()
	return Rect2(at - span, span * 2)
