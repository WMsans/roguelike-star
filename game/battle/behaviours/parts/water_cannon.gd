extends ChBehaviour

# The Water Cannon (C20): a straight jet that pays 10, shoves the enemy back and leaves water cells
# on the body it meets, which the status second turns into Wet.
const SPEED := 200.0  # cells per second along facing()
const CELLS := 6  # water cells over the part hit
const KNOCKBACK := 200.0  # the impulse the enemy's chassis takes

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
		ctx.push(ctx.enemy_of(part), part.facing() * KNOCKBACK)
	ctx.spawn(part, &"water", Vector2(shot.get("position", part.anchor_world())), CELLS)
