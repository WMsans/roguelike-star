extends ChBehaviour

# The Spiked Wheel (U76): while its chariot drives, a one-second clock swings it as a melee weapon.
# The reach and the damage are the def's (4 cells, 8), so _strike is the whole hit and a landed tick
# counts as a melee firing.

const PERIOD := 1.0  # seconds of driving per tick

var _clock := 0.0  # seconds of driving since the last tick


func process(ctx: ChBattleContext, delta: float) -> void:
	var own := ctx.own(part)
	if own == null or not own.driving:
		return
	_clock += delta * part.tick_rate()
	if _clock < PERIOD:
		return
	_clock = 0.0
	if _strike(ctx):
		ctx._emit_fired(part)
