extends ChBehaviour

# The Flamethrower (C16): a short beam, 4 damage a second, that sprays fire cells along what it
# reaches. The cells are the burn: the status second turns them into Flame, so the beam's own damage
# and the sim's fire are two separate things.
const CELLS := 6  # fire cells a second, spread over the frames
const NOZZLE := 5.0  # cells out from the anchor the flame leaves the barrel

var spray_left := 0.0  # fire cells still owed this second
var jet: ChFx = null  # the looping flame at the nozzle, held so a break can take it off the wreck

func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _beam_target(ctx)
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage)
	return true

func process(ctx: ChBattleContext, delta: float) -> void:
	if not part.running:
		if jet != null and is_instance_valid(jet):
			jet.fade_out()
			jet = null
		return
	if jet == null or not is_instance_valid(jet):
		jet = ChFx.spawn(ctx.world, &"flamethrower",
			part.anchor_world() + part.facing() * NOZZLE, part.facing())
	spray_left += CELLS * delta
	while spray_left >= 1.0:
		spray_left -= 1.0
		ctx.spawn(part, &"fire", _spray_at(ctx), 1)

func _spray_at(ctx: ChBattleContext) -> Vector2:
	# Where the beam lands: the body it reaches, or the middle of the reach box when it reaches none.
	var target := _beam_target(ctx)
	var holder: Object = ctx.part_of_body(target) if target != null else null
	if holder == null and target != null:
		holder = ctx.chariot_of_body(target)
	var at: Vector2 = holder.anchor_world() if holder != null else _spray_box(ctx).get_center()
	return at + Vector2(ctx.bus.rng.randf_range(-1.0, 1.0), ctx.bus.rng.randf_range(-1.0, 1.0))

func teardown() -> void:
	if jet != null and is_instance_valid(jet):
		jet.queue_free()
	jet = null
