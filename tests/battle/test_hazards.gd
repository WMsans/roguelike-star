extends ChTest

# Material blasts hurt and push chariots. The blasts are hand-made dicts fed to ChHazards.apply, so
# nothing here needs TNT in the world. Rigs come out of the real builder, as test_context.gd does.

const GROUND_TOP := 160
const HP := 1000  # more than a TNT centre hit, so the arithmetic is never clamped
const TNT := 300  # ChHazards.BLAST_DAMAGE[&"tnt"], the HP a TNT blast takes at its centre
const NEAR := Vector2(120, 140)
const FAR := Vector2(320, 140)

func _catalog() -> ChCatalog:
	var strut := ChPartDef.new()
	strut.id = &"strut"
	strut.integrity = 200
	strut.size = Vector2i(2, 2)
	strut.charges = -1
	var body := ChBodyDef.new()
	body.id = &"rig"
	body.hp = HP
	body.size = Vector2i(10, 6)
	body.slots = PackedVector2Array([Vector2(0, 0), Vector2(6, 0)])
	return ChCatalog.from_defs([strut] as Array[ChPartDef], [body] as Array[ChBodyDef])

func _rig(world: PixelWorld, catalog: ChCatalog, side: int, at: Vector2) -> ChChariotRuntime:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	layout.place([0] as Array[int], &"strut")
	layout.place([1] as Array[int], &"strut")
	return ChChariotBuilder.build(world, _parent(), layout, catalog, side, at, false)

# A world, two rigs and a context over them, with every emitted event kept.
func _fight() -> Dictionary:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock")
	var catalog := _catalog()
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = [_rig(world, catalog, 0, NEAR), _rig(world, catalog, 1, FAR)]
	var heard: Array[ChEvent] = []
	ctx.bus.subscribe(self, ChEvent.HAZARD_HIT, func(e: ChEvent): heard.append(e))
	return {"world": world, "ctx": ctx, "heard": heard}

func _blast(at: Vector2, radius: int, material := &"tnt") -> Dictionary:
	return {"position": Vector2i(at), "radius": radius, "power": 1.0, "material": material}

func test_material_blast_costs_hp_once() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var c: ChChariotRuntime = ctx.chariots[0]
	var before: Array[int] = []
	for part in c.parts:
		before.append(part.integrity)
	var centre := c.chassis.global_position
	ChHazards.apply(ctx, [_blast(centre, 12)])
	assert_eq(c.hp, HP - TNT)
	for at in c.parts.size():
		var part: ChPartRuntime = c.parts[at]
		var inside := part.anchor_world().distance_to(Vector2(Vector2i(centre))) <= 12.0
		assert_eq(part.integrity, before[at] - (roundi(TNT * ChHazards.BLAST_WEAR) if inside else 0), "part %d" % at)
	assert_true(c.parts[0].anchor_world().distance_to(centre) <= 12.0, "at least one part is inside")
	var mine := 0
	for e in f.heard:
		if e.data.target_side == 0:
			mine += 1
	assert_eq(mine, 1, "one HAZARD_HIT")
	assert_eq(f.heard[0].data.hp_damage, TNT)
	assert_eq(f.heard[0].data.hp_after, HP - TNT)
	assert_eq(f.heard[0].data.material, &"tnt")
	assert_eq(f.heard[0].source, null)
	_complete()

func test_falloff_halves_at_half_radius() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var c: ChChariotRuntime = ctx.chariots[0]
	var box := ChBattle.hull_box(c)
	ChHazards.apply(ctx, [_blast(Vector2(box.position.x - 6.0, box.get_center().y), 12)])
	assert_eq(c.hp, HP - roundi(TNT * 0.5))
	_complete()

func test_script_blast_deals_nothing() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var c: ChChariotRuntime = ctx.chariots[0]
	ChHazards.apply(ctx, [_blast(c.chassis.global_position, 12, &"")])
	assert_eq(c.hp, HP)
	assert_eq(f.heard.size(), 0)
	_complete()

func test_one_blast_both_chariots_each_once() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var a: ChChariotRuntime = ctx.chariots[0]
	var b: ChChariotRuntime = ctx.chariots[1]
	var centre := Vector2(220, 140)
	ChHazards.apply(ctx, [_blast(centre, 150)])
	for c in [a, b]:
		var box := ChBattle.hull_box(c)
		var d := centre.distance_to(centre.clamp(box.position, box.end))
		assert_eq(c.hp, HP - roundi(TNT * (1.0 - d / 150.0)), "side %d" % c.side)
	assert_eq(f.heard.size(), 2)
	_complete()

func test_broken_part_and_freed_chassis_skipped() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var a: ChChariotRuntime = ctx.chariots[0]
	var b: ChChariotRuntime = ctx.chariots[1]
	a.break_part(a.parts[0], ctx)
	var kept: int = a.parts[0].integrity
	b.chassis.free()
	ChHazards.apply(ctx, [_blast(a.chassis.global_position, 12)])
	assert_eq(a.parts[0].integrity, kept, "a broken part is not worn again")
	assert_eq(f.heard.size(), 1, "only the intact chariot is hit")
	_complete()

func test_blast_pushes_away() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var c: ChChariotRuntime = ctx.chariots[0]
	await Engine.get_main_loop().process_frame
	f.world.step(1)
	var at := c.chassis.global_position - Vector2(6, 0)
	ChHazards.apply(ctx, [{"position": Vector2i(at), "radius": 12, "power": 4.0, "material": &"tnt"}])
	# The body joins the physics world on a frame, so one passes before the step.
	await Engine.get_main_loop().process_frame
	f.world.step(1)
	assert_true(c.chassis.linear_velocity.x > 0.0, "pushed +x: %s" % c.chassis.linear_velocity)
	_complete()
