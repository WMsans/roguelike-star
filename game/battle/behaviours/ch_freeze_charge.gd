extends ChBehaviour

# The Freeze Charge (spec §5.4): passive, it adds freeze to a hit dealt by a same-side part inside
# its own reach. ChBattleContext.deal_hit already asks every same-side behaviour whose proximity_range
# covers the source, so the range is the def's (24 cells) and nothing here measures. The context puts
# hit["freeze"] on the part hit, so two hits of 0.5 fill ChPartRuntime's meter and freeze it.
const FREEZE_PER_HIT := 0.5

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	hit["freeze"] = hit["freeze"] + FREEZE_PER_HIT
