extends ChBehaviour

# The Ice Cream Mace (spec §5.4): a melee swing out to the def's reach and the Shatter, which pays
# ChDamage's x3 to a frozen target and ends that freeze. The weapon's numbers live here: ChPartDef
# has no reach field, so proximity_range (6 cells for a mace) is its reach, because the engine's
# per-body hit signal only fires on contact begin and cannot give a reach. The box the swing measures
# and the body it hits are ChBehaviour's, shared with every melee part.
func fire(ctx: ChBattleContext) -> void:
	var target := _nearest_enemy_body(ctx, _reach_box())
	if target != null:
		# deal_hit is the fight's one damage entry point: it asks the passives near the source, then this
		# behaviour's modify_hit, then applies ChDamage.
		ctx.deal_hit(part, target, part.def.damage)

func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	# deal_hit asks every same-side behaviour whose proximity_range covers the source, so a mace mounted
	# near another weapon hears that weapon's hit as well as its own: the Shatter is the swinger's own.
	if hit["source"] != part:
		return
	var target: ChPartRuntime = hit["target_part"]
	if target == null or not target.is_frozen():
		return
	hit["multiplier"] = hit["multiplier"] * ChDamage.shatter_multiplier(true)
	# ChBattleContext adds a pass's hit["freeze"] after the modifiers ran, so the Shatter asks for its
	# freeze reset through the hit rather than writing the meter here: a Freeze Charge landing on the
	# same hit still leaves the target thawed, at 0 rather than 0.5 (spec §5.6's "ends its freeze").
	# shortcut: thaw is all-freeze, so it drops whatever build-up the passives added as well as the part's
	# own; a hit that should keep part of that build-up wants a different key.
	hit["thaw"] = true
	# The Shatter ends the freeze it read, so THAWED names the target as its source, as ChPartRuntime's
	# own THAWED emission has it.
	var event := ChEvent.new()
	event.type = ChEvent.THAWED
	event.side = target.side
	event.source = target
	event.position = target.anchor_world()
	ctx.bus.emit(event)
