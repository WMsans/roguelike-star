extends ChBehaviour

# The Matter Eater (R11): a beam out to the def's reach (60 cells) that pays 8 a second, drips one
# acid cell on its target, and while running dissolves the terrain in its path twice a second.
const CELLS := 1  # acid cells a tick drips on the target
const DIG_RADIUS := 2  # cells: a disc as thick as the beam either side of its centre line
const DIG_HARDNESS := 8  # everything softer than concrete
const DIG_SECONDS := 0.5

var dig_left := 0.0  # seconds until the beam digs again

func continuous_tick(ctx: ChBattleContext) -> bool:
	var target := _beam_target(ctx)
	if target == null:
		return false
	ctx.deal_hit(part, target, part.def.damage)
	ctx.spawn(part, &"acid", _beam_point(ctx, target), CELLS)
	return true

func process(ctx: ChBattleContext, delta: float) -> void:
	# Like the Drill, the dig is on the part's own clock: a beam with no target still burns through
	# the terrain in front of it while the button is held.
	if not part.running:
		return
	dig_left -= delta
	if dig_left > 0.0:
		return
	dig_left += DIG_SECONDS
	if ctx.world == null:
		return
	_dig_beam(ctx)

func _beam_point(ctx: ChBattleContext, target: Object) -> Vector2:
	# Where the beam lands: the body it reaches, as its part or its hull.
	var holder: Object = ctx.part_of_body(target)
	if holder == null:
		holder = ctx.chariot_of_body(target)
	return holder.anchor_world() if holder != null else _spray_box(ctx).get_center()

func _dig_beam(ctx: ChBattleContext) -> void:
	# The reach box is centred on the part, so the tunnel is the half ahead of its nose: a disc as
	# thick as the beam, walked out to def.reach in DIG_RADIUS steps.
	var dir := part.facing()
	var nose := _nose(dir)
	for step in range(ceili(part.def.reach / DIG_RADIUS)):
		ctx.dig(Vector2i((nose + dir * (step * DIG_RADIUS)).round()), DIG_RADIUS, DIG_HARDNESS)
