extends ChBehaviour

# The Inferno Core (R01): every enemy part with Flame bursts into fire cells, 2 per Flame, 40 at most.
const PER_FLAME := 2  # fire cells per Flame
const CAP := 40  # fire cells one part can burst into

func fire(ctx: ChBattleContext) -> void:
	for foe in _enemy_parts(ctx):
		var flame := foe.statuses.count(ChStatuses.FLAME)
		if flame <= 0:
			continue
		ctx.spawn(part, &"fire", foe.anchor_world(), mini(CAP, PER_FLAME * flame))
