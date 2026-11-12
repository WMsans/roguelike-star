extends ChTest

# Task 5: the carried-parts bag. capacity is the run's rule (CAPACITY, five slots) and -1 is the
# unlimited kit ChMain still hands the garage, which is the case free_slots exists to cover: one
# fit rule serves both. move and remove_at are the inventory bar's handles (Task 11), index rather
# than id, because two copies of one part are different cards.


func _inventory(ids: Array, capacity := -1) -> ChInventory:
	var inventory := ChInventory.new()
	# capacity is set before the adds so an over-capacity fixture cannot be built by accident.
	inventory.capacity = capacity
	for id in ids:
		assert_true(inventory.add(id), "%s fits" % [id])
	return inventory


func test_move_reorders() -> void:
	var inventory := _inventory([&"a", &"b", &"c"])
	assert_true(inventory.move(0, 2), "the first part moves to the last slot")
	# A move is the bar's reorder: the part is lifted out and put down at the target index, so the
	# others close up rather than swapping places with it.
	assert_eq(inventory.part_ids, [&"b", &"c", &"a"], "so the list is the one the bar draws")
	assert_true(not inventory.move(5, 0), "an index past the end refuses")
	assert_true(not inventory.move(0, 5), "and so does a target past the end")
	assert_true(not inventory.move(-1, 0), "as does a negative index")
	assert_eq(inventory.part_ids, [&"b", &"c", &"a"], "a refusal changes nothing")
	_complete()


func test_free_slots() -> void:
	assert_eq(ChInventory.CAPACITY, 5, "the run carries five parts")
	var inventory := _inventory([&"a", &"b", &"c"], ChInventory.CAPACITY)
	assert_eq(inventory.free_slots(), 2, "capacity 5 with three carried")
	# capacity -1 is ChMain's kit today: the garage's lift asks free_slots and must always have room.
	var unlimited := _inventory([&"a"])
	assert_true(unlimited.free_slots() > ChInventory.CAPACITY, "an unlimited kit has room to spare")
	_complete()


func test_remove_at_lifts_one_copy_by_index() -> void:
	var inventory := _inventory([&"wheel", &"wheel", &"strut"])
	assert_eq(inventory.remove_at(1), &"wheel", "the copy at that index leaves")
	assert_eq(inventory.part_ids, [&"wheel", &"strut"], "and the others keep their order")
	assert_eq(inventory.remove_at(9), &"", "an index past the end removes nothing")
	assert_eq(inventory.part_ids, [&"wheel", &"strut"], "so the list is unchanged")
	# take (the id handle) and remove_at (the index handle) find the same part.
	assert_eq(inventory.remove_at(1), &"strut", "the strut by index")
	assert_eq(inventory.part_ids, [&"wheel"], "leaves the wheel")
	_complete()
