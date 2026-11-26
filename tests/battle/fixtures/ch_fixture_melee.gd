extends ChBehaviour

# Test fixture for the held button's continuous step: a melee weapon that swings once a second while
# its part runs. The timer is ChBattleContext's; this only answers whether the swing landed, which is
# ChBehaviour._strike into the reach box. Loaded by path (tests/battle/test_continuous.gd), so it
# carries no class_name.

func continuous_tick(ctx: ChBattleContext) -> bool:
	return _strike(ctx)
