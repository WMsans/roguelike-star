extends ChBehaviour

# The Molotov (C17): a bottle lobbed under LOB_GRAVITY that pays 30 on the body it meets and leaves a
# patch of fire where it lands. The patch is cells, so the burn is the sim's.
const SPEED := 60.0  # cells per second along the lob's line
const CELLS := 10  # fire cells the bottle bursts into

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	ctx.spawn(part, &"fire", Vector2(shot.get("position", part.anchor_world())), CELLS)
