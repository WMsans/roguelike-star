extends ChBehaviour

# The Dynamo Wheel (U61): a wheel, so driving pays for it, and while driving it generates 2 energy a
# second of its own - a net +1 over its own 1/s wheel cost, which is the part's whole point.
const GAIN := 2.0

func process(ctx: ChBattleContext, delta: float) -> void:
	var own := ctx.own(part)
	if own == null or not own.driving:
		return
	ctx.gain_energy(own, GAIN * delta)
