extends ChBehaviour

# The Chain Detonator (R20): an explosion near the enemy spawns a 4x4 TNT crate on the surface at its
# x, at most once a second. The crate is spawned, so it is the player's: its own blast is theirs too.
const CRATE_CELLS := 16  # a 4x4 crate
const NEAR := 30.0  # cells from the enemy hull's centre
const PERIOD := 1.0  # seconds between crates

var _next := 0.0  # ctx.time the next crate is allowed

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.EXPLOSION, func(event: ChEvent): _blast(ctx, event))

func _blast(ctx: ChBattleContext, event: ChEvent) -> void:
	var foe := ctx.enemy_of(part)
	if foe == null or ctx.time < _next or ctx.world == null:
		return
	if event.position.distance_to(foe.chassis.global_position) > NEAR:
		return
	_next = ctx.time + PERIOD
	ctx.spawn(part, &"tnt", Vector2(_surface(ctx.world, roundi(event.position.x))), CRATE_CELLS)

func _surface(world: PixelWorld, x: int) -> Vector2i:
	# The first non-air cell from the arena's top down this column: the crate lands on it, and spawn's
	# spiral fills the air above.
	var arena := world.arena
	for y in range(arena.position.y, arena.end.y):
		if world.get_material_at(Vector2i(x, y)) != &"air":
			return Vector2i(x, y)
	return Vector2i(x, arena.end.y - 1)
