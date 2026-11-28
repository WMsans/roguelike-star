extends ChTest

# Task 1: every part def on disk must match its row in docs/design-doc/parts-list.md.
# Rows whose id has no .tres yet are skipped (the def is not built yet), so the test grows
# greener as each batch adds its parts and turns fully green once all 169 exist (Task 24).
# Name: test_every_def_on_disk_matches_its_row.

const LIST := "res://docs/design-doc/parts-list.md"
const DIR := "res://game/data/parts/"

var mismatches: Array = []

func test_every_def_on_disk_matches_its_row() -> void:
	var f := FileAccess.open(LIST, FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var text := bytes.get_string_from_utf8()
	var lines := text.split("\n")
	var checked := 0
	for line in lines:
		var row := _parse_row(line)
		if row.size() == 0:
			continue
		var id := _id_of(String(row.get("name")))
		var path: String = "%s%s.tres" % [DIR, id]
		var def: ChPartDef = ResourceLoader.load(path) as ChPartDef
		if def == null:
			continue
		if def.id != id:
			mismatches.append("%s: def.id %s, want %s" % [row.get("name"), def.id, id])
		checked += 1
		_check_rarity(row, def)
		_check_tags(row, def)
		_check_energy(row, def)
		_check_mode(row, def)
		_check_integrity(row, def)
		_check_range(row, def)
		_check_ext(row, def)
		_check_description(row, def)
	if mismatches.size() > 0:
		_record("test_every_def_on_disk_matches_its_row: %d def(s) drift from their rows:\n%s" % [mismatches.size(), "\n".join(mismatches)], "")
	else:
		print("parts list: %d def(s) on disk match their rows" % checked)
	_complete()

# The id is the snake_case of the Name column: spaces and hyphens become underscores and an
# apostrophe is dropped, which is how Trade-In Coupon and Collector's Shelf got their ids.
func _id_of(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")

func _parse_row(line: String) -> Dictionary:
	var cells := line.split("|")
	if cells.size() < 10:
		return {}
	var id := String(cells[1]).strip_edges()
	if not id.is_valid_identifier() or id.length() < 2:
		return {}
	var prefix := String(id.substr(0, 1))
	if prefix != "C" and prefix != "U" and prefix != "R":
		return {}
	return {
		"rarity": prefix,
		"name": String(cells[2]).strip_edges(),
		"tags": String(cells[3]).strip_edges(),
		"en": String(cells[4]).strip_edges(),
		"cd": String(cells[5]).strip_edges(),
		"int": String(cells[6]).strip_edges(),
		"rng": String(cells[7]).strip_edges(),
		"ext": String(cells[8]).strip_edges(),
		"effect": String(cells[9]).strip_edges(),
	}

func _check_rarity(row: Dictionary, def: ChPartDef) -> void:
	var want: StringName
	match row.get("rarity"):
		"C": want = &"common"
		"U": want = &"uncommon"
		"R": want = &"rare"
	if def.rarity != want:
		mismatches.append("%s: rarity %s, want %s" % [row.get("name"), def.rarity, want])

func _check_tags(row: Dictionary, def: ChPartDef) -> void:
	var want: Array = []
	for tag in String(row.get("tags")).split(","):
		var t := String(tag).strip_edges().to_lower()
		if t != "":
			want.append(t)
	if def.tags.size() != want.size():
		mismatches.append("%s: tags %s, want %s" % [row.get("name"), def.tags, want])
		return
	for t in want:
		if not def.tags.has(t):
			mismatches.append("%s: tags %s, want %s" % [row.get("name"), def.tags, want])
			return

func _check_energy(row: Dictionary, def: ChPartDef) -> void:
	var en := String(row.get("en"))
	if en.ends_with("/s"):
		var want := en.substr(0, en.length() - 2).strip_edges().to_float()
		if def.energy_per_second != want:
			mismatches.append("%s: energy_per_second %s, want %s (En %s)" % [row.get("name"), def.energy_per_second, want, en])
		if def.energy_cost != 0:
			mismatches.append("%s: energy_cost %d, want 0 for a /s cell" % [row.get("name"), def.energy_cost])
	else:
		# U63's cell says `all`: the whole pool is spent, and the brief fixes energy_cost = 1, the
		# minimum to join a volley. Only that one word is spelled out; to_int() would read it as 0.
		var want := 1 if en == "all" else en.to_int()
		if def.energy_cost != want:
			mismatches.append("%s: energy_cost %d, want %d" % [row.get("name"), def.energy_cost, want])
		if def.energy_per_second != 0.0:
			mismatches.append("%s: energy_per_second %s, want 0 for a plain En cell" % [row.get("name"), def.energy_per_second])

func _check_mode(row: Dictionary, def: ChPartDef) -> void:
	var cd := String(row.get("cd"))
	var tags := def.tags
	var want_mode: StringName
	var want_cooldown := 0.0
	if cd == "Melee":
		want_mode = ChPartDef.MODE_MELEE
	elif cd == "Beam":
		want_mode = ChPartDef.MODE_BEAM
	elif cd == "—":
		want_mode = ChPartDef.MODE_WHEEL if tags.has("wheel") else ChPartDef.MODE_PASSIVE
	else:
		want_mode = ChPartDef.MODE_COOLDOWN
		want_cooldown = cd.to_float()
	if def.mode != want_mode:
		mismatches.append("%s: mode %s, want %s" % [row.get("name"), def.mode, want_mode])
	if def.cooldown != want_cooldown:
		mismatches.append("%s: cooldown %s, want %s" % [row.get("name"), def.cooldown, want_cooldown])

func _check_integrity(row: Dictionary, def: ChPartDef) -> void:
	var want := String(row.get("int")).to_int()
	if def.integrity != want:
		mismatches.append("%s: integrity %d, want %d" % [row.get("name"), def.integrity, want])

func _check_range(row: Dictionary, def: ChPartDef) -> void:
	var rng := String(row.get("rng"))
	var want := 0.0
	if rng == "S":
		want = 12.0
	elif rng == "M":
		want = 20.0
	elif rng == "L":
		want = 32.0
	if def.proximity_range != want:
		mismatches.append("%s: proximity_range %s, want %s" % [row.get("name"), def.proximity_range, want])

func _check_ext(row: Dictionary, def: ChPartDef) -> void:
	var ext := String(row.get("ext"))
	var want := 0
	if ext != "—":
		want = ext.to_int()
	if def.extension_slots.size() != want:
		mismatches.append("%s: extension_slots %d, want %d" % [row.get("name"), def.extension_slots.size(), want])

func _check_description(row: Dictionary, def: ChPartDef) -> void:
	# The def's line is the Effect cell with its keywords marked up, so both sides are stripped before
	# they are compared (ChKeywords' rule: the markup is the only difference).
	var stripped := _strip_markup(String(row.get("effect")))
	var want := def.description
	if want.size() != 1 or _strip_markup(want[0]) != stripped:
		mismatches.append("%s: description %s, want single entry %s" % [row.get("name"), def.description, stripped])

func _strip_markup(text: String) -> String:
	var out := ""
	var at := 0
	var re := RegEx.create_from_string("\\{([a-z_]+)(?::([^}]*))?\\}")
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var shown := m.get_string(2)
		if shown != "":
			out += shown
		else:
			out += ChKeywords.name_of(StringName(m.get_string(1)))
	out += text.substr(at)
	return out

# Task 24: every row in the list has its def and a behaviour, so the list is whole at 169.
func test_every_listed_part_exists() -> void:
	var f := FileAccess.open(LIST, FileAccess.READ)
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var text := bytes.get_string_from_utf8()
	var missing: Array = []
	var seen := {}
	for line in text.split("\n"):
		var row := _parse_row(line)
		if row.size() == 0:
			continue
		var id := _id_of(String(row.get("name")))
		seen[id] = true
		var path: String = "%s%s.tres" % [DIR, id]
		if not ResourceLoader.exists(path):
			missing.append("%s: no %s" % [id, path])
			continue
		var def: ChPartDef = ResourceLoader.load(path) as ChPartDef
		if def == null or def.behaviour == null:
			missing.append("%s: no behaviour" % id)
	assert_eq(missing, [], "every listed part has a def and a behaviour")
	assert_eq(seen.size(), 169, "the list names 169 parts")
	_complete()


# Task 1: a wheel's def sets the motor rad/s at full drive.
func test_wheel_reads_its_speed() -> void:
	var world: PixelWorld = await make_world()
	world.fill_rect(Rect2i(0, 160, 480, 20), &"rock")
	var def := ChPartDef.new()
	def.id = &"t_wheel"
	def.tags = PackedStringArray(["passive", "wheel"])
	def.mode = ChPartDef.MODE_WHEEL
	def.energy_per_second = 1.0
	def.wheel_speed = 6.0
	def.size = Vector2i(2, 2)
	def.charges = -1
	var body := ChBodyDef.new()
	body.id = &"rig"
	body.hp = 100
	body.energy_cap = 20
	body.energy_regen = 4.0
	body.size = Vector2i(10, 6)
	body.slots = PackedVector2Array([Vector2(0, 0)])
	var catalog := ChCatalog.from_defs([def], [body])
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	assert_true(layout.place([0], &"t_wheel"), "the wheel mounts")
	var runtime := ChChariotBuilder.build(world, _parent(), layout, catalog, 0, Vector2(120, 140), false)
	assert_true(runtime != null, "the chariot builds")
	var wheels := runtime.wheels()
	assert_eq(wheels.size(), 1, "one wheel is mounted")
	runtime.drive(1.0)
	assert_near(wheels[0].joint.motor_speed, 6.0, 0.001, "the motor runs at the def's wheel_speed")
	_complete()
