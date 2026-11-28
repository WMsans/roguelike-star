extends ChBehaviour

# The Buzzsaw Arm (U31): a continuous melee weapon that hits 5 harder on its next landed tick after
# a neighbour fires.
const BONUS := 5

var next_bonus := 0  # what the next landed tick adds, armed by a neighbour's firing


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	# A neighbour is an own part within ctx.range_of(part), which is what _neighbours reads; a forced
	# firing arm the bonus like any other, because the spec counts it as firing for triggers.
	var source: Object = event.source
	if source is ChPartRuntime and _neighbours(ctx).has(source):
		next_bonus = BONUS


func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage + next_bonus)
	next_bonus = 0
	return true
