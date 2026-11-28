extends ChBehaviour

# The Weather Vane (U52): each frame the disc of range_of(part) around it blows its gases one cell
# towards the enemy's x, so they drift sideways instead of rising.
const DRIFT := 1  # cells a frame

func process(ctx: ChBattleContext, _delta: float) -> void:
	var enemy := ctx.enemy_of(part)
	if enemy == null:
		return
	var toward := int(signf(enemy.anchor_world().x - part.anchor_world().x))
	if toward == 0:
		return
	var reach := roundi(ctx.range_of(part))
	var centre := Vector2i(roundi(part.anchor_world().x), roundi(part.anchor_world().y))
	# One row per strip, because a rect would blow the square's corners too and this part's reach is
	# a disc. A row at dy reaches sqrt(reach^2 - dy^2) cells either side of the centre.
	for dy in range(-reach, reach + 1):
		var half := int(sqrt(float(reach * reach - dy * dy)))
		var strip := Rect2i(centre + Vector2i(-half, dy), Vector2i(half * 2 + 1, 1))
		ctx.blow(strip, Vector2i(toward * DRIFT, 0))
