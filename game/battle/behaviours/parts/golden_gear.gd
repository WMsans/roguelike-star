extends ChBehaviour

# The Golden Gear (R29): 20 damage a shot, plus 10 for every part the run has sold. The count is
# ChChariotRuntime.parts_sold, filled by the builder from ChRun.player_layout.
const PER_SOLD := 10
const SPEED := 200.0  # cells per second along facing()

func fire(ctx: ChBattleContext) -> void:
	var chariot := ctx.own(part)
	var sold := chariot.parts_sold if chariot != null else 0
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot,
		part.def.damage + PER_SOLD * sold))

func _impact(ctx: ChBattleContext, shot: Dictionary, damage: int) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, damage)
