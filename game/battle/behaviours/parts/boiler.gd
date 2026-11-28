extends ChBehaviour

# The Boiler (U69): a straight shot that splashes 10 water cells on the part it meets, then 6 fire
# cells on the same spot, where the sim's water and fire meet in a burst of steam.
const SPEED := 400.0  # cells per second along facing()
const WATER := 10  # water cells on the part hit
const FIRE := 6  # fire cells on the same spot

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var at := Vector2(shot.get("position", part.anchor_world()))
	ctx.spawn(part, &"water", at, WATER)
	ctx.spawn(part, &"fire", at, FIRE)