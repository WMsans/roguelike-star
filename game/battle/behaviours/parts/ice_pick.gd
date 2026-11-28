extends ChBehaviour

# The Ice Pick (C21): a cooldown stab out to the def's reach (24 cells) that pays 20, or 40 when the
# holder it strikes - the part hit, or the hull's body - is frozen.
const FROZEN_DAMAGE := 40

func fire(ctx: ChBattleContext) -> void:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target == null:
		return
	ctx.deal_hit(part, target, _damage(ctx, target))

func _damage(ctx: ChBattleContext, target: Object) -> int:
	# The holder is the part hit, or the chariot body for a hull hit: deal_hit resolves the same split.
	var holder: Object = ctx.part_of_body(target)
	if holder == null:
		holder = ctx.chariot_of_body(target)
	if holder != null and holder.statuses.count(ChStatuses.FREEZE) > 0:
		return FROZEN_DAMAGE
	return part.def.damage
