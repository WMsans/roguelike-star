extends ChTest

# Task 4b: the slice's catalog content - game/data/bodies/*.tres, game/data/parts/*.tres and
# game/data/enemies/dozer_cook.tres - plus ChCatalog.load_default(), which scans the two def
# folders. Only the numbers a later task cannot re-derive from code are pinned here: the ones
# the plan's placeholder table and Global Constraints fix.


const PART_IDS: Array[StringName] = [
	# Task 5's common parts (C01-C15, C36-C43).
	&"rocket_pod", &"cannon", &"chainsaw", &"drill", &"stinger", &"spinning_blade",
	&"laser", &"shotgun", &"minigun", &"bayonet", &"steel_plate", &"shield_generator",
	&"bumper", &"plating_rig", &"first_aid_kit", &"spare_cell", &"generator",
	&"reinforced_frame", &"roller", &"bigfoot", &"sticky_tire", &"long_arm",
	# Task 6's common elemental and support parts (C16-C35).
	&"molotov", &"igniter", &"frost_sprayer", &"water_cannon", &"ice_pick",
	&"zap_gun", &"battery_dropper", &"lightning_rod", &"acid_squirter", &"acid_dripper",
	&"dynamite_toss", &"gunpowder_hopper", &"sandbag", &"fan", &"smoke_bomb",
	&"turbo_booster", &"targeting_computer", &"sharpener", &"heavy_rounds",
	# The two whose ids the retired parts also used: the C42 Strut and the C16 Flamethrower.
	&"strut", &"flamethrower",
	# Task 8's Inferno parts (U01-U06, R01-R03).
	&"oil_sprayer", &"fuel_line", &"heat_shield", &"incinerator", &"napalm_launcher",
	&"bellows", &"inferno_core", &"eternal_flame", &"pyre",
	# Task 9's Deep Freeze parts (U07-U13, R04-R06).
	&"rainmaker", &"cryo_cannon", &"icebreaker", &"antifreeze_coat", &"cold_snap",
	&"freeze_ray", &"ice_scope", &"absolute_zero", &"permafrost", &"glacier_engine",
	# Task 10's Steam parts (U69-U72, R31).
	&"boiler", &"pressure_valve", &"thermal_shock_gun", &"condenser", &"steam_engine",
	# Task 11's Shock Chain parts (U14-U19, R07-R09).
	&"tesla_coil", &"chain_lightning", &"ball_lightning", &"capacitor", &"wet_wire",
	&"grounding_spike", &"storm_core", &"lightning_bolt", &"superconductor",
	# Task 12's Acid Eater parts (U20-U24, R10-R11).
	&"acid_cannon", &"corroder", &"acid_gas_vent", &"etching_ray", &"sinkhole_flask",
	&"universal_solvent", &"matter_eater",
	# Task 13's Fortress parts (U25-U30, R12-R14).
	&"spiked_shield", &"shield_battery", &"rampart", &"bunker_frame", &"compound_plating",
	&"thermal_plating", &"aegis_mirror", &"iron_will", &"citadel",
	# Task 14's Thorns parts (U82-U85, R35-R36).
	&"spiked_armour", &"reactive_plate", &"shock_plate", &"mirror_plating", &"retribution",
	&"guardian_core",
	# Task 15's Last Stand parts (U78-U81, R34).
	&"adrenaline_injector", &"emergency_plating", &"berserker_chip", &"last_rites", &"death_wish",
	# Task 16's Grinder parts (U31-U36, R15-R17).
	&"buzzsaw_arm", &"hot_teeth", &"gear_train", &"heavy_grinder", &"rotary_drill",
	&"overdrive_clutch", &"meshing_gearbox", &"bloodsaw", &"grinding_engine",
	# Task 17's Rammer parts (U73-U77, R32-R33).
	&"ram_spike", &"booster_rocket", &"pogo_spring", &"spiked_wheel", &"harpoon",
	&"juggernaut", &"wrecking_gear",
	# Task 18's Sniper parts (U37-U41, R18-R19).
	&"railgun", &"focus_lens", &"rangefinder", &"stabiliser", &"long_barrel",
	&"distance_lens", &"piercing_railgun",
	# Task 19's Demolition parts (U42-U47, R20-R22).
	&"tnt_launcher", &"detonator", &"blast_shield", &"demolition_charge", &"mine_layer",
	&"excavator", &"chain_detonator", &"earthquake", &"blast_amplifier",
	# Task 20's Gale parts (U48-U52, R23-R24).
	&"gust_cannon", &"smokestack", &"turbine", &"steam_vent", &"weather_vane",
	&"toxic_tempest", &"stormfront",
	# Task 21's Overclock parts (U53-U58, R25-R26).
	&"overclocker", &"gear_linkage", &"momentum_hammer", &"coolant_pump", &"pulse_gun",
	&"static_gears", &"perpetual_gear", &"overdrive",
	# Task 22's Reactor parts (U59-U63, R27-R28).
	&"overflow_valve", &"priority_relay", &"dynamo_wheel", &"power_siphon", &"surge_cannon",
	&"fusion_core", &"blood_cell",
	# Task 23's Merchant parts (U64-U68, R29-R30).
	&"piggy_bank", &"scrap_cannon", &"safe", &"trade_in_coupon", &"collectors_shelf",
	&"golden_gear", &"bench_warmer",
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
	assert_eq(catalog.parts.size(), PART_IDS.size(), "%d part defs on disk" % PART_IDS.size())
	assert_eq(catalog.bodies.size(), 3, "3 body defs on disk")
	_complete()


func test_spec_numbers() -> void:
	var catalog := ChCatalog.load_default()
	var cutter: ChBodyDef = catalog.body(&"cutter")
	assert_true(cutter != null, "the Cutter def loads")
	var dozer: ChBodyDef = catalog.body(&"dozer")
	assert_true(dozer != null, "the Dozer def loads")
	# The parts-list §1.1 scale (Task 7): HP about 800, energy about 20, regen about 4/s.
	assert_eq(cutter.hp, 750, "Cutter HP 750")
	assert_eq(cutter.energy_cap, 18, "Cutter energy cap 18")
	assert_eq(cutter.energy_regen, 4.0, "Cutter regen 4/s")
	assert_eq(dozer.hp, 900, "Dozer HP 900")
	assert_eq(dozer.energy_cap, 20, "Dozer energy cap 20")
	assert_eq(dozer.energy_regen, 4.0, "Dozer regen 4/s")
	var corsair: ChBodyDef = catalog.body(&"corsair")
	assert_true(corsair != null, "the Corsair def loads")
	assert_eq(corsair.hp, 1000, "Corsair HP 1000")
	assert_eq(corsair.energy_cap, 22, "Corsair energy cap 22")
	assert_eq(corsair.energy_regen, 4.5, "Corsair regen 4.5/s")
	# part() answers null for an id the catalog does not hold, so each def is bound and asserted
	# before its properties are read: chaining onto null aborts the body with a null-access error
	# that names no def, which is what the Cutter/Dozer/Corsair guards above already do.
	var strut: ChPartDef = catalog.part(&"strut")
	assert_true(strut != null, "the strut def loads")
	assert_eq(strut.extension_slots.size(), 1, "the Strut carries 1 extension slot")
	_complete()


# Rarity is what a part costs in the shop (ChPrices.price) and tags are what its theme rolls pick
# from, so a def that ships without either cannot be offered. The values are the spec's table
# (docs/superpowers/specs/2026-11-12-run-shop-and-card-feel-design.md, "Part data (designer's calls)").
func test_every_part_has_rarity_and_tags() -> void:
	var catalog := ChCatalog.load_default()
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		assert_true(def.rarity in [&"common", &"uncommon", &"rare"], "%s has a rarity" % id)
		assert_true(def.tags.size() > 0, "%s has tags" % id)
	# Spot-checks on the table: an unset field would answer the def's default here rather than the id.
	var flame: ChPartDef = catalog.part(&"flamethrower")
	assert_true(flame != null, "the Flamethrower def loads")
	if flame != null:
		assert_eq(flame.rarity, &"common", "the Flamethrower is common")
		for tag in ["fire", "weapon", "beam"]:
			assert_true(flame.tags.has(tag), "the Flamethrower is tagged %s" % tag)
	var rocket: ChPartDef = catalog.part(&"rocket_pod")
	assert_true(rocket != null, "the Rocket Pod def loads")
	if rocket != null:
		assert_eq(rocket.rarity, &"common", "the Rocket Pod is common")
	var strut: ChPartDef = catalog.part(&"strut")
	assert_true(strut != null, "the Strut def loads")
	if strut != null:
		assert_true(strut.tags.has("stats"), "the Strut is a stats part")
	_complete()


# Task 1 (Stage 3): every part says how it fires. mode is one of ChPartDef's five constants, the
# wheel tag is what makes a part a wheel, and is_continuous is the mode's own question.
func test_every_part_has_a_mode() -> void:
	var catalog := ChCatalog.load_default()
	var modes := [ChPartDef.MODE_COOLDOWN, ChPartDef.MODE_MELEE, ChPartDef.MODE_BEAM,
		ChPartDef.MODE_PASSIVE, ChPartDef.MODE_WHEEL]
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		assert_true(def.mode in modes, "%s has one of the five modes" % id)
		assert_eq(def.is_wheel(), def.mode == ChPartDef.MODE_WHEEL,
			"%s: the wheel tag holds exactly when the mode is wheel" % id)
		assert_eq(def.is_continuous(), def.mode == ChPartDef.MODE_MELEE or def.mode == ChPartDef.MODE_BEAM,
			"%s: is_continuous matches the mode" % id)
		# A cooldown part is what the volley fires, so it needs a cooldown to gate it. A continuous
		# part is what the hold runs, so it must not also be fired by a press: that would pay it twice.
		if def.mode == ChPartDef.MODE_COOLDOWN:
			assert_true(def.cooldown > 0.0, "%s: a cooldown part has a cooldown" % id)
		elif def.mode == ChPartDef.MODE_MELEE or def.mode == ChPartDef.MODE_BEAM:
			assert_eq(def.cooldown, 0.0, "%s: a continuous part has no cooldown" % id)
	_complete()


# The reach the driver closes with is ChPartDef.reach, not proximity_range: a weapon's reach is the
# distance it strikes, and only a part that is not a weapon keeps the two equal.
func test_reach_matches_proximity_range_outside_weapons() -> void:
	var catalog := ChCatalog.load_default()
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		if def.damage <= 0 or def.cooldown <= 0.0:
			# A passive (Freeze Charge, Ember Battery, Strut) or a wheel brought nothing to bear
			# before, so its reach stays 0 whatever its proximity_range is.
			continue
		if def.tags.has("melee") or def.tags.has("beam"):
			# Task 5: a melee or beam weapon's reach is the distance it strikes, not a proximity
			# range, so the two fields are free to differ (the Stinger reaches 48 with no chain).
			continue
		assert_near(def.reach, def.proximity_range, 0.001, "%s reach equals its proximity_range" % id)
	_complete()


func test_body_rarities() -> void:
	# Bodies are bought the same way parts are, so each carries a rarity too: Cutter common,
	# Dozer uncommon, Corsair rare.
	var catalog := ChCatalog.load_default()
	for pair in [[&"cutter", &"common"], [&"dozer", &"uncommon"], [&"corsair", &"rare"]]:
		var body: ChBodyDef = catalog.body(pair[0])
		assert_true(body != null, "%s loads" % pair[0])
		if body != null:
			assert_eq(body.rarity, pair[1], "%s is %s" % [pair[0], pair[1]])
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
		if node.part_id == &"roller":
			wheels += 1
			# The wheels sit low and exposed: their anchor y matches the body's lowest slots, so
			# moving a wheel to a higher slot index fails here instead of only counting wheels.
			assert_near(anchor.y, lowest_slot_y, 0.001,
				"%s sits on one of the body's lowest slots" % steps)
			# And that slot is on the hull's bottom edge (ch_body_def.gd's header: a wheel inside
			# the edge leaves the hull on the sand).
			assert_near(anchor.y, _bottom_at(body_def, anchor.x), 0.5,
				"%s sits on the hull's bottom edge" % steps)
		elif node.part_id == &"rocket_pod" or node.part_id == &"igniter" \
				or node.part_id == &"shield_generator":
			# ChBodyDef.slots say +x is forward, so these three sit on the front half of the hull;
			# the two Molotovs stay behind them and get no assertion.
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
	# Spec §2: the cook's kit is a brawler's, so it drives the Barge. Task 7 rebuilds it from list
	# parts: two Molotovs on the rear top slots, a Rocket Pod, an Igniter and a Shield Generator in
	# front (+x is forward; the battle mirrors the enemy so its front faces the player).
	var catalog := ChCatalog.load_default()
	var layout: ChChariotLayout = load("res://game/data/enemies/dozer_cook.tres")
	assert_eq(layout.body_id, &"corsair", "the cook drives a Corsair")
	# The HP is the run's fight-0 enemy HP (ChRun.FIRST_HP), re-tuned with the smoke suite; see
	# tools/balance/README.md's tuning table.
	assert_eq(layout.max_hp, ChRun.FIRST_HP, "the cook has the run's fight-0 HP")
	var body: ChBodyDef = catalog.body(layout.body_id)
	var wheels := _wheel_slots(body)
	var tops: Array[int] = []
	for i in body.slots.size():
		if not wheels.has(i):
			tops.append(i)
	tops.sort_custom(func(a: int, b: int) -> bool: return body.slots[a].x > body.slots[b].x)
	var front: Array[String] = []
	for i in tops.slice(0, 2):
		var node: ChSlotNode = layout.get_node(_typed_path([i]))
		front.append(String(node.part_id) if node != null else "")
	front.sort()
	assert_eq(front, ["igniter", "shield_generator"],
		"the Igniter and the Shield Generator on the front top slots")
	for i in wheels:
		var node: ChSlotNode = layout.get_node(_typed_path([i]))
		assert_true(node != null and node.part_id == &"roller", "roller on slot %d" % i)
	_complete()


func test_every_part_described() -> void:
	var catalog := ChCatalog.load_default()
	assert_eq(catalog.parts.size(), PART_IDS.size(), "the slice's %d parts" % PART_IDS.size())
	for id in catalog.parts:
		var def: ChPartDef = catalog.parts[id]
		assert_true(def.description.size() > 0, "%s has a description" % id)
		for line in def.description:
			assert_eq(ChKeywords.parse(line).unknown, [], "%s: every tag resolves" % id)
			assert_true(not line.begins_with("•"), "%s: the tooltip adds the bullet" % id)
	assert_eq(ChKeywords.keys_of(catalog.part(&"flamethrower").description), [&"flame"])
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
		# Task 5: a def with no sprite draws the flat placeholder, so only the art that exists is
		# held to the placeholder's silhouette.
		if def.texture == null:
			continue
		var want: Image
		if def is ChBodyDef:
			want = ChTextures.polygon(def.outline, def.size, Color.BLACK).get_image()
		elif def.id == &"roller":
			want = ChTextures.disc(def.size.x, Color.BLACK).get_image()
		else:
			want = ChTextures.box(def.size.x, def.size.y, Color.BLACK).get_image()
		var got: Image = def.texture.get_image()
		# A hand sprite's art has a transparent background; its body collides as ChTextures.solid(art).
		if def is ChPartDef and def.id != &"roller":
			got = ChTextures.solid(got).get_image()
		assert_eq(got.get_size(), want.get_size(), "%s sprite is its def's size" % def.id)
		var off := 0
		for y in mini(got.get_height(), want.get_height()):
			for x in mini(got.get_width(), want.get_width()):
				if (got.get_pixel(x, y).a > 0.5) != (want.get_pixel(x, y).a > 0.0):
					off += 1
		assert_eq(off, 0, "%s sprite is solid where its placeholder is" % def.id)
	_complete()
