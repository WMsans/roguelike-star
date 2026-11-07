extends ChBehaviour

# The Ember Battery (spec §5.4): when anything catches fire - either chariot - its own chariot gains
# 3 energy, clamped to the pool's cap, and says so. setup is where a behaviour subscribes, and the
# subscription carries no proximity, which is the whole "anything" in the rule. ChPartRuntime's own
# CAUGHT_FIRE transition is what usually makes the event; a battery never stops a fire, it spends it.
const BATTERY_COOLDOWN := 0.5  # seconds between gains, the brief's internal cooldown
const GAIN := 3.0

var cooldown_left := 0.0  # seconds until this battery can gain again

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.CAUGHT_FIRE, func(caught: ChEvent): _gain(ctx))

func process(ctx: ChBattleContext, delta: float) -> void:
	# The gate is a countdown against the same delta the fight hands every part, cooldown and pool.
	# shortcut: only a spent battery counts down, so an idle one costs nothing per tick.
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)

# The gain: the battery's own chariot's pool, clamped where it lands, then the announcement. ChEnergy
# owns no add method, so value and cap are its own vars and the clamp is the whole rule here.
func _gain(ctx: ChBattleContext) -> void:
	# A battery still cooling down spends nothing, which is the brief's internal cooldown.
	if cooldown_left > 0.0:
		return
	var chariot: ChChariotRuntime = ctx.own(part)
	if chariot == null:
		return
	cooldown_left = BATTERY_COOLDOWN
	var before := chariot.energy.value
	chariot.energy.value = minf(chariot.energy.value + GAIN, chariot.energy.cap)
	var event := ChEvent.new()
	event.type = ChEvent.ENERGY_GAINED
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	# What actually landed, after the cap: a battery firing into a full pool gained nothing, and the
	# balance runner sums this to price the battery.
	event.data = {"amount": chariot.energy.value - before}
	ctx.bus.emit(event)
