extends ChBehaviour

# The Booster Rocket (U74): the press launches its own chariot the way its slot faces. The enemy is
# mirrored by flipped slots and negated anchors, never by its chassis rotation (0 on both sides), so
# the part's own facing is what "forward" means, and a deliberately flipped booster follows its slot.

const LAUNCH := 900.0  # impulse along the part's facing


func fire(ctx: ChBattleContext) -> void:
	ctx.push(ctx.own(part), part.facing() * LAUNCH)
