extends ChBehaviour

# The Momentum Hammer (U55): a straight shot that pays 30, and each Speedup it gains is +10 damage
# for the battle.
const SPEED := 200.0  # cells per second along facing()
const BONUS := 10

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.STATUS_GAINED, func(event: ChEvent): _gained(ctx, event))

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)

func _gained(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("status") != ChStatuses.SPEEDUP or event.source != part:
		return
	part.bonus_damage += BONUS
