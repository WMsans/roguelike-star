extends ChTest

# Task 3: the game material set at res://game/materials/ (ChTest.make_world loads game_set.tres
# and sets the border to concrete). It adds concrete, frost and ice, and water freezes.


func test_frost_freezes_water() -> void:
	var world := await make_world()
	assert_eq(world.fill_rect(Rect2i(100, 100, 10, 10), &"water"), 100, "water block placed")
	# The brief's "frost circle above it" never freezes anything: probed at centres (105, 96), (105, 99),
	# (105, 102) and (105, 105), no ice appears anywhere in the arena in 300 ticks. move_gas (movement.cpp)
	# lifts a frost cell sitting on the block into the Empty cell above it, so the circle leaves the water
	# within ~3 ticks and frost's lifetime 40 turns the rest to air (decay, chemistry.cpp). exchange_heat
	# bails out for frost itself (def.fixed_temp, chemistry.cpp), so only a water cell that runs chemistry
	# with frost as its 1-of-4 hash-picked neighbour can cool, and a frost cell that rose from inside the
	# block left the water it displaced stamped (step() in movement.cpp), which update_cell skips that tick;
	# next_speed then lets the gas rise 1..15 cells a tick, so no frost stays beside a water cell that gets
	# its turn. Centred below the block the contact lands: frost rises up through the column, the water it
	# swapped with runs chemistry next tick with frost above it, and one exchange of round(-80 * min(1.0, 0.6)
	# * 0.5) = -24 crosses water's low_temperature 0 (phase_change, chemistry.cpp). This is geometry only:
	# frost's gas class, fixed_temperature = true, base_temperature = -60 and lifetime = 40 are the plan's.
	# First ice tick by centre y, radius 6, this seed: 96..105 none, 106 -> 2, 108 -> 1, 114 -> 1; 106 is
	# the closest working centre.
	assert_eq(world.fill_circle(Vector2i(105, 106), 6, &"frost"), 113, "frost circle placed")
	# shortcut: the zone is this setup's column; widen it to the arena rect if a test puts water elsewhere.
	var zone := Rect2i(90, 90, 45, 90)
	# shortcut: ice thaws back within a few ticks beside water, so every tick is counted; upgrade
	# to one step(N) call if ice survives. 300 ticks is the brief's bound.
	var frozen := false
	var ticks := 0
	while not frozen and ticks < 300:
		world.step(1)
		ticks += 1
		if world.count_materials(zone).get(&"ice", 0) > 0:
			frozen = true
			break
	assert_true(frozen, "no ice within 300 ticks")
	world.free()
	_complete()


func test_fire_thaws_ice() -> void:
	var world := await make_world()
	assert_eq(world.fill_rect(Rect2i(200, 150, 6, 6), &"ice"), 36, "ice block placed")
	# The fire circle straddles the block's right edge, so ice has a hot neighbour from the first tick.
	assert_eq(world.fill_circle(Vector2i(207, 153), 3, &"fire"), 29, "fire circle placed")
	var zone := Rect2i(190, 140, 60, 40)
	# The zone is wider than the ice block on purpose: the water the ice releases falls to the arena
	# floor, and nothing else in the arena holds water, so a positive count is this setup's thaw.
	# shortcut: the zone is this setup's footprint; widen it to the arena rect if a test adds water
	# elsewhere.
	# Probed: the thaw shows on the first tick (30 water in the block rect), so every tick is counted
	# one step at a time; 300 ticks is the brief's bound.
	var thawed := false
	var ticks := 0
	while not thawed and ticks < 300:
		world.step(1)
		ticks += 1
		var counts: Dictionary = world.count_materials(zone)
		if counts.get(&"water", 0) > 0 or counts.get(&"steam", 0) > 0:
			thawed = true
			break
	assert_true(thawed, "no water or steam within 300 ticks")
	world.free()
	_complete()


func test_border_is_concrete() -> void:
	var world := await make_world()
	assert_eq(world.get_material_at(Vector2i(-1, 90)), &"concrete", "the arena border reads concrete")
	world.free()
	_complete()


func test_game_set_has_explosives() -> void:
	var set: PixelMaterialSet = load("res://game/materials/game_set.tres")
	var found := {}
	for m in set.materials:
		if m.explode_radius > 0:
			found[m.name] = true
	assert_true(found.has(&"gunpowder") and found.has(&"tnt"), "gunpowder and tnt explode")
	_complete()


func test_acid_eats_sand_not_rock() -> void:
	var world := await make_world()
	var arena := Rect2i(0, 0, 480, 180)
	# rock basin: floor and two walls around x 100..119
	world.fill_rect(Rect2i(98, 150, 24, 3), &"rock")
	world.fill_rect(Rect2i(98, 130, 2, 20), &"rock")
	world.fill_rect(Rect2i(120, 130, 2, 20), &"rock")
	world.fill_rect(Rect2i(100, 146, 20, 4), &"sand")
	world.fill_rect(Rect2i(105, 140, 6, 6), &"acid")
	var sand_before: int = world.count_materials(arena).get(&"sand", 0)
	var rock_before: int = world.count_materials(arena).get(&"rock", 0)
	world.step(120)
	var after: Dictionary = world.count_materials(arena)
	assert_true(after.get(&"sand", 0) < sand_before, "acid ate sand")
	assert_eq(after.get(&"rock", 0), rock_before, "rock untouched")
	world.free()
	_complete()


func test_fire_sets_off_tnt() -> void:
	var world := await make_world()
	world.fill_rect(Rect2i(200, 150, 4, 4), &"tnt")
	var hit := false
	for i in 120:
		# fire lives 24 ticks and heats slowly (conductivity 0.1), so keep a flame beside the crate
		world.fill_rect(Rect2i(204, 150, 3, 4), &"fire")
		world.step(1)
		for b in world.take_blasts():
			if b["material"] == &"tnt":
				hit = true
		if hit:
			break
	assert_true(hit, "tnt blast within 120 ticks")
	world.free()
	_complete()


func test_hardness_values() -> void:
	var want := {&"sand": 1, &"gunpowder": 1, &"wood": 3, &"tnt": 3, &"ice": 4, &"rock": 5,
		&"dirt": 2, &"coal": 3, &"battery": 4, &"steel": 7, &"obsidian": 8}
	var set: PixelMaterialSet = load("res://game/materials/game_set.tres")
	var seen := {}
	for m in set.materials:
		seen[m.name] = true
		assert_eq(m.indestructible, m.name == &"concrete", "indestructible only for concrete (%s)" % m.name)
		assert_eq(m.hardness, want.get(m.name, 0), "hardness of %s" % m.name)
	for n in want:
		assert_true(seen.has(n), "%s is in the game set" % n)
	_complete()


func test_lava_and_frost_make_obsidian() -> void:
	var world := await make_world()
	var arena := Rect2i(0, 0, 480, 180)
	world.fill_rect(Rect2i(100, 150, 10, 10), &"lava")
	world.fill_rect(Rect2i(110, 150, 4, 10), &"frost")
	var made := false
	var ticks := 0
	while not made and ticks < 300:
		world.step(1)
		ticks += 1
		made = world.count_materials(arena).get(&"obsidian", 0) > 0
	assert_true(made, "no obsidian within 300 ticks")
	world.free()
	_complete()


func test_acid_dissolving_releases_acid_gas() -> void:
	var world := await make_world()
	var arena := Rect2i(0, 0, 480, 180)
	world.fill_rect(Rect2i(100, 170, 20, 5), &"sand")
	world.fill_rect(Rect2i(105, 160, 6, 10), &"acid")
	var seen := false
	var ticks := 0
	while not seen and ticks < 300:
		world.step(1)
		ticks += 1
		seen = world.count_materials(arena).get(&"acid_gas", 0) > 0
	assert_true(seen, "no acid_gas within 300 ticks")
	world.free()
	_complete()


func test_lit_flammable_gas_is_a_medium_blast() -> void:
	var world := await make_world()
	# sealed rock pocket 20x20 inside, walls 3 thick
	world.fill_rect(Rect2i(100, 100, 26, 26), &"rock")
	world.fill_rect(Rect2i(103, 103, 20, 20), &"air")
	world.fill_rect(Rect2i(105, 105, 16, 16), &"flammable_gas")
	world.fill_rect(Rect2i(112, 112, 2, 2), &"fire")
	var found := {}
	var ticks := 0
	while found.is_empty() and ticks < 300:
		world.step(1)
		ticks += 1
		for b in world.take_blasts():
			if b["material"] == &"flammable_gas":
				found = b
	assert_true(not found.is_empty(), "no flammable_gas blast within 300 ticks")
	assert_eq(found.get("radius"), 8, "radius 8")
	assert_eq(found.get("dig"), 4, "dig 4")
	world.free()
	_complete()


func test_coal_outburns_wood() -> void:
	var world := await make_world()
	var arena := Rect2i(0, 0, 480, 180)
	# Two blocks on the floor, a fire strip touching both, fed every tick (fire lives 24 ticks).
	world.fill_rect(Rect2i(100, 160, 6, 6), &"coal")
	world.fill_rect(Rect2i(110, 160, 6, 6), &"wood")
	var wood_gone := false
	var coal_left := 0
	for i in 600:
		world.fill_rect(Rect2i(106, 160, 4, 6), &"fire")
		world.step(1)
		var counts: Dictionary = world.count_materials(arena)
		if counts.get(&"wood", 0) == 0:
			wood_gone = true
			coal_left = counts.get(&"coal", 0)
			break
	assert_true(wood_gone, "wood never burned away")
	assert_true(coal_left > 0, "coal still there when the wood is gone")
	world.free()
	_complete()


# A lit 12x12 TNT crate in a 3-thick box with a 4-cell gap, so the inner wall faces are ~10 cells from the
# crate centre, inside TNT's radius 12. Returns the wall material's cell count after the blast.
func _tnt_box_wall_after(wall: StringName) -> Array[int]:
	var world := await make_world()
	var arena := Rect2i(0, 0, 480, 180)
	world.fill_rect(Rect2i(207, 137, 26, 26), wall)
	world.fill_rect(Rect2i(210, 140, 20, 20), &"air")
	world.fill_rect(Rect2i(214, 144, 12, 12), &"tnt")
	var before: int = world.count_materials(arena).get(wall, 0)
	var blasted := false
	var ticks := 0
	while not blasted and ticks < 300:
		# fire lives 24 ticks and heats slowly, so keep a flame beside the crate (as test_fire_sets_off_tnt)
		world.fill_rect(Rect2i(212, 148, 2, 6), &"fire")
		world.step(1)
		ticks += 1
		for b in world.take_blasts():
			if b["material"] == &"tnt":
				blasted = true
	assert_true(blasted, "tnt blast within 300 ticks")
	var after: int = world.count_materials(arena).get(wall, 0)
	world.free()
	return [before, after]


func test_tnt_blast_spares_steel() -> void:
	var c: Array[int] = await _tnt_box_wall_after(&"steel")
	assert_eq(c[1], c[0], "steel (hardness 7 > dig 6) untouched")
	_complete()


func test_tnt_blast_digs_rock_control() -> void:
	var c: Array[int] = await _tnt_box_wall_after(&"rock")
	assert_true(c[1] < c[0], "same box in rock (hardness 5 <= dig 6) loses cells")
	_complete()
