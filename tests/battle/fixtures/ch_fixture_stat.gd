extends ChBehaviour

# Test double for ChBehaviour.modify_stat (Task 2). `mode` is one of "add" (+1), "double" (×2)
# or "double_cooldown" (×2 the cooldown stat only). Loaded by path from test_stats_scopes.gd, so it
# carries no class_name; each test builds its own instance and wires part itself.

var mode: StringName = &"add"

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	if mode == &"add":
		return value + 1.0
	if mode == &"double":
		return value * 2.0
	if mode == &"double_cooldown" and stat == ChBattleContext.STAT_COOLDOWN:
		return value * 2.0
	return value
