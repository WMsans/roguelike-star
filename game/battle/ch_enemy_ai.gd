class_name ChEnemyAI extends RefCounted

# The enemy's drive decision (spec 5.9): drive toward the player until in weapon range, then hold.
# This only answers -1/0/1; ChBattleContext.tick pays it through ChEnergy exactly as it pays the
# player's own input, which is what makes the enemy "pay the same energy rules".

# The range the driver closes comes from reach(): ChPartDef has no reach field, so a weapon's
# proximity_range doubles as its reach in cells — ChBehaviour._reach_box measures exactly that (the
# Mace's 6, the Chainsaw's 14, the Ring of Fire's 24) — so the driver reads the same number the
# swing uses. The Corsair Harpoon owns no proximity_range: its behaviour raycasts its own 120-cell
# line, so the range is named here and, per the brief, counted only while that part can really fire.
# shortcut: HARPOON_RANGE repeats ch_harpoon.gd's own const because a script's private const is not
# readable from outside; upgrade to a reach field on ChPartDef once these two need to agree again.
# A weapon whose reach is the flight of a shot (Rocket, Firebolt, Flamethrower, Hearth) owns no
# range at all: driving does not shorten a shot, so it never pulls the driver in.
const HARPOON_RANGE := 120.0  # cells; matches ch_harpoon.gd's RANGE
const HARPOON_ID := &"corsair_harpoon"  # one part type, the builder's WHEEL_ID rule being the twin

static func reach(chariot: ChChariotRuntime) -> float:
	# The shortest reach the chariot can bring to bear; INF when it carries no weapon that has one,
	# which leaves decide holding still rather than charging in.
	var best := INF
	for part in chariot.parts:
		var def: ChPartDef = part.def
		if def == null or def.damage <= 0 or def.cooldown <= 0.0 or part.broken:
			# Nothing to pay, or a passive (cooldown 0: Freeze Charge, Ember Battery): a passive
			# holds no weapon, so it brings nothing to bear. A broken part is out of the fight.
			continue
		if def.id == HARPOON_ID:
			if _can_fire(part):
				best = minf(best, HARPOON_RANGE)
		elif def.proximity_range > 0.0:
			best = minf(best, def.proximity_range)
	return best

static func _can_fire(part: ChPartRuntime) -> bool:
	# The fight's own readiness, the same three conditions ChBattleContext.tick gates a fire on:
	# a still-counting cooldown, a part out of charges (ChPartRuntime parks cooldown_left at INF
	# when it runs out, which also holds here) and a frozen part, whose countdown is paused.
	return part.cooldown_left <= 0.0 and part.charges_left != 0 and not part.is_frozen()

const KITE_BACKOFF := 8.0  # cells; width of the kiter's rest band below its hold. Proposed.

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
	# pushing on contact. Kiter holds a band [hold - KITE_BACKOFF, hold]: it backs off from inside
	# it, closes from outside it, and rests between (so it does not jitter on the edge). An INF
	# range gives INF for hold, so a kiter with no reach holds still.
	if style == &"brawler":
		return signf(dx)
	if style == &"kiter":
		if absf(dx) < hold - KITE_BACKOFF:
			return -signf(dx)
		return signf(dx) if absf(dx) > hold else 0.0
	if absf(dx) <= hold:
		return 0.0
	return -1.0 if dx < 0.0 else 1.0

# The enemy's finger. The share of the ready volley's cost the pool must hold before the enemy
# spends it on a target in reach: below it a press would fire only the cheap part of the volley
# (try_pay skips what it cannot afford), above it the wait costs more than the shots it saves.
const PRESS_SHARE := 0.6

static func should_press(chariot: ChChariotRuntime, target_x: float, own_half: float,
		target_half: float) -> bool:
	# Press when a ready part has the target in reach and the pool holds PRESS_SHARE of the ready
	# volley's cost, or when the pool is at cap (regen is wasted above it, so waiting buys nothing).
	# A press with nothing ready is a dud, so no ready part never presses, whatever the pool holds.
	# Distances are measured from the part's own position, so a rig needs no chassis to be asked
	# (the same fake bodies test_part_runtime.gd uses). A part's reach is measured from its own edge,
	# so measuring from the part already covers the attacker's half-width: own_half is part of the
	# signature (it mirrors decide) but is deliberately unused, or it would be counted twice. The
	# target's half stays, since its hull edge is what the swing has to touch.
	var cost := 0
	var in_reach := false
	for part in chariot.parts:
		if not part.is_ready():
			continue
		cost += part.def.energy_cost
		var range_cells := HARPOON_RANGE if part.def.id == HARPOON_ID else part.def.proximity_range
		var dx := target_x - part.anchor_world().x
		if range_cells > 0.0:
			in_reach = in_reach or absf(dx) <= range_cells + target_half
		else:
			# A ranged part's shot flies where its slot faces, so facing the target is its reach.
			in_reach = in_reach or signf(part.facing().x) == signf(dx)
	if cost == 0:
		return false
	var pool := chariot.energy
	return pool.value >= pool.cap or (in_reach and pool.value >= PRESS_SHARE * cost)
