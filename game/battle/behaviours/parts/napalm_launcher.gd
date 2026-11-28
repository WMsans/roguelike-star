extends ChBehaviour

# The Napalm Launcher (U05): a lob that pays 30, then oils the landing spot and lights it.
const SPEED := 60.0  # cells per second along the lob's line
const OIL_CELLS := 10  # oil cells in the splash
const FIRE_CELLS := 8  # fire cells that light it

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var at := Vector2(shot.get("position", part.anchor_world()))
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.spawn(part, &"oil", at, OIL_CELLS)
	ctx.spawn(part, &"fire", at, FIRE_CELLS)
