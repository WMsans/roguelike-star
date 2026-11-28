extends ChBehaviour

# The Turret Mount (U86): the weapon bolted onto it fires both ways. The mount's own half of that is
# the damage: every hit from its child is halved. The other half is the firing: when the child fires
# on its own, the mount fires it once more with facing() reversed, which is free and leaves the
# child's own clock alone (ChBattleContext.force_fire). A forced firing is skipped here, so the
# mount cannot force itself through the firing it caused.
const HALF := 0.5


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


# The row's Rng is "—", so nothing is within its range: the link is the mount tree, which is what
# makes deal_hit ask the mount about its child's hits.
func links(_ctx: ChBattleContext, a: Object, b: Object) -> bool:
	return a == part and b is ChPartRuntime and b.parent == part


func modify_hit(_ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source != null and source.parent == part:
		hit["multiplier"] = float(hit["multiplier"]) * HALF


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var child: ChPartRuntime = event.source
	if child == null or child.parent != part or bool(event.data.get("forced", false)):
		return
	child.reversed = true
	ctx.force_fire(child, part)
	child.reversed = false
