extends ChBehaviour

# The Meshing Gearbox (R15): a melee neighbour that fires makes every other melee neighbour fire too.
# The forced fire is free and leaves the weapon's own clock alone (ChBattleContext.force_fire), and a
# forced firing is skipped here, so the chain a gearbox starts cannot feed itself.
# Each weapon is forced at most once per ctx.time value, so two neighbours firing in the same tick do
# not fire the third twice.
# shortcut: the timestamp lives on this gearbox, so two gearboxes on one chariot can each force a
# weapon once in the same tick; upgrade if a shared per-tick marker appears.
var _forced_at := {}  # weapon -> the ctx.time value this gearbox last forced it at


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent): _fired(ctx, event))


func _fired(ctx: ChBattleContext, event: ChEvent) -> void:
	var source: ChPartRuntime = event.source
	if source == null or bool(event.data.get("forced", false)):
		return
	if not _neighbours(ctx, "melee").has(source):
		return
	for other in _neighbours(ctx, "melee"):
		if other == source or _forced_at.get(other) == ctx.time:
			continue
		_forced_at[other] = ctx.time
		ctx.force_fire(other, part)
