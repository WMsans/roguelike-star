extends ChBehaviour

# The Fan (C30): a beam that never hits. While it runs it blows the gases in its reach box forward
# along facing(), so its only PART_FIRED is the moment it switches on (the loop's beam rule).
const BLOW := 2  # cells a frame the gas moves

func continuous_tick(ctx: ChBattleContext) -> bool:
	return false

func process(ctx: ChBattleContext, delta: float) -> void:
	if not part.running:
		return
	ctx.blow(Rect2i(_spray_box(ctx)), Vector2i(part.facing() * BLOW))
