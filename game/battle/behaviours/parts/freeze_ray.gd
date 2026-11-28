extends ChBehaviour

# The Freeze Ray (U12): no damage, 4 frost cells a second along what it reaches, and a burst of 20
# water cells the moment it switches on.
const FROST := 4  # frost cells a second in the spray box
const WATER := 20  # water cells the switch-on burst sprays at the target

var _was_running := false  # the part's running last tick, so switching on is one burst

func continuous_tick(ctx: ChBattleContext) -> bool:
	ctx.spawn(part, &"frost", _spray_at(ctx), FROST)
	return true

func process(ctx: ChBattleContext, delta: float) -> void:
	var running := part.running
	if running and not _was_running:
		# Its own running going false -> true: the beam just switched on. The burst lands where the
		# beam lands, so on this one frame the water covers the frost the tick just wrote (a spawn
		# may overwrite a gas, and frost is one); the next second's frost is clear of it.
		var target := _beam_target(ctx)
		if target != null:
			ctx.spawn(part, &"water", _spray_at(ctx), WATER)
	_was_running = running

func _spray_at(ctx: ChBattleContext) -> Vector2:
	# Where the beam lands: the body it reaches, or the middle of the reach box when it reaches none.
	var target := _beam_target(ctx)
	var holder: Object = ctx.part_of_body(target) if target != null else null
	if holder == null and target != null:
		holder = ctx.chariot_of_body(target)
	return holder.anchor_world() if holder != null else _spray_box(ctx).get_center()