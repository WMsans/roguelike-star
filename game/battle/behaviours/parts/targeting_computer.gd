extends ChBehaviour

# The Targeting Computer (C33): 10 damage on the body it reaches, and every own weapon gains +2
# damage for the battle.
const BONUS := 2

func fire(ctx: ChBattleContext) -> void:
	_hit_enemy_body(ctx, part.def.damage)
	for other in _own_parts(ctx, "weapon"):
		other.bonus_damage += BONUS
