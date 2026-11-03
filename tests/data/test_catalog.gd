extends ChTest

# Task 4b: the slice's catalog content - game/data/bodies/*.tres, game/data/parts/*.tres and
# game/data/enemies/dozer_cook.tres - plus ChCatalog.load_default(), which scans the two def
# folders. Only the numbers a later task cannot re-derive from code are pinned here: the ones
# the plan's placeholder table and Global Constraints fix.


const PART_IDS: Array[StringName] = [
	&"ice_cream_mace", &"cutter_chainsaw", &"flamethrower", &"hearth", &"cutter_rocket",
	&"corsair_harpoon", &"ember_battery", &"firebolt_launcher", &"ring_of_fire",
	&"freeze_charge", &"wheel", &"strut",
]
const BODY_IDS: Array[StringName] = [&"cutter", &"dozer", &"corsair"]


func test_all_ids_load() -> void:
	var catalog := ChCatalog.load_default()
	var missing_parts: Array[StringName] = []
	for part_id in PART_IDS:
		# part() and body() answer null for an id the catalog does not hold.
		if catalog.part(part_id) == null:
			missing_parts.append(part_id)
	var missing_bodies: Array[StringName] = []
	for body_id in BODY_IDS:
		if catalog.body(body_id) == null:
			missing_bodies.append(body_id)
	assert_eq(missing_parts, [], "every slice part id has a def")
	assert_eq(missing_bodies, [], "every slice body id has a def")
	# The counts catch a def filed under an id these lists do not name.
	assert_eq(catalog.parts.size(), 12, "12 part defs on disk")
	assert_eq(catalog.bodies.size(), 3, "3 body defs on disk")
	_complete()


func test_spec_numbers() -> void:
	var catalog := ChCatalog.load_default()
	var dozer: ChBodyDef = catalog.body(&"dozer")
	assert_true(dozer != null, "the Dozer def loads")
	assert_eq(dozer.hp, 500, "Dozer HP 500")
	assert_eq(dozer.energy_cap, 20, "Dozer energy cap 20")
	assert_eq(dozer.energy_regen, 5.0, "Dozer regen 5/s")
	var corsair: ChBodyDef = catalog.body(&"corsair")
	assert_true(corsair != null, "the Corsair def loads")
	assert_eq(corsair.hp, 600, "Corsair HP 600")
	assert_eq(corsair.energy_cap, 24, "Corsair energy cap 24")
	# Costs follow the CATS rule in Global Constraints: power 5 -> 1 energy, power 10 -> 2.
	assert_eq(catalog.part(&"ice_cream_mace").energy_cost, 1, "mace costs 1")
	assert_eq(catalog.part(&"cutter_chainsaw").energy_cost, 2, "chainsaw costs 2")
	assert_eq(catalog.part(&"ring_of_fire").energy_cost, 4, "Ring of Fire costs 4")
	assert_eq(catalog.part(&"firebolt_launcher").charges, 5, "Firebolt has 5 charges per fight")
	assert_eq(catalog.part(&"strut").extension_slots.size(), 2, "the Strut carries 2 extension slots")
	_complete()


# place() records an id without looking one up, and accepts a slot index no def owns, so a
# mistyped path in the enemy .tres mounts silently. Walking all_paths() catches it: an index
# outside the def's range answers ZERO at anchor_of, and a part whose def is missing answers
# null here. No slot of any slice body sits at (0,0), so ZERO means unresolved for a path.
# all_paths() hands back untyped arrays; get_node and anchor_of take Array[int].
func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func test_enemy_layout_valid() -> void:
	var catalog := ChCatalog.load_default()
	var layout: ChChariotLayout = load("res://game/data/enemies/dozer_cook.tres")
	assert_true(layout != null, "the enemy layout loads")
	assert_eq(layout.body_id, &"dozer", "the enemy sits on the Dozer")
	# anchor_of reads the body def, so an id the catalog cannot place is a broken build.
	assert_true(catalog.body(layout.body_id) != null, "and the catalog can place that body")
	var paths := layout.all_paths()
	assert_eq(paths.size(), 5, "2 wheels + hearth + harpoon + mace are mounted")
	var wheels := 0
	for path in paths:
		var steps := _typed_path(path)
		var node: ChSlotNode = layout.get_node(steps)
		# A path all_paths gave has a node by construction; the check keeps a broken tree
		# reporting a failure instead of aborting the body.
		assert_true(node != null, "%s has a node" % [steps])
		if node == null:
			continue
		assert_true(catalog.part(node.part_id) != null, "%s resolves to a def" % node.part_id)
		# A path whose indices no def owns has no position: the anchor reads ZERO.
		assert_true(layout.anchor_of(steps, catalog) != Vector2.ZERO, "%s lands on a real slot" % [steps])
		if node.part_id == &"wheel":
			wheels += 1
	assert_eq(wheels, 2, "the build has exactly 2 wheels, low and exposed")
	_complete()
