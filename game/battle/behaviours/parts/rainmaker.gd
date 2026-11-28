extends ChBehaviour

# The Rainmaker (U07): a 3 s rain cloud that drops 4 water particles a tick above the enemy.
const SECONDS := 3.0  # how long the cloud rains
const PER_TICK := 4  # water particles a tick
const HEIGHT := 20.0  # cells above the enemy hull's centre the cloud sits
const FALL := 40.0  # cells per second the drops fall

var left := 0.0  # seconds of rain left

func fire(ctx: ChBattleContext) -> void:
	left = SECONDS

func process(ctx: ChBattleContext, delta: float) -> void:
	if left <= 0.0:
		return
	left -= delta
	var foe := ctx.enemy_of(part)
	if foe == null:
		return
	var at := ChBattle.hull_box(foe).get_center() + Vector2(0.0, -HEIGHT)
	ctx.world.spawn_particles(&"water", at, Vector2(0.0, FALL), PER_TICK, 0.5)