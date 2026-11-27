class_name ChEnemyAI extends RefCounted

# The enemy's drive decision (spec 5.9): drive toward the player until in weapon range, then hold.
# This only answers -1/0/1; ChBattleContext.tick pays it through ChEnergy exactly as it pays the
# player's own input, which is what makes the enemy "pay the same energy rules".

# The range the driver closes comes from reach(): ChPartDef.reach is a weapon's reach in cells,
# measured from the part's own edge along its facing, which is exactly what ChBehaviour._reach_box
# measures. proximity_range is the proximity-chain range and never a weapon's reach.

static func reach(chariot: ChChariotRuntime) -> float:
	# The shortest reach the chariot can bring to bear; INF when it carries no weapon that has one,
	# which leaves decide holding still rather than charging in. A broken part is out of the fight, a
	# passive (mode passive or wheel) brings nothing to bear, and a cooldown part with no charges
	# left cannot fire.
	var best := INF
	for part in chariot.parts:
		var def: ChPartDef = part.def
		if def == null or part.broken or def.damage <= 0 or def.reach <= 0.0:
			continue
		if def.mode != ChPartDef.MODE_COOLDOWN and def.mode != ChPartDef.MODE_MELEE \
				and def.mode != ChPartDef.MODE_BEAM:
			continue
		if def.mode == ChPartDef.MODE_COOLDOWN and part.charges_left == 0:
			continue
		best = minf(best, def.reach)
	return best

# cells; how far the kiter's rest band reaches below its hold, and how far outside hull contact its
# back-off edge has to stay. The band is [max(hold - KITE_BACKOFF, contact + KITE_MARGIN), hold],
# contact being own half + target half. With a ranged reach the 20-cell width is what matters: at 8
# the Tower's momentum carried it through the band and it reversed at full speed, which tipped it
# (README "Body tuning log"). With a melee reach (the Chainsaw's 14) hold - 20 lands inside contact,
# so without the margin a kiter could never back off at all.
const KITE_BACKOFF := 20.0
const KITE_MARGIN := 4.0

static func decide(self_x: float, target_x: float, preferred_range: float,
		own_half_width: float = 0.0, target_half_width: float = 0.0,
		style: StringName = &"") -> float:
	# Chassis-centre to chassis-centre, in cells: -1 drives left, 1 drives right, 0 holds.
	# ChBattleContext.tick pays whichever of the three ChEnergy can afford, so an unaffordable drive
	# is simply ignored.
	# A weapon's reach is measured from the part's own edge and a part mounts on the hull's edge, so the
	# reach alone does not say how far the HULLS have to stay apart: holding at the Mace's 6 cells
	# parks a 30-cell-wide Dozer on top of a 30-cell Cutter, and every body is CAT_BODY against
	# CAT_BODY with no per-body filter (physics.cpp:24-33), so the two hulls grind into each other
	# instead of fighting. Both half-widths are what "clear of each other" means for these hulls, so
	# the driver holds at reach + own half + target half: the swing still lands, the hulls do not touch.
	# An unreachable target (preferred_range INF) stays INF under the sum, so it still holds.
	var hold := preferred_range + own_half_width + target_half_width
	var dx := target_x - self_x
	# A body's drive style (ChBodyDef.drive_style) overrides the hold-off so shape can matter:
	# hulls have to meet for a body's silhouette to count. Brawler never holds off: it keeps
	# pushing on contact. Kiter holds the band KITE_BACKOFF describes: it backs off from inside
	# it, closes from outside it, and rests between (so it does not jitter on the edge). An INF
	# range gives INF for hold, so a kiter with no reach holds still.
	if style == &"brawler":
		return signf(dx)
	if style == &"kiter":
		if is_inf(hold):
			return 0.0  # INF - KITE_BACKOFF is still INF, which would read as "too close" forever
		if absf(dx) < maxf(hold - KITE_BACKOFF, own_half_width + target_half_width + KITE_MARGIN):
			return -signf(dx)
		return signf(dx) if absf(dx) > hold else 0.0
	if absf(dx) <= hold:
		return 0.0
	return -1.0 if dx < 0.0 else 1.0

# The enemy's finger. The share of the ready volley's cost the pool must hold before the enemy
# spends it on a target in reach: below it a press would fire only the cheap part of the volley
# (try_pay skips what it cannot afford), above it the wait costs more than the shots it saves.
const PRESS_SHARE := 0.6

static func should_press(chariot: ChChariotRuntime, target_x: float, target_half: float) -> bool:
	# Press when a ready part has the target in reach and the pool holds PRESS_SHARE of the ready
	# volley's cost, or when the pool is at cap (regen is wasted above it, so waiting buys nothing).
	# A press with nothing ready is a dud, so no ready part never presses, whatever the pool holds.
	# Distances are measured from the part's own position, so a rig needs no chassis to be asked
	# (the same fake bodies test_part_runtime.gd uses). A part's reach is measured from its own edge,
	# so measuring from the part already covers the attacker's half-width; only the target's half is
	# added, since its hull edge is what the swing has to touch.
	var cost := 0
	var in_reach := false
	for part in chariot.parts:
		if not part.is_ready():
			continue
		cost += part.cost
		var range_cells := part.def.reach
		# Measure from the part's edge (anchor + facing x half its length) and count only targets
		# on the facing side, as ChBehaviour._reach_box does.
		var edge := part.anchor_world() + part.facing() * (0.5 * part.def.size.x)
		var along := (target_x - edge.x) * part.facing().x
		if range_cells > 0.0:
			in_reach = in_reach or (along >= 0.0 and along <= range_cells + target_half)
		else:
			in_reach = in_reach or along >= 0.0
	if cost == 0:
		return false
	var pool := chariot.energy
	return pool.value >= pool.cap or (in_reach and pool.value >= PRESS_SHARE * cost)

# The held button's share: a continuous part pays energy_per_second for every frame it runs, so the
# pool has to cover a share of that rate before the enemy holds. Half a second of the running parts'
# rate is enough for the hold to keep paying rather than start and starve.
const HOLD_SHARE := 0.5

static func should_hold(chariot: ChChariotRuntime, target_x: float, target_half: float) -> bool:
	# Hold when a part the button would run has the target in reach and the pool holds HOLD_SHARE of
	# the drain the hold commits to. Reach is measured from the part's own position, as should_press
	# measures it, so the attacker's half-width is already covered. The drain is every can_run() part,
	# reach or no reach, because the continuous step pays them all, dearest first: pricing only the
	# in-reach ones would commit the pool to a hold it cannot afford and starve the in-reach runner.
	var per_second := 0.0
	var in_reach := false
	for part in chariot.parts:
		if not part.can_run():
			continue
		var edge := part.anchor_world() + part.facing() * (0.5 * part.def.size.x)
		var along := (target_x - edge.x) * part.facing().x
		if along >= 0.0 and along <= part.def.reach + target_half:
			in_reach = true
		per_second += part.rate
	return in_reach and chariot.energy.value >= HOLD_SHARE * per_second
