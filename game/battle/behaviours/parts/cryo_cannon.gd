extends ChBehaviour

# The Cryo Cannon (U08): a straight shot that pays 40 and bursts into frost cells, twice as many
# when the part it hit is Wet.
const SPEED := 400.0  # cells per second along facing()
const CELLS := 8  # frost cells on a dry part
const WET_TIMES := 2  # times the frost when the part hit is Wet

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	var cells := CELLS
	if met != null and is_instance_valid(met):
		ctx.deal_hit(part, met, part.def.damage)
		# The part hit, or nobody for a hull hit: the same split deal_hit makes.
		var struck: Object = ctx.part_of_body(met)
		if struck != null and struck.statuses.count(ChStatuses.WET) > 0:
			cells *= WET_TIMES
	ctx.spawn(part, &"frost", Vector2(shot.get("position", part.anchor_world())), cells)