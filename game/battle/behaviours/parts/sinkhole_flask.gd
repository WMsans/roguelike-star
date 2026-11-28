extends ChBehaviour

# The Sinkhole Flask (U24): a flask lobbed under LOB_GRAVITY that bursts into a 30-cell acid pool
# under the enemy hull's bottom centre, whatever it met on the way.
const SPEED := 60.0  # cells per second along the lob's line
const CELLS := 30  # acid cells the flask bursts into

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, _shot: Dictionary) -> void:
	var foe := ctx.enemy_of(part)
	if foe == null:
		return
	var box := _hull_box(foe)
	ctx.spawn(part, &"acid", Vector2(box.get_center().x, box.end.y + 1.0), CELLS)
