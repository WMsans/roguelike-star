class_name ChKeywords extends RefCounted

# The one glossary every part tooltip reads, so a concept looks and reads the same on every part.
# Descriptions mark keywords explicitly as {key} or {key:shown text}: no word matching, so "fires"
# (shoots) is never painted as the fire element.

const DARK_TEXT := Color(0.08, 0.08, 0.1)

const ENTRIES := {
	&"burn": {"name": "Burning", "color": Color("#d63c2f"),
		"text": "A part touching 3 or more fire or lava cells catches fire. While any of a chariot's parts burn, it loses 5 HP a second. 6 water cells put a part out."},
	&"freeze": {"name": "Frozen", "color": Color("#6fb6e8"),
		"text": "Frost and ice build up a part's freeze meter. When it fills, the part stops: it can't fire, and a wheel locks. The meter drains once the cold is gone."},
	&"sparks": {"name": "Sparks", "color": Color("#ff8c42"),
		"text": "Hot sparks that fly from cuts. They can set flammable ground alight."},
	&"energy": {"name": "Energy", "color": ChUi.ACCENT,
		"text": "Parts spend energy to fire. Your chariot refills it over time."},
	&"charges": {"name": "Charges", "color": Color("#a98be0"),
		"text": "Fires this many times per battle, then stops."},
	&"proximity": {"name": "Proximity", "color": Color("#5fbf8f"),
		"text": "Affects your own parts within range. The garage shows the range as a circle while you hover."},
	&"extension": {"name": "Extension slots", "color": Color("#9aa0aa"),
		"text": "Parts bolted onto this one. They move with it, and fall off if it breaks."},
}

static var _tag_re := RegEx.create_from_string("\\{([a-z_]+)(?::([^}]*))?\\}")


static func has(key: StringName) -> bool:
	return ENTRIES.has(key)


static func name_of(key: StringName) -> String:
	return ENTRIES[key].name if has(key) else ""


static func color_of(key: StringName) -> Color:
	return ENTRIES[key].color if has(key) else ChUi.TEXT


static func text_of(key: StringName) -> String:
	return ENTRIES[key].text if has(key) else ""


static func text_color_on(background: Color) -> Color:
	return DARK_TEXT if background.get_luminance() > 0.5 else ChUi.TEXT


static func parse(line: String) -> Dictionary:
	var keys: Array[StringName] = []
	var unknown: Array[StringName] = []
	var out := ""
	var at := 0
	for m in _tag_re.search_all(line):
		out += line.substr(at, m.get_start() - at)
		at = m.get_end()
		var key := StringName(m.get_string(1))
		var has_shown := m.get_start(2) != -1
		if has(key):
			keys.append(key)
			var shown := m.get_string(2) if has_shown else name_of(key)
			out += "[0x%s;sin]%s[]" % [color_of(key).to_html(false), shown]
		else:
			unknown.append(key)
			push_warning("ChKeywords: unknown keyword {%s} in \"%s\"" % [key, line])
			out += m.get_string(2) if has_shown else String(key)
	out += line.substr(at)
	return {"bbcode": out, "keys": keys, "unknown": unknown}


static func keys_of(lines: PackedStringArray) -> Array[StringName]:
	var out: Array[StringName] = []
	for line in lines:
		for key in parse(line).keys:
			if not out.has(key):
				out.append(key)
	return out
