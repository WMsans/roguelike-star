class_name ChBalanceScenario extends RefCounted

# JSON scenario -> validated ChBalanceMatchups (spec §5). Written for agents: every problem is
# collected rather than stopping at the first, and each reads "<where>: <field path>: <problem>",
# naming the valid values when a value is unknown, so a typo is fixed in one round trip and no
# fight ever runs on a half-understood scenario.

const SCENARIO_KEYS := ["name", "player", "enemy", "seeds", "drive", "press", "expect"]
const SIDE_KEYS := ["layout", "body_id", "parts", "hp", "plain_hull", "body_type", "body_seed"]
const PART_KEYS := ["slot", "part", "flipped"]
const SUITE_KEYS := ["name", "scenarios"]


static func parse(data: Variant, base: ChCatalog, where: String) -> Dictionary:
	var errors := PackedStringArray()
	var matchups := _scenario(data, base, where, "", errors)
	return _out(errors, matchups)


static func parse_suite(data: Variant, base: ChCatalog, where: String) -> Dictionary:
	# A suite is {"name", "scenarios": [scenario, ...]}; a scenario's errors carry its index.
	var errors := PackedStringArray()
	var matchups: Array[ChBalanceMatchup] = []
	if not data is Dictionary:
		errors.append("%s: suite: must be a JSON object" % where)
		return _out(errors, matchups)
	_unknown_keys(data, SUITE_KEYS, where, "", errors)
	if not (data.get("name") is String and data.get("name") != ""):
		errors.append("%s: name: required, a non-empty string" % where)
	var list = data.get("scenarios")
	if not (list is Array and not list.is_empty()):
		errors.append("%s: scenarios: required, a non-empty list of scenarios" % where)
		return _out(errors, matchups)
	for i in list.size():
		matchups.append_array(_scenario(list[i], base, where, "scenarios[%d]" % i, errors))
	return _out(errors, matchups)


static func _out(errors: PackedStringArray, matchups: Array[ChBalanceMatchup]) -> Dictionary:
	# CONTRACT: no matchups unless every field checked out, so a caller cannot run a partial set.
	var none: Array[ChBalanceMatchup] = []
	return {"ok": errors.is_empty(), "errors": errors, "matchups": matchups if errors.is_empty() else none}


static func _scenario(data: Variant, base: ChCatalog, where: String, root: String,
		errors: PackedStringArray) -> Array[ChBalanceMatchup]:
	var out: Array[ChBalanceMatchup] = []
	var before := errors.size()
	if not data is Dictionary:
		errors.append("%s: %s: must be a JSON object" % [where, root if root != "" else "scenario"])
		return out
	_unknown_keys(data, SCENARIO_KEYS, where, root, errors)
	var name = data.get("name")
	if not (name is String and name != ""):
		errors.append("%s: %s: required, a non-empty string" % [where, _at(root, "name")])
	var seeds := _seeds(data.get("seeds", {}), where, _at(root, "seeds"), errors)
	var drive := _policies(data.get("drive", {}), ChBalanceDrivers.POLICIES, where, _at(root, "drive"), errors)
	var press := _policies(data.get("press", {}), ChBalanceDrivers.PRESS_POLICIES, where, _at(root, "press"), errors)
	var expect := _expect(data.get("expect", {}), where, _at(root, "expect"), errors)
	# Hp overrides collect here; their ids are unique per (body, hp), so one catalog holds them all.
	var extra_bodies: Dictionary = {}
	var players := _sides(data.get("player"), base, where, _at(root, "player"), extra_bodies, errors)
	var enemies := _sides(data.get("enemy"), base, where, _at(root, "enemy"), extra_bodies, errors)
	if errors.size() > before:
		return out
	var parts: Array[ChPartDef] = []
	parts.assign(base.parts.values())
	var bodies: Array[ChBodyDef] = []
	bodies.assign(base.bodies.values())
	bodies.append_array(extra_bodies.values())
	var catalog := ChCatalog.from_defs(parts, bodies)
	var matrix := data.get("player") is Array or data.get("enemy") is Array
	for i in players.size():
		for j in enemies.size():
			var m := ChBalanceMatchup.new()
			m.name = "%s/%dx%d" % [name, i, j] if matrix else name
			m.player = players[i]
			m.enemy = enemies[j]
			m.catalog = catalog
			m.seeds = seeds
			m.drive = drive
			m.press = press
			m.expect = expect
			out.append(m)
	return out


static func _at(root: String, key: String) -> String:
	return key if root == "" else root + "." + key


static func _unknown_keys(data: Dictionary, known: Array, where: String, root: String,
		errors: PackedStringArray) -> void:
	# A misspelt optional field would otherwise be silently replaced by its default.
	for key in data.keys():
		if not known.has(key):
			errors.append("%s: %s: unknown field; known: %s" % [where, _at(root, str(key)),
				", ".join(known)])


static func _is_int(value: Variant) -> bool:
	# JSON numbers arrive as floats, so 2.0 is an int here and 2.5 is not.
	return (value is int or value is float) and value == floorf(value)


static func _seeds(value: Variant, where: String, field: String, errors: PackedStringArray) -> Array[int]:
	var seeds: Array[int] = []
	if not value is Dictionary:
		errors.append("%s: %s: must be {\"from\": int, \"count\": int}" % [where, field])
		return seeds
	_unknown_keys(value, ["from", "count"], where, field, errors)
	var from = value.get("from", 1)
	var count = value.get("count", 10)
	if not _is_int(from):
		errors.append("%s: %s.from: must be an integer" % [where, field])
		return seeds
	if not (_is_int(count) and count >= 1):
		errors.append("%s: %s.count: must be an integer >= 1" % [where, field])
		return seeds
	for s in range(int(from), int(from) + int(count)):
		seeds.append(s)
	return seeds


static func _policies(value: Variant, known: Array, where: String, field: String, errors: PackedStringArray) -> PackedStringArray:
	var drive := PackedStringArray(["ai", "ai"])
	if not value is Dictionary:
		errors.append("%s: %s: must be {\"player\": policy, \"enemy\": policy}" % [where, field])
		return drive
	_unknown_keys(value, ["player", "enemy"], where, field, errors)
	for at in 2:
		var key: String = ["player", "enemy"][at]
		var policy = value.get(key, "ai")
		if not known.has(policy):
			errors.append("%s: %s.%s: unknown policy '%s'; known: %s" % [where, field, key, policy,
				", ".join(known)])
			continue
		drive[at] = policy
	return drive


static func _expect(value: Variant, where: String, field: String, errors: PackedStringArray) -> Dictionary:
	# Only the shape is checked here: whether a path names a real metric is known once a fight has
	# produced the metrics, so ChBalanceReport.check_expect reports unknown paths.
	if not value is Dictionary:
		errors.append("%s: %s: must be {\"metric.path\": [min, max]}" % [where, field])
		return {}
	for key in value:
		var range_ = value[key]
		if not (range_ is Array and range_.size() == 2 and (range_[0] is float or range_[0] is int)
				and (range_[1] is float or range_[1] is int) and range_[0] <= range_[1]):
			errors.append("%s: %s.%s: must be [min, max] with min <= max" % [where, field, key])
	return value


static func _sides(value: Variant, base: ChCatalog, where: String, field: String,
		extra_bodies: Dictionary, errors: PackedStringArray) -> Array[ChChariotLayout]:
	# A list makes a matrix; one object is one side.
	var out: Array[ChChariotLayout] = []
	if value is Dictionary:
		var one := _side(value, base, where, field, extra_bodies, errors)
		if one != null:
			out.append(one)
	elif value is Array and not value.is_empty():
		for i in value.size():
			var one := _side(value[i], base, where, "%s[%d]" % [field, i], extra_bodies, errors)
			if one != null:
				out.append(one)
	else:
		errors.append("%s: %s: required, a side object or a non-empty list of them" % [where, field])
	return out


static func _side(value: Variant, base: ChCatalog, where: String, field: String,
		extra_bodies: Dictionary, errors: PackedStringArray) -> ChChariotLayout:
	if not value is Dictionary:
		errors.append("%s: %s: must be a side object" % [where, field])
		return null
	var before := errors.size()
	_unknown_keys(value, SIDE_KEYS, where, field, errors)
	for key in ["body_type", "body_seed"]:
		if value.has(key):
			errors.append("%s: %s.%s: body types arrive with the bodies plan; use body_id" % [where, field, key])
	var hp = value.get("hp", 0)
	if value.has("hp") and not (_is_int(hp) and hp >= 1):
		errors.append("%s: %s.hp: must be an integer >= 1" % [where, field])
	var layout: ChChariotLayout = null
	if value.has("layout") == value.has("body_id"):
		errors.append("%s: %s: give exactly one of layout or body_id" % [where, field])
	elif value.has("layout"):
		# A layout brings its own parts, so parts beside it would be silently dropped.
		if value.has("parts"):
			errors.append("%s: %s.parts: only with body_id; a layout side uses the layout's parts" % [where, field])
		if value.has("plain_hull"):
			errors.append("%s: %s.plain_hull: only with body_id" % [where, field])
		layout = _layout_file(value["layout"], base, where, field + ".layout", errors)
	else:
		layout = _inline(value, base, where, field, errors)
	var plain = value.get("plain_hull", false)
	if not plain is bool:
		errors.append("%s: %s.plain_hull: must be true or false" % [where, field])
	if layout == null or errors.size() > before:
		return null
	# Overrides make a new body under its own id, so two sides on one body never share a def, and
	# the def on disk (shared by the whole process) is never touched.
	var def: ChBodyDef = base.body(layout.body_id)
	if plain:
		# The box control: every field kept but the outline, so only the shape differs.
		def = def.copy()
		def.id = StringName("%s_box" % def.id)
		def.outline = PackedVector2Array()
	if value.has("hp"):
		def = _body_with_hp(def, int(hp))
	if def != base.body(layout.body_id):
		extra_bodies[def.id] = def
		layout.body_id = def.id
	if value.has("hp"):
		# A layout's own max_hp would win over its body's hp, so the override is set there too.
		layout.max_hp = int(hp)
	return layout


static func _layout_file(path: Variant, base: ChCatalog, where: String, field: String,
		errors: PackedStringArray) -> ChChariotLayout:
	if not (path is String and path.begins_with("res://") and ResourceLoader.exists(path)):
		errors.append("%s: %s: no layout at '%s' (want a res:// path; see run.sh --list)" % [where, field, path])
		return null
	var loaded = ResourceLoader.load(path)
	if not loaded is ChChariotLayout:
		errors.append("%s: %s: '%s' is not a ChChariotLayout" % [where, field, path])
		return null
	if base.body(loaded.body_id) == null:
		errors.append("%s: %s: layout's body '%s' is not in the catalog" % [where, field, loaded.body_id])
		return null
	# A deep copy, so an hp override never rewrites the resource cache's shared layout. Mirroring
	# twice inverts every flip twice, which is the copy with the flips as they were.
	return loaded.mirrored().mirrored()


static func _inline(value: Dictionary, base: ChCatalog, where: String, field: String,
		errors: PackedStringArray) -> ChChariotLayout:
	var body_id = value["body_id"]
	var body: ChBodyDef = base.body(StringName(body_id)) if body_id is String else null
	if body == null:
		errors.append("%s: %s.body_id: unknown body '%s'; known: %s" % [where, field, body_id,
			_known(base.bodies)])
		return null
	var parts = value.get("parts")
	if not parts is Array:
		errors.append("%s: %s.parts: required, a list of {\"slot\": [i, ...], \"part\": id}" % [where, field])
		return null
	# Checked entries as [index, path, part id, flipped]; bad ones are reported and skipped.
	var mounts: Array = []
	for i in parts.size():
		var at := "%s.parts[%d]" % [field, i]
		var entry = parts[i]
		if not entry is Dictionary:
			errors.append("%s: %s: must be {\"slot\": [i, ...], \"part\": id}" % [where, at])
			continue
		_unknown_keys(entry, PART_KEYS, where, at, errors)
		var slot = entry.get("slot")
		var path: Array[int] = []
		if slot is Array and not slot.is_empty():
			for step in slot:
				if not (_is_int(step) and step >= 0):
					path.clear()
					break
				path.append(int(step))
		if path.is_empty():
			errors.append("%s: %s.slot: required, a non-empty list of slot indices like [2] or [2, 0]" % [where, at])
		var id = entry.get("part")
		if not (id is String and base.part(StringName(id)) != null):
			errors.append("%s: %s.part: unknown part '%s'; known: %s" % [where, at, id, _known(base.parts)])
			continue
		var flipped = entry.get("flipped", false)
		if not flipped is bool:
			errors.append("%s: %s.flipped: must be true or false" % [where, at])
			continue
		if not path.is_empty():
			mounts.append([i, path, StringName(id), flipped])
	# Shortest path first, so a part mounted on another part finds its parent already placed.
	mounts.sort_custom(func(a, b): return a[1].size() < b[1].size() or (a[1].size() == b[1].size() and a[0] < b[0]))
	var layout := ChChariotLayout.new()
	layout.body_id = body.id
	for mount in mounts:
		var at := "%s.parts[%d].slot" % [field, mount[0]]
		var path: Array[int] = mount[1]
		var index: int = path[path.size() - 1]
		var room: int = body.slots.size()
		var owner := "body '%s'" % body.id
		if path.size() > 1:
			var parent := layout.get_node(path.slice(0, path.size() - 1))
			if parent == null:
				errors.append("%s: %s: no part at %s to mount on" % [where, at, path.slice(0, path.size() - 1)])
				continue
			room = base.part(parent.part_id).extension_slots.size()
			owner = "part '%s'" % parent.part_id
		if index >= room:
			errors.append("%s: %s: %s has %s" % [where, at, owner,
				"no slots" if room == 0 else "slots 0..%d" % (room - 1)])
			continue
		if not layout.place(path, mount[2]):
			errors.append("%s: %s: slot %s is already taken" % [where, at, path])
			continue
		if mount[3]:
			layout.toggle_flip(path)
	return layout


static func _known(table: Dictionary) -> String:
	var ids: Array = []
	for id in table.keys():
		ids.append(String(id))
	ids.sort()
	return ", ".join(ids)


static func _body_with_hp(loaded: ChBodyDef, hp: int) -> ChBodyDef:
	# ChBodyDef.copy() carries every field (duplicate() drops a script resource's own properties).
	var copy := loaded.copy()
	copy.id = StringName("%s__hp%d" % [loaded.id, hp])
	copy.hp = hp
	return copy
