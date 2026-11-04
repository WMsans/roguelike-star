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

static func decide(self_x: float, target_x: float, preferred_range: float) -> float:
	# Chassis to chassis, in cells: -1 drives left, 1 drives right, 0 holds. ChBattleContext.tick
	# pays whichever of the three ChEnergy can afford, so an unaffordable drive is simply ignored.
	var dx := target_x - self_x
	if absf(dx) <= preferred_range:
		return 0.0
	return -1.0 if dx < 0.0 else 1.0
