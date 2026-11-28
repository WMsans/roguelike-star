extends ChBehaviour

# The Guardian Core (R36): a hit on a neighbour is taken by this part instead, and the part gains
# Block equal to half the damage it took. The Block is read off its own HIT, so it cannot soak the
# hit it came from.
func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.HIT, func(event: ChEvent): _hit(ctx, event))

func modify_incoming(ctx: ChBattleContext, hit: Dictionary) -> void:
	var target: Object = hit.get("target_part")
	if target != null and target != part and _neighbours(ctx).has(target):
		hit["target_part"] = part

func _hit(ctx: ChBattleContext, event: ChEvent) -> void:
	if event.data.get("target_part") != part:
		return
	ctx.give_status(part, ChStatuses.BLOCK, int(event.data["hp_damage"]) / 2)
