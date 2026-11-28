extends ChBehaviour

# The Absolute Zero (R04): damage on the enemy body equal to 3 times the enemy's Freeze, parts and
# body together.
const PER_FREEZE := 3

func fire(ctx: ChBattleContext) -> void:
	_hit_enemy_body(ctx, PER_FREEZE * _freeze(ctx))

func _freeze(ctx: ChBattleContext) -> int:
	var chariot := ctx.enemy_of(part)
	var total := chariot.statuses.count(ChStatuses.FREEZE) if chariot != null else 0
	for foe in _enemy_parts(ctx):
		total += foe.statuses.count(ChStatuses.FREEZE)
	return total