extends ChBehaviour

# The Stinger (C05): a cooldown stab out to the def's reach (48 cells, twice the other melee
# weapons). A stab that meets nothing still paid and still counts: the volley owns both.
func fire(ctx: ChBattleContext) -> void:
	_strike(ctx)
