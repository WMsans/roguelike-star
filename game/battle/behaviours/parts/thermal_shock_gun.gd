extends ChBehaviour

# The Thermal Shock Gun (U71): a straight shot that pays 30; the part it hits bursts into 3 fire
# cells for each Freeze it has, or into 12 frost cells when it has none.
const SPEED := 400.0  # cells per second along facing()
const FROST := 12  # frost cells on a part without Freeze
const FIRE_PER_FREEZE := 3  # fire cells for each Freeze on the part hit

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	var at := Vector2(shot.get("position", part.anchor_world()))
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
	# The part hit, or nobody for a hull hit: the same split deal_hit makes.
	var struck: Object = ctx.part_of_body(met) if met != null and is_instance_valid(met) else null
	var freeze: int = struck.statuses.count(ChStatuses.FREEZE) if struck != null else 0
	if freeze > 0:
		ctx.spawn(part, &"fire", at, FIRE_PER_FREEZE * freeze)
	else:
		ctx.spawn(part, &"frost", at, FROST)