extends ChTest

# The projectile trail: the bolt's own core sprite and the puffs it leaves in the world, which the
# ranged parts fire through ChBehaviour._shoot. The parts themselves are tested in
# tests/parts/test_common_weapons.gd; what is under test here is what a shot leaves behind.
# The rigs sit on ChTest's arena with a rock floor. These fights await engine frames: ChProjectile
# moves on Godot physics frames and the world's Box2D sim ticks on them too, so a synchronous
# ctx.tick loop cannot fly a projectile.
# shortcut: rig numbers are literals per def below; the slice's tuning lives in game/data/parts.

const GROUND_TOP := 160  # first rock row: the bottom 20 rows of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # the player's rig origin (Task 9's spawn ruling)
const TICK := 1.0 / 60.0  # the fight's clock per awaited frame
const PRESS := [true, true]  # both sides press every tick: a part fires the moment it is ready
const SETTLE := 90  # awaited frames that let a rig join the world and fall onto the floor

# The rig body every test's chariot sits on: a 10x10 hull so the settled chassis spans the launch
# line, and three slots, the outer one 8 cells out and 3 below the centre so the flight line runs
# just above the rock floor.
func _rig() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = 100
	def.energy_cap = 20
	def.energy_regen = 0.0
	def.size = Vector2i(10, 10)
	def.slots = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(8, 3)])
	return def

# The ranged def comes off res://game/data/parts, so a build reads the weapon's numbers (cost,
# cooldown, damage) off the .tres and gets the behaviour the .tres names.
func _catalog() -> ChCatalog:
	var loaded := ChCatalog.load_default()
	var defs: Array[ChPartDef] = []
	for id in [&"rocket_pod"]:
		var def: ChPartDef = loaded.part(id)
		assert_true(def != null, "%s loads from res://game/data/parts" % id)
		defs.append(def)
	var catalog := ChCatalog.from_defs(defs, [_rig()])
	for id in [&"rocket_pod"]:
		assert_true(catalog.part(id).behaviour != null, "%s behaviour is as the .tres stand" % id)
	return catalog

# A build from [[path, part_id]] in mount order on the rig body; place() takes Array[int].
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout

func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps

# The part the builder put at a layout path; runtime.parts keeps every part's own path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null

# A battle over both sides, with every mounted behaviour getting the setup call that subscribes it.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = rigs
	for rig in rigs:
		for part in rig.parts:
			if part.behaviour != null:
				part.behaviour.setup(ctx)
	return ctx

# The rock floor the chariots stand on; fill_rect returns the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")

# The awaited-frame loop every projectile test runs: the fight's clock stays in fight seconds
# (TICKS_TO_FIRE of ctx ticks) while the engine's physics frames keep flying the projectile.
const TICKS_TO_FIRE := 250  # 4.17 s of fight clock: the Rocket Pod's 4 s cooldown goes ready, one fire only
const FLIGHT_FRAMES := 400  # awaited frames for the cooldown and the flight, which the fight clock does not bound

# The bolt's trail is emitted, not attached: each physics frame the bolt hands the world's particle
# pool a few pixels carrying a share of its own velocity, and never addresses them again, so the bolt
# outruns its own smoke. The core sprite is the one look that does ride the bolt, because a body is
# its own emitter; without it the bolt the old trail sheet used to draw is invisible.
func _bolt(world: PixelWorld) -> ChProjectile:
	for child in world.get_children():
		if child is ChProjectile:
			return child
	return null

# The world's own baked effects: a trail puff is one of these, the muzzle flash is another.
func _fx(world: PixelWorld) -> Array:
	var found: Array = []
	for child in world.get_children():
		if child is ChFx:
			found.append(child)
	return found

func _puffs(world: PixelWorld) -> Array:
	var found: Array = []
	for node in _fx(world):
		var path: String = node.texture.resource_path
		if path.ends_with("puff_fire.png") or path.ends_with("puff_smoke.png"):
			found.append(node)
	return found

# A settled rig firing its rocket once, handed back with the fight: [ctx, bolt], the bolt null if the
# shot never came out. Four tests need the same launch, and a copy each would be four places to drift.
func _rocket_shot(world: PixelWorld) -> Array:
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"rocket_pod"]]), catalog, 0, ORIGIN, false)
	var rocket := _part_of(at, [2])
	assert_true(rocket != null and rocket.behaviour != null, "the rocket mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var bolt: ChProjectile = null
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		bolt = _bolt(world)
		if bolt != null:
			break
	return [ctx, bolt]

func test_bolt_trail_is_particles_and_the_bolt_stays_visible() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := _catalog()
	var at: ChChariotRuntime = ChChariotBuilder.build(world, _parent(), _mount([[[2], &"rocket_pod"]]), catalog, 0, ORIGIN, false)
	var rocket := _part_of(at, [2])
	assert_true(rocket != null and rocket.behaviour != null, "the rocket mounted and behaves")
	var rigs: Array[ChChariotRuntime] = [at]
	var ctx: ChBattleContext = _battle(world, catalog, rigs)
	for _settle in SETTLE:
		await Engine.get_main_loop().process_frame
	var bolt: ChProjectile = null
	for _frame in FLIGHT_FRAMES:
		await Engine.get_main_loop().process_frame
		if ctx.time < TICKS_TO_FIRE * TICK:
			ctx.tick(TICK, [0.0, 0.0], PRESS)
		bolt = _bolt(world)
		if bolt != null:
			break
	assert_true(bolt != null, "the rocket fired and a bolt is flying")
	# The first pixels go on the bolt's first physics frame, which is the frame after it enters the tree.
	for _frame in 6:
		await Engine.get_main_loop().process_frame
	assert_true(is_instance_valid(bolt), "the bolt is still flying")
	var sprites := 0
	var sheets := 0
	for child in bolt.get_children():
		if child is Sprite2D:
			sprites += 1
		if child is ChFx:
			sheets += 1
	assert_eq(sprites, 1, "the bolt carries one core sprite of its own")
	assert_eq(sheets, 0, "no baked effect rides the bolt")
	assert_true(int(world.get_stats()["particles_visual"]) > 0, "the trail is in the world's particle pool")
	_complete()

# The trail's mass is baked, and baked effects live in the world: the bolt drops one every eight cells it
# flies and the puff is born where the bolt was. Distance rather than time, so the stream is evenly spaced
# whatever the bolt's speed, and the alternation of the two sheets is what makes it read smoke under flame.
const PUFF_EVERY := 8.0  # cells: the cadence both the drop and this test read

func test_bolt_drops_a_puff_every_eight_cells() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	# Flight time is physics time: headless idle frames run faster than the 60 Hz the bolt steps on.
	for _tick in 12:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() >= 2, "the bolt left puffs behind it (%d)" % puffs.size())
	assert_true(puffs[0].texture.resource_path != puffs[1].texture.resource_path, "the stream alternates flame and smoke")
	assert_near(puffs[1].position.distance_to(puffs[0].position), PUFF_EVERY, 0.5,
		"puffs sit %s cells apart" % PUFF_EVERY)
	_complete()

# The bug the emitter split fixed, pinned the other way round: emitted pixels must not ride the emitter.
# If a puff were parented to the bolt, turning the bolt would swing every puff already out of it.
func test_a_dropped_puff_never_moves_again() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 10:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() > 0, "a puff is out")
	var puff: ChFx = puffs[0]
	var dropped_at := puff.global_position
	var turned_at := puff.global_rotation
	bolt.global_rotation += 0.7
	bolt.bolt_velocity = bolt.bolt_velocity.rotated(0.5)
	for _tick in 4:
		await Engine.get_main_loop().physics_frame
	assert_true(is_instance_valid(puff), "the puff is still there")
	assert_true(puff.global_position.is_equal_approx(dropped_at), "the puff stays where it was dropped (%s, was %s)" % [puff.global_position, dropped_at])
	assert_true(is_equal_approx(puff.global_rotation, turned_at), "and keeps its own turn")
	_complete()

# Decoration gives way to the fight in the pool, and the trail is not pool particles: with the pool past
# ChFeedbackParticles' share the sparks stop, and the puffs must go on landing.
func test_puffs_appear_even_when_the_pool_is_full() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 4:
		await Engine.get_main_loop().physics_frame
	world.spawn_visual_particles(Color.WHITE, ORIGIN, Vector2.ZERO, int(world.get_max_particles()), 1.0, 0.5)
	assert_eq(ChFeedbackParticles.budget(world, 1), 0, "the pool is past the share decoration may spend")
	var before := _puffs(world).size()
	for _tick in 6:
		await Engine.get_main_loop().physics_frame
	assert_true(_puffs(world).size() > before, "a puff landed with no pool to spend")
	_complete()

# A puff is a one-shot with nobody holding it: once the bolt is gone nothing keeps its trail alive.
func test_puffs_free_themselves() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var shot: Array = await _rocket_shot(world)
	var bolt: ChProjectile = shot[1]
	assert_true(bolt != null, "the rocket fired")
	for _tick in 6:
		await Engine.get_main_loop().physics_frame
	var puffs := _puffs(world)
	assert_true(puffs.size() > 0, "the bolt dropped puffs")
	var dropped: ChFx = puffs[0]
	bolt.queue_free()
	for _tick in 2:
		await Engine.get_main_loop().physics_frame
	assert_true(is_instance_valid(dropped), "the bolt's own free takes no puff with it")
	# A puff's own life is 22 frames at 30 fps, ~44 physics ticks: 70 is past the last one.
	for _tick in 70:
		await Engine.get_main_loop().physics_frame
	assert_eq(_puffs(world).size(), 0, "every puff freed itself")
	_complete()
