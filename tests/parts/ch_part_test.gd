class_name ChPartTest extends ChTest

# Task 1: the harness every part test extends (Tasks 5-24).
# RIG := &"rig": a test body, 60x8 cells. Eight top slots in a row 6 cells apart (x = -21 .. 21,
# y = -4) and two wheel slots on the bottom edge (x = +/-20, y = 4). Slot indices 0-7 are the top
# slots, 8-9 the wheels. 800 HP, energy 20, regen 4.
# The two wheel slots always carry the common wheel (Task 5's Roller), so the chariot can drive.

const RIG := &"rig"
const WHEEL_ID := &"roller"  # Task 5: the Roller, the common wheel (the old `wheel` before it)
const GROUND_TOP := 160
const TICK := 1.0 / 60.0

func _rig_body() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = RIG
	def.hp = 800
	def.energy_cap = 20
	def.energy_regen = 4.0
	def.size = Vector2i(60, 8)
	var slots := PackedVector2Array()
	for x in range(-21, 22, 6):
		slots.append(Vector2(x, -4))
	slots.append(Vector2(-20, 4))
	slots.append(Vector2(20, 4))
	def.slots = slots
	return def

func _catalog_with_rig() -> ChCatalog:
	var catalog := ChCatalog.load_default()
	catalog.bodies[RIG] = _rig_body()
	return catalog

func _build_rig(world: PixelWorld, catalog: ChCatalog, mounts: Array, origin: Vector2, side: int,
	mirrored: bool) -> ChChariotRuntime:
	var layout := ChChariotLayout.new()
	layout.body_id = RIG
	# The two wheel slots always carry a wheel, so the chariot can drive.
	layout.place([8], WHEEL_ID)
	layout.place([9], WHEEL_ID)
	for mount in mounts:
		# place() takes a typed Array[int], and a mount literal is untyped, so the path is copied into one.
		var path: Array[int] = []
		for step in mount[0]:
			path.append(step)
		var id: StringName = mount[1]
		var flipped: bool = mount.size() > 2 and mount[2]
		assert_true(layout.place(path, id), "%s mounts %s" % [path, id])
		if flipped:
			layout.toggle_flip(path)
	var build_layout := layout
	var build_origin := origin
	if mirrored:
		build_layout = layout.mirrored()
	var runtime := ChChariotBuilder.build(world, _parent(), build_layout, catalog, side, build_origin, mirrored)
	assert_true(runtime != null, "the chariot builds")
	return runtime

# Builds two mirrored RIG chariots (side 0 at x 160, side 1 `gap` cells further right) over a rock
# floor, mounts every entry, calls each behaviour's setup and returns the battle context.
func duel(mine: Array, theirs: Array = [], gap := 40.0) -> ChBattleContext:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock")
	var catalog := _catalog_with_rig()
	var player := _build_rig(world, catalog, mine, Vector2(160, 140), 0, false)
	var enemy := _build_rig(world, catalog, theirs, Vector2(160 + gap, 140), 1, true)
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = [player, enemy]
	for rig in ctx.chariots:
		for part in rig.parts:
			if part.behaviour != null:
				part.behaviour.setup(ctx)
	return ctx

# Ticks at 1/60 for `seconds`, driving and pressing only side 0. With `frames` true it awaits one
# process_frame per tick, for projectiles and the sim.
func step(ctx: ChBattleContext, seconds: float, press := false, hold := false, drive := 0.0,
		frames := false) -> void:
	var ticks := ceilf(seconds * 60.0)
	for _tick in range(ticks):
		ctx.tick(TICK, [drive, 0.0], [press, false], [hold, false])
		if frames:
			await Engine.get_main_loop().process_frame

func of(ctx: ChBattleContext, side: int, id: StringName) -> ChPartRuntime:
	for part in ctx.chariots[side].parts:
		if part.def != null and part.def.id == id:
			return part
	return null

# Collects every event of a type emitted during the fight the returned array is filled into.
func sink(ctx: ChBattleContext, type: StringName) -> Array:
	var out: Array = []
	var sink := out
	var listener := RefCounted.new()
	ctx.bus.subscribe(listener, type, func(event: ChEvent): sink.append(event))
	return out
