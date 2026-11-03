extends ChTest

# Task 3: the game material set at res://game/materials/ (ChTest.make_world loads game_set.tres
# and sets the border to concrete). It adds concrete, frost and ice, and water freezes.


func test_frost_freezes_water() -> void:
	var world := await make_world()
	assert_eq(world.fill_rect(Rect2i(100, 100, 10, 10), &"water"), 100, "water block placed")
	# frost rises and water falls, so the circle sits over the block's lower rows: a frost cell
	# above the water moves away before the water cell below it is ever updated, and with no
	# shared edge the two never exchange heat. Centred below the block they meet face to face.
	world.fill_circle(Vector2i(105, 108), 6, &"frost")
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
	# fire inside the block gives ice a hot neighbour from tick one; fire dies at lifetime 24.
	world.fill_circle(Vector2i(207, 153), 3, &"fire")
	# shortcut: the zone is this setup's footprint; widen it to the arena rect if a test adds water elsewhere.
	var zone := Rect2i(190, 140, 60, 40)
	# shortcut: water released here falls to the arena floor, so the zone reaches y 180.
	# shortcut: counts are sampled per 10-tick batch because fire burns out at lifetime 24;
	# 30 batches x 10 ticks is the brief's 300-tick bound.
	var thawed := false
	for batch in 30:
		world.step(10)
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
