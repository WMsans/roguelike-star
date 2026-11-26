class_name ChFightRules extends RefCounted

# Task 8: one fight's modifier (spec's "Elite and boss modifiers"). ChRun draws a modifier for each
# elite and for the boss, `of` turns that draw into the numbers the fight runs on, and ChBattle hands
# the result to its context and its bus: a multiplier in the hit path and the burn tick, a shorter tick
# budget, and a share of the event deliveries.
# These are handicaps on the player, so each one reaches the player's side only: fire-tagged hits from
# side 0 and the enemy's burn ticks, and deliveries to the player's own listeners.
# The plain `new()` is the do-nothing rule (fire x1, the whole tick budget, every delivery through),
# which is what every fight without a modifier runs on — that is what keeps a normal fight identical to
# a fight before modifiers existed.

var modifier: StringName = &""  # the draw this rule came from; &"" for a fight that has none
var fire_mult := 1.0  # what the player's fire-tagged hits and the enemy's burn ticks are worth
var tick_limit := ChBattle.FIGHT_TICKS  # the ticks this fight may run
var chain_pass := 1.0  # the share of the deliveries to the player's listeners that go through


static func of(modifier: StringName, boss: bool) -> ChFightRules:
	# The spec's table: the elite's number, and the boss's stronger one. An empty (or unknown) draw is
	# the plain rule, so a normal fight changes nothing.
	var rules := ChFightRules.new()
	rules.modifier = modifier
	match modifier:
		&"fire_halved":
			rules.fire_mult = 0.25 if boss else 0.5
		&"time_limit":
			rules.tick_limit = (30 if boss else 40) * 60
		&"chains_weak":
			rules.chain_pass = 0.25 if boss else 0.5
	return rules


func banner_text() -> String:
	# The fight's own words for its modifier, shown once at the start. Empty for a fight that has none,
	# which is what keeps the banner off every normal fight. The time limit reads its seconds back off
	# tick_limit, so the banner cannot drift from the budget the fight actually runs on.
	match modifier:
		&"fire_halved":
			return "Fire damage halved"
		&"time_limit":
			return "Kill it in %d s" % (tick_limit / 60)
		&"chains_weak":
			return "Chains weakened"
	return ""
