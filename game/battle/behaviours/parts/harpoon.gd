extends ChBehaviour

# The Harpoon (U77): at the start of the battle it pays 3 and reels both chariots together for 1.5 s.
# The pull is the retired Corsair Harpoon's own reel: one equal and opposite impulse a tick, so the
# gap closes from both sides rather than one hull flying.

const COST := 3  # energy the start-of-battle pull pays
const PULL := 20000.0  # impulse per tick, each hull toward the other
const ATTACH := 1.5  # seconds the line stays attached

var attach_left := 0.0  # seconds of pull left


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.BATTLE_STARTED, func(_event: ChEvent): _start(ctx))


func _start(ctx: ChBattleContext) -> void:
	# The trigger's own entry point, so a modifier on this part's energy_cost is paid here too.
	if ctx.pay_trigger(part, COST):
		attach_left = ATTACH


func process(ctx: ChBattleContext, delta: float) -> void:
	if attach_left <= 0.0:
		return
	attach_left = maxf(0.0, attach_left - delta)
	var own := ctx.own(part)
	var foe := ctx.enemy_of(part)
	if own == null or foe == null:
		return
	if own.chassis == null or not is_instance_valid(own.chassis) \
			or foe.chassis == null or not is_instance_valid(foe.chassis):
		return
	# At the body's own centre, so Box2D reads a pull rather than a twist.
	var haul := own.anchor_world() - foe.anchor_world()
	if haul.length() <= 0.0:
		return
	var dir := haul.normalized()
	foe.chassis.apply_force(dir * PULL, foe.chassis.global_position)
	own.chassis.apply_force(-dir * PULL, own.chassis.global_position)
