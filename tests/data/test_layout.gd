extends ChTest

# Task 4: the chariot layout data model. The catalog is built in code here; Task 4b adds the
# .tres content. Body A slots [(-10,0),(10,0),(0,-6)], body B slots [(9,0),(-9,0)],
# strut extension_slots [(0,-6),(4,-6)]. `mace` has no def on purpose: place() records an id,
# it does not look one up.


func _catalog() -> ChCatalog:
	var parts: Array[ChPartDef] = [_mk_part(&"strut", [Vector2(0, -6), Vector2(4, -6)])]
	# Body B is smaller than A, so a swap can leave a subtree over.
	var bodies: Array[ChBodyDef] = [
		_mk_body(&"A", [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -6)]),
		_mk_body(&"B", [Vector2(9, 0), Vector2(-9, 0)]),
	]
	return ChCatalog.from_defs(parts, bodies)


func _mk_part(id: StringName, extensions: Array) -> ChPartDef:
	var part := ChPartDef.new()
	part.id = id
	# shortcut: only extension_slots matters to these tests; Task 4b sets the real numbers.
	part.extension_slots = PackedVector2Array(extensions)
	return part


func _mk_body(id: StringName, slots: Array) -> ChBodyDef:
	var body := ChBodyDef.new()
	body.id = id
	# shortcut: fixed size; these tests read slots only, a later task draws the shape.
	body.slots = PackedVector2Array(slots)
	return body


func _layout(body_id: StringName) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	return layout


func test_place_and_nested_place() -> void:
	var layout := _layout(&"A")
	assert_eq(layout.place([0], &"strut"), true, "body slot 0 takes a strut")
	# [0, 1] is extension slot 1 of the part in body slot 0.
	assert_eq(layout.place([0, 1], &"mace"), true, "the strut's extension 1 takes a part")
	assert_eq(layout.place([0], &"mace"), false, "body slot 0 is occupied")
	# Body slot 1 is empty, so [1, 0] has no parent node to mount on.
	assert_eq(layout.place([1, 0], &"mace"), false, "a missing parent fails the place")
	_complete()


func test_remove_returns_subtree() -> void:
	var layout := _layout(&"A")
	assert_true(layout.place([0], &"strut"), "mount the parent")
	assert_true(layout.place([0, 1], &"mace"), "mount the child on it")
	var detached: ChSlotNode = layout.remove([0])
	assert_true(detached != null, "remove hands back the detached subtree")
	assert_eq(detached.children.size(), 1, "the detached subtree still holds its child")
	# remove() returns the whole subtree, so the garage can put it back in the inventory.
	assert_eq(layout.subtree_part_ids(detached), [&"strut", &"mace"], "the subtree, depth-first")
	assert_eq(layout.get_node([0]), null, "the body slot is empty after the remove")
	_complete()


func test_flip_mirrors_child_anchor() -> void:
	var catalog := _catalog()
	var layout := _layout(&"A")
	assert_true(layout.place([1], &"strut"), "the strut mounts on body slot 1 at (10,0)")
	# anchor_of resolves a path through nodes that exist, so the child is mounted before
	# either anchor is read. Body slot 1 is (10,0); the strut's extension 1 is (4,-6).
	assert_true(layout.place([1, 1], &"mace"), "the child mounts on the strut's extension 1")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(14, -6), "unflipped parent: (10+4, -6)")
	# A flip turns the mount 180°, so a child's extension x offset negates: (10-4, -6).
	layout.toggle_flip([1])
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(6, -6), "flipped parent: (10-4, -6)")
	_complete()


func test_swap_body_nearest() -> void:
	var catalog := _catalog()
	var layout := _layout(&"A")
	assert_true(layout.place([0], &"strut"), "a part on A slot 0 at (-10,0)")
	assert_true(layout.place([1], &"strut"), "a part on A slot 1 at (10,0)")
	assert_true(layout.place([1, 0], &"mace"), "that part carries a child on its extension 0")
	# A slot 1 (10,0) is 1 cell from B slot 0 (9,0); A slot 0 (-10,0) is 1 cell from B slot 1 (-9,0).
	var leftovers: Array[ChSlotNode] = layout.swap_body(catalog.body(&"B"), catalog)
	assert_eq(layout.body_id, &"B", "the layout now sits on body B")
	assert_eq(leftovers.size(), 0, "both top-level subtrees found a slot")
	# The part that carried a child moved as a subtree, so the child is still under it.
	assert_true(layout.get_node([0]) != null, "B slot 0 holds the subtree from A slot 1")
	assert_true(layout.get_node([0, 0]) != null, "the child moved with its parent")
	assert_eq(layout.get_node([0, 0]).part_id, &"mace", "the child kept its extension index")
	assert_eq(layout.anchor_of([0], catalog), Vector2(9, 0), "reseeded onto B slot 0")
	assert_eq(layout.anchor_of([1], catalog), Vector2(-9, 0), "the other part onto B slot 1")
	_complete()


func test_swap_to_smaller_body_returns_leftovers_whole() -> void:
	var catalog := _catalog()
	var layout := _layout(&"A")
	assert_true(layout.place([0], &"strut"), "A slot 0 filled")
	assert_true(layout.place([1], &"strut"), "A slot 1 filled")
	assert_true(layout.place([2], &"strut"), "A slot 2 at (0,-6) filled by the strut")
	# The strut still carries a child, so it must come back whole rather than stripped.
	assert_true(layout.place([2, 0], &"mace"), "the strut carries a child on its extension 0")
	# B has two slots; (0,-6) is the farthest of the three, so it is the one left over.
	var leftovers: Array[ChSlotNode] = layout.swap_body(catalog.body(&"B"), catalog)
	assert_eq(leftovers.size(), 1, "one subtree does not fit B")
	# A leftover comes back as the whole subtree, not as its parts.
	assert_eq(leftovers[0].part_id, &"strut", "the leftover is the strut subtree")
	assert_eq(leftovers[0].children.size(), 1, "it still has its child")
	assert_eq(layout.slots.size(), 2, "only the two reseated subtrees stay mounted")
	_complete()


func test_mirrored_inverts_flips() -> void:
	var layout := _layout(&"A")
	assert_true(layout.place([0], &"strut"), "mount the parent")
	assert_true(layout.place([0, 1], &"mace"), "mount the child")
	layout.toggle_flip([0])
	var mirror: ChChariotLayout = layout.mirrored()
	# The enemy copy faces the other way: every flipped flag inverts, down to the children.
	assert_eq(mirror.get_node([0]).flipped, false, "the flipped parent comes back unflipped")
	assert_eq(mirror.get_node([0, 1]).flipped, true, "the unflipped child comes back flipped")
	# mirrored() is a deep copy: it must not reach back and re-flip the original.
	assert_eq(layout.get_node([0]).flipped, true, "the original keeps its own flip")
	assert_eq(mirror.get_node([0]).children.size(), 1, "the shape copies across")
	assert_eq(mirror.slots.size(), layout.slots.size(), "same body slots")
	_complete()


func test_inventory_capacity() -> void:
	var inventory := ChInventory.new()
	inventory.capacity = 1
	assert_true(inventory.add(&"strut"), "the first part fits")
	assert_true(not inventory.add(&"mace"), "capacity 1 is full")
	assert_true(not inventory.take(&"mace"), "taking a missing id fails")
	assert_true(inventory.has(&"strut"), "the part still held is reported")
	assert_true(inventory.take(&"strut"), "taking a held part works")
	assert_true(not inventory.has(&"strut"), "take removed it")
	assert_true(inventory.add(&"mace"), "the freed slot takes another part")
	_complete()
