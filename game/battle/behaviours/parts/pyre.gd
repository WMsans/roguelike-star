extends ChBehaviour

# The Pyre (R03): damage on the enemy body equal to the enemy's Flame, parts and body together.
func fire(ctx: ChBattleContext) -> void:
	_hit_enemy_body(ctx, _flame(ctx))

func _flame(ctx: ChBattleContext) -> int:
	var chariot := ctx.enemy_of(part)
	var total := chariot.statuses.count(ChStatuses.FLAME) if chariot != null else 0
	for foe in _enemy_parts(ctx):
		total += foe.statuses.count(ChStatuses.FLAME)
	return total
