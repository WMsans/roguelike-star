extends ChBehaviour

# Test double for ChBehaviour.modify_stat / modify_gain (Tasks 2-3). `mode` is one of "add" (+1),
# "double" (×2), "double_cooldown" (×2 the cooldown stat only), "double_decay_freeze" (×2 the
# decay_freeze stat only) or "zero_gain" (a gain of nothing). Loaded by path from
# test_stats_scopes.gd and test_hp_energy.gd, so it carries no class_name; each test builds its own
# instance and wires part itself.

var mode: StringName = &"add"

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if mode == &"add":
		return value + 1.0
	if mode == &"double":
		return value * 2.0
	if mode == &"double_cooldown" and stat == ChBattleContext.STAT_COOLDOWN:
		return value * 2.0
	if mode == &"double_decay_freeze" and stat == ChBattleContext.STAT_DECAY_FREEZE:
		return value * 2.0
	return value

func modify_gain(ctx: ChBattleContext, target: Object, status: StringName, amount: int,
		cause: StringName) -> int:
	if mode == &"zero_gain":
		return 0
	return amount
