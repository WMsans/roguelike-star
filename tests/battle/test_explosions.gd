extends ChTest

# One EXPLOSION per blast, the size table, and who owns a blast. Part blasts go through ctx.explode;
# material blasts are hand-made dicts fed to ctx.hazards.apply, as test_hazards.gd does.

const GROUND_TOP := 160
const HP := 1000
const NEAR := Vector2(120, 140)
const FAR := Vector2(320, 140)
const A := Vector2i(240, 100)  # open air, far from both rigs

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

# A world, two rigs and a context over them, with every EXPLOSION and HIT kept.
func _fight(near := NEAR, far := FAR) -> Dictionary:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock")
	var catalog := _catalog()
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = [_rig(world, catalog, 0, near), _rig(world, catalog, 1, far)]
	var booms: Array[ChEvent] = []
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(self, ChEvent.EXPLOSION, func(e: ChEvent): booms.append(e))
	ctx.bus.subscribe(self, ChEvent.HIT, func(e: ChEvent): hits.append(e))
	return {"world": world, "ctx": ctx, "booms": booms, "hits": hits}

func _blast(at: Vector2i, material := &"tnt", radius := 12) -> Dictionary:
	return {"position": at, "radius": radius, "power": 1.0, "material": material, "dig": 6}

func _owner_of(ctx: ChBattleContext, booms: Array[ChEvent], at: Vector2i) -> int:
	# Drain one tnt entry at `at` and answer the owner its EXPLOSION names.
	var before := booms.size()
	ctx.hazards.apply(ctx, [_blast(at)])
	assert_eq(booms.size(), before + 1, "one EXPLOSION per drained blast")
	return booms.back().data.owner if booms.size() > before else -2


func test_part_blast_emits_one_owned_explosion() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	var part: ChPartRuntime = ctx.chariots[1].parts[0]
	ctx.explode(part, A, &"large", 80)
	ctx.hazards.apply(ctx, f.world.take_blasts())  # the &"" entry the part blast queued adds nothing
	assert_eq(f.booms.size(), 1)
	var e: ChEvent = f.booms[0]
	assert_eq(e.side, 1)
	assert_eq(e.position, Vector2(A))
	assert_eq(e.data.owner, 1)
	assert_eq(e.data.size, &"large")
	assert_eq(e.data.radius, 12)
	assert_eq(e.data.dig, 6)
	assert_eq(e.data.source, part)
	_complete()


func test_part_blast_hits_only_the_enemy() -> void:
	var f := await _fight(Vector2(120, 140), Vector2(136, 140))
	var ctx: ChBattleContext = f.ctx
	var mine: ChChariotRuntime = ctx.chariots[0]
	var theirs: ChChariotRuntime = ctx.chariots[1]
	var centre := Vector2i(128, 140)
	for c in [mine, theirs]:
		var box := ChBattle.hull_box(c)
		var at := Vector2(centre)
		assert_true(at.distance_to(at.clamp(box.position, box.end)) <= 12.0, "side %d is inside" % c.side)
	var box := ChBattle.hull_box(theirs)
	var at := Vector2(centre)
	var expected := roundi(80 * (1.0 - at.distance_to(at.clamp(box.position, box.end)) / 12.0))
	var part: ChPartRuntime = mine.parts[0]
	ctx.explode(part, centre, &"large", 80)
	assert_eq(mine.hp, HP, "a part's own blast never hurts its own chariot")
	assert_eq(theirs.hp, HP - expected)
	assert_eq(f.hits.size(), 1)
	assert_eq(f.hits[0].source, part)
	assert_eq(f.hits[0].data.target_side, 1)
	assert_eq(f.hits[0].data.hp_damage, expected)
	_complete()


func test_part_blast_digs_by_size() -> void:
	var f := await _fight()
	var world: PixelWorld = f.world
	var ctx: ChBattleContext = f.ctx
	world.fill_rect(Rect2i(A.x - 8, A.y - 6, 7, 13), &"rock")
	world.fill_rect(Rect2i(A.x + 2, A.y - 6, 7, 13), &"steel")
	ctx.explode(ctx.chariots[0].parts[0], A, &"large", 80)
	var rock: int = world.count_materials(Rect2i(A.x - 8, A.y - 6, 7, 13)).get(&"rock", 0)
	var steel: int = world.count_materials(Rect2i(A.x + 2, A.y - 6, 7, 13)).get(&"steel", 0)
	assert_true(rock < 7 * 13, "large digs rock (hardness 5): %d left" % rock)
	assert_true(world.get_material_at(A - Vector2i(2, 0)) != &"rock", "the rock beside the centre is gone")
	assert_eq(steel, 7 * 13, "every steel cell (hardness 7) stays")
	_complete()


func test_charge_ownership() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	ctx.own_charge(Rect2i(A, Vector2i(4, 4)), 1)
	var at := A + Vector2i(2, 2)
	assert_eq(_owner_of(ctx, f.booms, at), 1)
	assert_eq(f.booms.back().side, 1)
	assert_eq(f.booms.back().data.material, &"tnt")
	assert_eq(f.booms.back().data.size, &"large")
	assert_eq(f.booms.back().data.source, null)
	_complete()


func test_chain_ownership_carries_and_expires() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	ctx.time = 0.0
	ctx.explode(ctx.chariots[0].parts[0], A, &"large", 80)  # disc at A, radius 12, side 0
	ctx.time = 0.2
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(8, 0)), 0, "inside A's radius, 0.2 s on")
	ctx.time = 0.6
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(18, 0)), 0, "inside the second's radius, 0.4 s after it")
	assert_eq(_owner_of(ctx, f.booms, A - Vector2i(8, 0)), -1, "inside only A's radius, 0.6 s on")
	_complete()


func test_overlapping_owners_first_wins() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	ctx.explode(ctx.chariots[0].parts[0], A, &"large", 80)
	ctx.explode(ctx.chariots[1].parts[0], A + Vector2i(4, 0), &"large", 80)
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(2, 0)), 0, "side 0's disc was recorded first")
	# The other way round, so it is the record order that decides and not the side.
	ctx.hazards = ChHazards.new()
	ctx.explode(ctx.chariots[1].parts[0], A, &"large", 80)
	ctx.explode(ctx.chariots[0].parts[0], A + Vector2i(4, 0), &"large", 80)
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(2, 0)), 1, "side 1's disc was recorded first")
	_complete()


func test_unowned_terrain_blast() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	assert_eq(_owner_of(ctx, f.booms, A), -1)
	assert_eq(f.booms.back().side, -1)
	assert_eq(f.booms.back().data.source, null)
	_complete()


func test_spent_charge_is_dropped() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	ctx.own_charge(Rect2i(A, Vector2i(4, 4)), 1)  # air: nothing explosive to own
	ctx._status_second()
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(2, 2)), -1, "the spent charge claims nothing")
	_complete()


func test_part_blast_wears_enemy_parts_in_radius() -> void:
	var f := await _fight(Vector2(120, 140), Vector2(150, 140))
	var ctx: ChBattleContext = f.ctx
	var theirs: ChChariotRuntime = ctx.chariots[1]
	var mine: ChChariotRuntime = ctx.chariots[0]
	var near_part: ChPartRuntime = theirs.parts[0]
	var far_part: ChPartRuntime = theirs.parts[1]
	if far_part.anchor_world().x < near_part.anchor_world().x:
		var swap := near_part
		near_part = far_part
		far_part = swap
	var centre := Vector2i(near_part.anchor_world() - Vector2(8, 0))
	assert_true(Vector2(centre).distance_to(near_part.anchor_world()) <= 12.0, "one enemy part inside")
	assert_true(Vector2(centre).distance_to(far_part.anchor_world()) > 12.0, "the other outside")
	var box := ChBattle.hull_box(theirs)
	var at := Vector2(centre)
	var dealt := roundi(80 * (1.0 - at.distance_to(at.clamp(box.position, box.end)) / 12.0))
	assert_true(dealt > 0, "the hull is inside too")
	var mine_before: Array[int] = []
	for part in mine.parts:
		mine_before.append(part.integrity)
	ctx.explode(mine.parts[0], centre, &"large", 80)
	assert_eq(near_part.integrity, 200 - roundi(dealt * ChHazards.BLAST_WEAR), "worn by the damage dealt")
	assert_eq(far_part.integrity, 200, "outside the radius: untouched")
	for i in mine.parts.size():
		assert_eq(mine.parts[i].integrity, mine_before[i], "own part %d untouched" % i)
	_complete()


class HitRecorder:
	var hits: Array = []

	func modify_hit(_ctx: ChBattleContext, hit: Dictionary) -> void:
		hits.append(hit.duplicate())


func test_part_blast_hit_names_the_explosion() -> void:
	var f := await _fight(Vector2(120, 140), Vector2(136, 140))
	var ctx: ChBattleContext = f.ctx
	var part: ChPartRuntime = ctx.chariots[0].parts[0]
	var recorder := HitRecorder.new()
	part.behaviour = recorder
	ctx.explode(part, Vector2i(128, 140), &"large", 80)
	part.behaviour = null
	assert_eq(recorder.hits.size(), 1, "the source is asked about its one hit")
	assert_eq(recorder.hits[0].get("explosion"), &"large", "the hit carries the blast's size")
	_complete()


func test_charge_with_explosive_left_is_kept() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	f.world.fill_rect(Rect2i(A, Vector2i(4, 4)), &"tnt")
	ctx.own_charge(Rect2i(A, Vector2i(4, 4)), 1)
	ctx._status_second()
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(2, 2)), 1, "the charge still holds its TNT")
	_complete()


func test_terrain_tnt_beside_a_spent_charge_does_not_keep_it() -> void:
	var f := await _fight()
	var ctx: ChBattleContext = f.ctx
	f.world.fill_rect(Rect2i(A + Vector2i(5, 0), Vector2i(2, 4)), &"tnt")  # inside the margin, outside the rect
	ctx.own_charge(Rect2i(A, Vector2i(4, 4)), 1)  # air
	ctx._status_second()
	assert_eq(_owner_of(ctx, f.booms, A + Vector2i(2, 2)), -1, "the spent charge claims nothing")
	_complete()
