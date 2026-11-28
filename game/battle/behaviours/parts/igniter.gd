extends ChBehaviour

# The Igniter (C18): a small patch of fire 8 cells ahead, and a neighbour's fire cells are doubled.
const CELLS := 8  # fire cells in the patch
const AHEAD := 8.0  # cells in front of the part the patch starts at

func fire(ctx: ChBattleContext) -> void:
	ctx.spawn(part, &"fire", part.anchor_world() + part.facing() * AHEAD, CELLS)

func modify_stat(ctx: ChBattleContext, target: Object, stat: StringName, value: float) -> float:
	# ctx.spawn asks spawn_<material> of the part that spawned, so a neighbour's fire is the target.
	if stat == &"spawn_fire" and target is ChPartRuntime and target != part \
			and _neighbours(ctx).has(target):
		return value * 2.0
	return value
