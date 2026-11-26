extends ChBehaviour

# The Ice Cream Mace (spec §5.4): a melee swing out to the def's reach and the Shatter, which pays
# ChDamage's x3 to a frozen target and ends that freeze. The weapon's numbers live here: ChPartDef.reach
# (6 cells for a mace) is its reach, and ChBehaviour._reach_box measures it, because the engine's
# per-body hit signal only fires on contact begin and cannot give a reach. The box the swing measures
# and the body it hits are ChBehaviour's, shared with every melee part.
func fire(ctx: ChBattleContext) -> void:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target != null:
		# The thud lands at the far edge of the reach box, where the swing meets the target.
		var box := _reach_box()
		ChFx.spawn(ctx.world, &"blunt_hit", box.get_center() + box.size * 0.5 * part.facing(), part.facing())
		# deal_hit is the fight's one damage entry point: it asks the passives near the source, then this
		# behaviour's modify_hit, then applies ChDamage.
		ctx.deal_hit(part, target, part.def.damage)

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	# deal_hit asks every same-side behaviour whose proximity_range covers the source, so a mace mounted
	# near another weapon hears that weapon's hit as well as its own: the Shatter is the swinger's own.
	if hit["source"] != part:
		return
	# freeze_part is the part hit, or for a hull hit the part nearest the swing (ChBattleContext).
	var target: ChPartRuntime = hit["freeze_part"]
	if target == null or not target.is_frozen():
		return
	hit["multiplier"] = hit["multiplier"] * ChDamage.shatter_multiplier(true)
	# ChBattleContext gives a pass's hit["freeze"] after the modifiers ran, so the Shatter asks for its
	# thaw through the hit rather than clearing Freeze here: a Freeze Charge landing on the same hit
	# still leaves the target thawed (spec §5.6's "ends its freeze"). deal_hit announces the thaw.
	hit["thaw"] = true
