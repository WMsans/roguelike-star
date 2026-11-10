class_name ChBalanceDrivers extends RefCounted

# The drive policies a headless fight can give a side. There is no input in a headless run, so
# the player side needs one too. Each is a ChBattle.drivers entry: func(battle, side) -> float.

const POLICIES := ["ai", "hold", "charge", "kite", "brawl"]


static func make(policy: String) -> Callable:
	# CONTRACT: policy is one of POLICIES; ChBalanceScenario rejects anything else before a fight.
	match policy:
		"hold":
			return func(_battle, _side): return 0.0
		"charge":
			return func(battle, side):
				var me: ChChariotRuntime = battle.player if side == 0 else battle.enemy
				var other: ChChariotRuntime = battle.enemy if side == 0 else battle.player
				return charge_toward(me.chassis.global_position.x, other.chassis.global_position.x)
		"kite":
			return func(battle, side): return battle.ai_drive(side, &"kiter")
		"brawl":
			return func(battle, side): return battle.ai_drive(side, &"brawler")
	return func(battle, side): return battle.ai_drive(side)


# The press policies, the other half of a side's input: ChBattle.pressers entries, func(battle, side)
# -> bool. "ai" is the enemy AI's rule, "mash" holds the button every tick, "never" never presses.
const PRESS_POLICIES := ["ai", "mash", "never"]


static func make_press(policy: String) -> Callable:
	# CONTRACT: policy is one of PRESS_POLICIES; ChBalanceScenario rejects anything else before a fight.
	match policy:
		"mash":
			return func(_battle, _side): return true
		"never":
			return func(_battle, _side): return false
	return func(battle, side): return battle.ai_press(side)


static func charge_toward(self_x: float, other_x: float) -> float:
	# Always at the other chariot, never holding off: -1, 0 or 1.
	return signf(other_x - self_x)
