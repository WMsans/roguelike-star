extends ChBehaviour

# The Freeze Charge (spec §5.4): passive, it adds freeze to a hit dealt by a same-side part inside
# its own reach. ChBattleContext.deal_hit already asks every same-side behaviour whose proximity_range
# covers the source, so the range is the def's (24 cells) and nothing here measures. The context puts
# hit["freeze"] on hit["freeze_part"] (the part hit, or for a hull hit the part nearest the attacker),
# so one hit fills ChPartRuntime's meter and freezes it.
const FREEZE_PER_HIT := 1.0

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	hit["freeze"] = hit["freeze"] + FREEZE_PER_HIT
