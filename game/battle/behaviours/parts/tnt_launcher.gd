extends ChBehaviour

# The TNT Launcher (U42): a lob that plants a 6x6 TNT crate where it lands. The crate is the world's
# own: fire or a spark sets it off, and spawn records it as the side's, so its blast is that side's.
const SPEED := 60.0  # cells per second along the lob's line
const CRATE_CELLS := 36  # a 6x6 crate

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _landed(ctx, shot))

func _landed(ctx: ChBattleContext, shot: Dictionary) -> void:
	ctx.spawn(part, &"tnt", Vector2(shot.get("position", part.anchor_world())), CRATE_CELLS)
