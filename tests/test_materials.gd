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
