extends ChBehaviour

# The Cold Snap (U11): 10 frost cells on the enemy part with the most Wet, or on the hull when no
# part is Wet at all. Ties go to mount order, which is the order _enemy_parts walks.
const CELLS := 10

func fire(ctx: ChBattleContext) -> void:
	var chariot := ctx.enemy_of(part)
	if chariot == null:
		return
	var at := chariot.anchor_world()
	var most := 0
	for foe in _enemy_parts(ctx):
		var wet := foe.statuses.count(ChStatuses.WET)
		if wet > most:
			most = wet
			at = foe.anchor_world()
	ctx.spawn(part, &"frost", at, CELLS)