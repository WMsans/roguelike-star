extends ChBehaviour

# The Berserker Chip (U80): your weapons deal +1 damage a hit for every 2% of HP missing, so at
# empty they add 50.
const BONUS_AT_EMPTY := 50

func links(_ctx: ChBattleContext, a: Object, b: Object) -> bool:
	# The row's Rng is "—", so the chip is chariot-wide: it counts as linked to every own weapon,
	# which is what lets deal_hit ask it for that weapon's hits. Only when it is the pair's own first
	# part, so it claims no link between any other two.
	return a == part and b is ChPartRuntime and b.def != null and b.side == part.side \
			and b.def.tags.has("weapon")

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	var source: ChPartRuntime = hit.get("source")
	if source == null or source.def == null or source.side != part.side \
			or not source.def.tags.has("weapon"):
		return
	var chariot := ctx.own(part)
	if chariot == null or chariot.max_hp <= 0:
		return
	var missing := chariot.max_hp - chariot.hp
	hit["bonus"] = int(hit["bonus"]) + floori(missing * BONUS_AT_EMPTY / float(chariot.max_hp))
