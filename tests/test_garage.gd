extends ChTest

# Task 16: the garage's logic — the inventory handshakes (drop, lift), the flip click, the body
# cycle and the copy `fight_requested` hands the battle. ChGarage.setup is what a scene calls
# before any of these, so every test builds its own garage, inventory and layout: a garage owns
# the references it was handed, so a shared one would carry an earlier test's mounts.
# The UI is built on these same methods, so nothing below touches the mouse.


func _catalog() -> ChCatalog:
	var catalog := ChCatalog.load_default()
	assert_true(catalog != null, "the slice's defs load")
	# shortcut: one null-check here; a missing def fails every test below rather than
	# printing one confusing null access each.
	if catalog == null:
		return ChCatalog.new()
	return catalog


func _garage(inventory: ChInventory, layout: ChChariotLayout,
	catalog: ChCatalog) -> ChGarage:
	# A bare Control, off the tree: the logic methods read no nodes and draw nothing.
	# The test, not the scene, owns the inventory and the layout, which is how the later shop
	# wraps the garage by handing over its own pair.
	var garage := ChGarage.new()
	garage.setup(inventory, layout, catalog)
	return garage


func _inventory(ids: Array) -> ChInventory:
	var inventory := ChInventory.new()
	for id in ids:
		assert_true(inventory.add(id), "the starter id fits")
	return inventory


func _layout(body_id: StringName) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	# ChariotLayout.new() starts body_id empty, which swap_body has no position to measure from,
	# so a garage is only ever set up on a body the catalog has a def for.
	# shortcut: a body_id the catalog has no def for stays a caller error; cycle_body's refusal
	# is what such a layout shows, and setup invents no rule of its own.
	layout.body_id = body_id
	return layout


func test_drop_takes_from_inventory() -> void:
	var inventory := _inventory([&"wheel", &"wheel", &"cutter_chainsaw"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	# The layout the test holds IS the one the garage was handed, so the mount reads back there.
	assert_true(layout.get_node([0]) != null, "so the wheel mounted")
	assert_eq(layout.slots[0].part_id, &"wheel", "as the wheel")
	# ChInventory.take lifts the FIRST copy, so the list stays in its original order minus one.
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "one copy left, order kept")
	# A part the inventory does not carry cannot be dropped, and the inventory stays as it was.
	assert_true(not garage.drop_part(&"cutter_rocket", [1]), "an id not carried is refused")
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "unchanged by the refusal")
	# ChChariotLayout.place refuses a taken slot, so the garage loses nothing from the inventory.
	assert_true(not garage.drop_part(&"wheel", [0]), "a taken slot refuses")
	assert_true(layout.slots.size() == 1, "and the layout gained nothing")
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "so the part stayed carried")
	# Inherited from Task 4, and deliberately not hardened here: place accepts a slot index no
	# def owns, so the garage adds no range rule of its own. Such a mount reads back no anchor.
	assert_true(garage.drop_part(&"wheel", [9]), "an out-of-range index still mounts")
	# shortcut: anchor_of is asserted rather than a refusal, because a range check belongs in
	# Task 4's place(), which the brief says stays as it is.
	assert_eq(layout.anchor_of([9], _catalog()), Vector2.ZERO, "and it has no anchor")
	garage.free()
	_complete()


func test_lift_returns_subtree() -> void:
	var inventory := _inventory([&"strut", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts with nothing under it")
	# The strut's extension slot 0 is (0,-6), so a wheel bolted there is one path step deep.
	assert_true(garage.drop_part(&"wheel", [1, 0]), "the wheel bolts onto the strut")
	assert_true(inventory.part_ids.is_empty(), "both drops left the inventory empty")
	assert_true(not garage.lift([3]), "an empty slot lifts nothing")
	assert_true(garage.lift([1]), "lifting the strut takes its whole branch")
	# The child travelled with its parent, so it is no longer mounted either.
	# shortcut: the brief's exact claim is the two ids coming back, asserted next; get_node is the
	# supporting evidence that the branch rather than only its tip detached.
	assert_true(layout.get_node([1]) == null, "the branch left the body slot")
	assert_true(layout.slots.size() == 0, "nothing stays mounted, child included")
	assert_true(inventory.has(&"strut") and inventory.has(&"wheel"), "both ids back in inventory")
	assert_eq(inventory.part_ids.size(), 2, "so the strut and its wheel are carried again")
	# The child's path has no parent now, so it cannot be re-dropped before its parent is.
	assert_true(not garage.drop_part(&"wheel", [1, 0]), "a nested path needs its parent mounted")
	garage.free()
	_complete()


func test_click_flips() -> void:
	var catalog := _catalog()
	var inventory := _inventory([&"strut", &"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, catalog)
	assert_true(garage.drop_part(&"strut", [1]), "the strut takes cutter slot 1 at (6,3)")
	assert_true(garage.drop_part(&"wheel", [1, 1]), "the wheel sits on the strut's extension 1 at (4,-6)")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(10, -3), "unflipped parent: 6+4 across")
	garage.click_part([1])
	# A flip turns the mount the other way, so the child's extension x negates: the anchor moves,
	# which is the only visible effect a flip has on a part that owns no range of its own.
	assert_true(layout.get_node([1]).flipped, "the flag toggled")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(2, -3), "flipped parent: 6-4 across")
	garage.click_part([1])
	assert_true(not layout.get_node([1]).flipped, "a second click toggles back")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(10, -3), "and the child returns to its cell")
	# ChChariotLayout.toggle_flip answers silently for a path nothing holds; the garage does not
	# add its own check, so a stray click changes nothing rather than losing a part.
	garage.click_part([2])
	assert_true(layout.slots.has(1), "the mounted strut is untouched by a click on an empty slot")
	garage.free()
	_complete()


func test_cycle_body_keeps_parts_and_returns_leftovers() -> void:
	# Corsair slots sit at (-8,3),(10,3),(-18,-5),(-8,-5),(2,-5),... and the Cutter's four at
	# (-4,3),(6,3),(-4,-3),(6,-3), so swap_body's greedy nearest pairing moves every mount except
	# the strut at Corsair slot 2 (-18,-5), which is 14 cells from the closest Cutter slot.
	var inventory := _inventory([&"wheel", &"wheel", &"strut", &"wheel", &"ember_battery",
	    &"cutter_rocket"])
	var layout := _layout(&"corsair")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "Corsair slot 0 at (-8,3)")
	assert_true(garage.drop_part(&"wheel", [1]), "Corsair slot 1 at (10,3)")
	assert_true(garage.drop_part(&"strut", [2]), "Corsair slot 2 at (-18,-5)")
	assert_true(garage.drop_part(&"wheel", [2, 0]), "a wheel bolted under that strut")
	assert_true(garage.drop_part(&"ember_battery", [3]), "Corsair slot 3 at (-8,-5)")
	assert_true(garage.drop_part(&"cutter_rocket", [4]), "Corsair slot 4 at (2,-5)")
	assert_true(inventory.part_ids.is_empty(), "six drops left the inventory empty")
	garage.cycle_body()
	# Cutter -> Dozer -> Corsair -> Cutter, so a build starting on Corsair wraps to Cutter.
	assert_eq(layout.body_id, &"cutter", "the cycle moved one body on")
	assert_eq(layout.slots.size(), 4, "four of the five mounts found a Cutter slot")
	assert_eq(layout.get_node([0]).part_id, &"wheel", "the wheels kept a top-level slot each")
	assert_eq(layout.get_node([1]).part_id, &"wheel", "as did the other")
	assert_eq(layout.get_node([2]).part_id, &"ember_battery", "the Ember Battery took slot 2")
	assert_eq(layout.get_node([3]).part_id, &"cutter_rocket", "the Rocket took slot 3")
	assert_true(layout.get_node([2, 0]) == null, "and the branch that came back left nothing behind")
	# A leftover comes back as its whole subtree, so the ids travel parent first.
	assert_eq(inventory.part_ids, [&"strut", &"wheel"], "the branch came back whole, parent first")
	garage.cycle_body()
	# Cutter -> Dozer: both bodies have six slots, so the nearest pairing keeps each index
	# (a Dozer slot sits under the Cutter slot it answers for), so nothing is left over.
	assert_eq(layout.body_id, &"dozer", "and the cycle keeps going")
	assert_eq(layout.slots.size(), 4, "all four fit the Dozer")
	assert_eq(inventory.part_ids, [&"strut", &"wheel"], "and the same two carried parts")
	assert_eq(layout.get_node([4]).part_id, &"ember_battery", "the Ember Battery moved to slot 4")
	assert_eq(layout.get_node([3]).part_id, &"cutter_rocket", "and the Rocket stayed at 3")
	garage.free()
	_complete()


func test_fight_emits_layout_copy() -> void:
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(_inventory([&"wheel", &"wheel"]), layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "one mount, so the copy has a node to copy")
	var handed: Array = []
	var sink := handed
	garage.fight_requested.connect(func(copy: ChChariotLayout): sink.append(copy))
	garage.request_fight()
	assert_eq(handed.size(), 1, "Fight hands over exactly one layout")
	var copy: ChChariotLayout = handed[0]
	# The brief's point: the battle receives a copy, so it can never mutate the garage's build
	# (ChBattle mirrors the layout it is given).
	assert_true(copy.get_instance_id() != layout.get_instance_id(), "not the garage's instance")
	assert_true(copy.get_node([0]).get_instance_id() != layout.get_node([0]).get_instance_id(),
		"deep copy: even the node is new")
	assert_eq(copy.body_id, layout.body_id, "carrying the same body")
	assert_eq(copy.slots.size(), layout.slots.size(), "and the same mounts")
	assert_true(copy.get_node([0]).part_id == layout.get_node([0]).part_id, "the same part")
	# The copy keeps the same flips, because the pit and the fight have to agree on which way a
	# part faces (mirrored() would have inverted them, which is how an enemy build is sent).
	var copy_flip := copy.get_node([0]).flipped
	assert_eq(copy_flip, layout.get_node([0]).flipped, "the copy faces the same way")
	layout.toggle_flip([0])
	assert_true(layout.get_node([0]).flipped, "the garage's own mount changed")
	assert_eq(copy.get_node([0]).flipped, copy_flip, "and the copy kept its own flip")
	garage.free()
	_complete()
