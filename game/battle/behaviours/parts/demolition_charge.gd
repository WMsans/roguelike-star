extends ChBehaviour

# The Demolition Charge (U45): a lob that leaves a large blast where it lands, for the def's damage
# and down to hardness 6. The blast, its ownership and its wear are ChHazards' own.
const SPEED := 60.0  # cells per second along the lob's line
const DIG := 6  # the hardness the crater reaches

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _landed(ctx, shot))

func _landed(ctx: ChBattleContext, shot: Dictionary) -> void:
	var at := Vector2i(shot.get("position", part.anchor_world()))
	ctx.explode(part, at, &"large", part.def.damage, DIG)
