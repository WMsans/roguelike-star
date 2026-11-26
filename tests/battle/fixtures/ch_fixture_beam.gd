extends ChBehaviour

# Test fixture for the held button's continuous step: a beam that hits once a second while its part
# runs. Like the melee fixture it only answers whether the tick landed (ChBehaviour._strike into the
# reach box); the beam's one PART_FIRED on switch-on is ChBattleContext's rule, not this file's.
# Loaded by path (tests/battle/test_continuous.gd), so it carries no class_name.

func continuous_tick(ctx: ChBattleContext) -> bool:
	return _strike(ctx)
