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
	# The demo balance pass (docs/superpowers/handoffs/2026-11-07-demo-balance-handoff.md): caps and
	# regen small enough that a full loadout runs short of energy. HP and regen were re-tuned for the
	# press volley and the body shapes (button-and-bodies Task 9, same handoff, "Re-balance for presses").
	assert_eq(dozer.hp, 700, "Dozer HP 700")
	assert_eq(dozer.energy_cap, 14, "Dozer energy cap 14")
	assert_eq(dozer.energy_regen, 3.0, "Dozer regen 3/s")
	var corsair: ChBodyDef = catalog.body(&"corsair")
	assert_true(corsair != null, "the Corsair def loads")
	assert_eq(corsair.hp, 900, "Corsair HP 900")
	assert_eq(corsair.energy_cap, 12, "Corsair energy cap 12")
	assert_eq(corsair.energy_regen, 3.25, "Corsair regen 3.25/s")
	# Costs started on the CATS rule in Global Constraints (power 5 -> 1 energy, power 10 -> 2); the
	# balance pass moved the Chainsaw and the Ring to their measured damage per energy.
	# part() answers null for an id the catalog does not hold, so each def is bound and asserted
	# before its properties are read: chaining onto null aborts the body with a null-access error
	# that names no def, which is what the Dozer/Corsair guards above already do.
	var mace: ChPartDef = catalog.part(&"ice_cream_mace")
	assert_true(mace != null, "the mace def loads")
	assert_eq(mace.energy_cost, 1, "mace costs 1")
	var chainsaw: ChPartDef = catalog.part(&"cutter_chainsaw")
	assert_true(chainsaw != null, "the chainsaw def loads")
	assert_eq(chainsaw.energy_cost, 1, "chainsaw costs 1")
	var ring: ChPartDef = catalog.part(&"ring_of_fire")
	assert_true(ring != null, "the Ring of Fire def loads")
	assert_eq(ring.energy_cost, 3, "Ring of Fire costs 3")
	var firebolt: ChPartDef = catalog.part(&"firebolt_launcher")
	assert_true(firebolt != null, "the Firebolt launcher def loads")
	assert_eq(firebolt.charges, 5, "Firebolt has 5 charges per fight")
	var strut: ChPartDef = catalog.part(&"strut")
	assert_true(strut != null, "the strut def loads")
	assert_eq(strut.extension_slots.size(), 2, "the Strut carries 2 extension slots")
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
	assert_eq(layout.body_id, &"corsair", "the enemy sits on the Corsair (a Barge)")
	# anchor_of reads the body def, so an id the catalog cannot place is a broken build.
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	assert_true(body_def != null, "and the catalog can place that body")
	# The assert above recorded why; stop before reading the def's slots so the run reports the
	# failure instead of dying on a null access.
	if body_def == null:
		return
	# ChBodyDef.slots are body-local cells with +y down, so the largest y is the lowest slot and
	# the wheels have to sit there. Read off the def rather than a literal, so a re-tuned body
	# still has to keep its wheels on whatever slots sit lowest.
	# shortcut: -INF seeds the scan; a body with no slots leaves it, so every wheel anchor below
	# fails and says why. No slice body has an empty slot table.
	var lowest_slot_y: float = -INF
	for slot in body_def.slots:
		if slot.y > lowest_slot_y:
			lowest_slot_y = slot.y
	var paths := layout.all_paths()
	assert_eq(paths.size(), 7, "2 wheels + 2 firebolts + 2 hearths + harpoon are mounted")
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
		var anchor := layout.anchor_of(steps, catalog)
		# A path whose indices no def owns has no position: the anchor reads ZERO.
		assert_true(anchor != Vector2.ZERO, "%s lands on a real slot" % [steps])
		if node.part_id == &"wheel":
			wheels += 1
			# The wheels sit low and exposed: their anchor y matches the body's lowest slots, so
			# moving a wheel to a higher slot index fails here instead of only counting wheels.
			assert_near(anchor.y, lowest_slot_y, 0.001,
				"%s sits on one of the body's lowest slots" % steps)
			# And that slot is on the hull's bottom edge (ch_body_def.gd's header: a wheel inside
			# the edge leaves the hull on the sand).
			assert_near(anchor.y, _bottom_at(body_def, anchor.x), 0.5,
				"%s sits on the hull's bottom edge" % steps)
		elif node.part_id == &"corsair_harpoon" or node.part_id == &"ice_cream_mace":
			# ChBodyDef.slots say +x is forward, so these two sit on the front half of the hull;
			# the hearth stays behind them and gets no assertion.
			assert_true(anchor.x > 0.0, "%s mounts facing forward" % node.part_id)
	assert_eq(wheels, 2, "the build has exactly 2 wheels, low and exposed")
	_complete()


func _bottom_at(body: ChBodyDef, x: float) -> float:
	# The outline's largest y (+y is down) on the vertical line at x: the hull's bottom edge there.
	# An empty outline is the size box. -INF when x misses the hull, so the caller's assert fails.
	if body.outline.is_empty():
		return body.size.y * 0.5 if absf(x) <= body.size.x * 0.5 else -INF
	var best := -INF
	for i in body.outline.size():
		var a: Vector2 = body.outline[i]
		var b: Vector2 = body.outline[(i + 1) % body.outline.size()]
		if x < minf(a.x, b.x) or x > maxf(a.x, b.x):
			continue
		best = maxf(best, maxf(a.y, b.y) if a.x == b.x else lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best


func _wheel_slots(body: ChBodyDef) -> Array[int]:
	# The two lowest slots are the wheel mounts (ch_body_def.gd's header).
	var order: Array[int] = []
	for i in body.slots.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return body.slots[a].y > body.slots[b].y)
	return order.slice(0, 2)


func test_spec_bodies() -> void:
	# The bodies spec's roster (§2): each body's type, its AI drive style and its slot count. The
	# count is kept from the box bodies, so layouts that address slots by index still load.
	var want := {
		&"cutter": ["Wedge", &"brawler", 4],
		&"dozer": ["Tower", &"kiter", 6],
		&"corsair": ["Barge", &"brawler", 7],
	}
	var catalog := ChCatalog.load_default()
	for id in want:
		var body: ChBodyDef = catalog.body(id)
		assert_true(body != null, "%s loads" % id)
		if body == null:
			continue
		assert_eq(body.type_name, want[id][0], "%s type" % id)
		assert_eq(body.drive_style, want[id][1], "%s drive style" % id)
		assert_eq(body.slots.size(), want[id][2], "%s slot count" % id)
		assert_true(not body.outline.is_empty(), "%s has an outline" % id)
		for i in _wheel_slots(body):
			assert_near(body.slots[i].y, _bottom_at(body, body.slots[i].x), 0.5,
				"%s wheel slot %d sits on the bottom edge" % [id, i])
	_complete()


func test_slots_inside_outline() -> void:
	# A slot off the hull would hang its part in the air beside it: every slot is inside the
	# outline or within one cell of its edge.
	for body in ChCatalog.load_default().bodies.values():
		for i in body.slots.size():
			var at: Vector2 = body.slots[i]
			var near := Geometry2D.is_point_in_polygon(at, body.outline)
			for e in body.outline.size():
				var closest := Geometry2D.get_closest_point_to_segment(at, body.outline[e],
					body.outline[(e + 1) % body.outline.size()])
				near = near or at.distance_to(closest) <= 1.0
			assert_true(near, "%s slot %d %s is on the hull" % [body.id, i, at])
	_complete()


func test_cook_is_a_barge() -> void:
	# Spec §2: the cook's kit is a brawler's, so it drives the Barge with its two Hearths on the two
	# frontmost top slots (+x is forward; the battle mirrors the enemy so its front faces the player).
	var catalog := ChCatalog.load_default()
	var layout: ChChariotLayout = load("res://game/data/enemies/dozer_cook.tres")
	assert_eq(layout.body_id, &"corsair", "the cook drives a Corsair")
	# 1800 was the auto-fire number; presses fire less often, so Task 9 re-tuned it to 700, and the
	# cook-and-arena tune (two Firebolts on [2]/[3], a second Hearth for the Mace, tools/balance/README.md)
	# to 1500 with the runner.
	assert_eq(layout.max_hp, 1500, "the cook has its re-tuned 1500 HP")
	var body: ChBodyDef = catalog.body(layout.body_id)
	var wheels := _wheel_slots(body)
	var tops: Array[int] = []
	for i in body.slots.size():
		if not wheels.has(i):
			tops.append(i)
	tops.sort_custom(func(a: int, b: int) -> bool: return body.slots[a].x > body.slots[b].x)
	var front: Array[StringName] = []
	for i in tops.slice(0, 2):
		var node: ChSlotNode = layout.get_node(_typed_path([i]))
		front.append(node.part_id if node != null else &"")
	front.sort()
	assert_eq(front, [&"hearth", &"hearth"], "two Hearths on the front top slots")
	for i in wheels:
		var node: ChSlotNode = layout.get_node(_typed_path([i]))
		assert_true(node != null and node.part_id == &"wheel", "wheel on slot %d" % i)
	_complete()


func test_every_part_described() -> void:
	var catalog := ChCatalog.load_default()
	assert_eq(catalog.parts.size(), 12, "the slice's 12 parts")
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		assert_true(def.description.size() > 0, "%s has a description" % id)
		for line in def.description:
			assert_eq(ChKeywords.parse(line).unknown, [], "%s: every tag resolves" % id)
			assert_true(not line.begins_with("•"), "%s: the tooltip adds the bullet" % id)
	assert_eq(ChKeywords.keys_of(catalog.part(&"flamethrower").description), [&"press", &"burn"])
	assert_eq(ChKeywords.keys_of(catalog.part(&"freeze_charge").description), [&"passive", &"proximity", &"freeze"])
	assert_eq(ChKeywords.keys_of(catalog.part(&"ember_battery").description), [&"passive", &"burn", &"energy"])
	_complete()


func test_ember_battery_names_its_cooldown() -> void:
	# Five parts lighting at once pay 3, not 15: the battery's internal cooldown is part of the rule.
	var lines := "\n".join(ChCatalog.load_default().part(&"ember_battery").description)
	assert_true(lines.contains("0.5 s"), "ch_ember_battery.gd's BATTERY_COOLDOWN is stated")
	_complete()


func test_body_copy_keeps_every_field() -> void:
	for body in ChCatalog.load_default().bodies.values():
		var c: ChBodyDef = body.copy()
		for field in ["id", "hp", "outline", "mass", "friction", "restitution", "drive_style", "type_name", "slots"]:
			assert_eq(c.get(field), body.get(field), "%s: copy keeps %s" % [body.id, field])
	_complete()


func test_outline_matches_size() -> void:
	for body in ChCatalog.load_default().bodies.values():
		if body.outline.is_empty():
			continue
		var low: Vector2 = body.outline[0]
		var high: Vector2 = body.outline[0]
		for p in body.outline:
			low = Vector2(minf(low.x, p.x), minf(low.y, p.y))
			high = Vector2(maxf(high.x, p.x), maxf(high.y, p.y))
		assert_eq(high - low, Vector2(body.size), "%s: outline spans size" % body.id)
		assert_eq(low, -Vector2(body.size) * 0.5, "%s: outline is centred" % body.id)
	_complete()


func test_body_copy_keeps_non_default_fields() -> void:
	# The catalog's bodies leave the new fields at their defaults, so this one sets every field to
	# something else: a copy() that dropped any of them would fail here.
	var body := ChBodyDef.new()
	body.id = &"x"
	body.display_name = "X"
	body.hp = 77
	body.energy_cap = 9
	body.energy_regen = 1.5
	body.size = Vector2i(10, 6)
	body.material = &"iron"
	body.color = Color(0.1, 0.2, 0.3)
	body.slots = PackedVector2Array([Vector2(1, 2), Vector2(-3, 4)])
	body.outline = PackedVector2Array([Vector2(-5, 3), Vector2(5, 3), Vector2(-5, -3)])
	body.mass = 50.0
	body.friction = 0.2
	body.restitution = 0.4
	body.drive_style = &"kiter"
	body.type_name = "Wedge"
	var c := body.copy()
	for prop in body.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(c.get(prop.name), body.get(prop.name), "copy keeps %s" % prop.name)
	assert_true(c != body, "copy is a new def")
	_complete()


func test_sprites_keep_the_placeholder_pixels() -> void:
	# Mass and collision come from a body's opaque pixels, so art may recolour a def but never
	# reshape it: every def's texture is solid exactly where its placeholder is.
	var catalog := ChCatalog.load_default()
	var defs: Array = catalog.parts.values() + catalog.bodies.values()
	for def in defs:
		assert_true(def.texture != null, "%s has a sprite" % def.id)
		if def.texture == null:
			continue
		var want: Image
		if def is ChBodyDef:
			want = ChTextures.polygon(def.outline, def.size, Color.BLACK).get_image()
		elif def.id == &"wheel":
			want = ChTextures.disc(def.size.x, Color.BLACK).get_image()
		else:
			want = ChTextures.box(def.size.x, def.size.y, Color.BLACK).get_image()
		var got: Image = def.texture.get_image()
		assert_eq(got.get_size(), want.get_size(), "%s sprite is its def's size" % def.id)
		var off := 0
		for y in mini(got.get_height(), want.get_height()):
			for x in mini(got.get_width(), want.get_width()):
				if (got.get_pixel(x, y).a > 0.5) != (want.get_pixel(x, y).a > 0.0):
					off += 1
		assert_eq(off, 0, "%s sprite is solid where its placeholder is" % def.id)
	_complete()
