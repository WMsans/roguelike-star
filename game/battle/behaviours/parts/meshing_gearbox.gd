extends ChBehaviour

# The Meshing Gearbox (R15): a melee neighbour that fires makes every other melee neighbour fire too.
# The forced fire is free and leaves the weapon's own clock alone (ChBattleContext.force_fire), and a
# forced firing is skipped here, so the chain a gearbox starts cannot feed itself.
# Each weapon is forced at most once per ctx.time value, which force_fire's "once" keeps for the whole
# fight, so two neighbours firing in the same tick do not fire the third twice, and neither do two
# gearboxes in range of it.


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or bool(event.data.get("forced", false)):
		return
	if not _neighbours(ctx, "melee").has(source):
		return
	for other in _neighbours(ctx, "melee"):
		if other == source:
			continue
		ctx.force_fire(other, part, true)
