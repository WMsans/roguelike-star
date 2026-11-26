class_name ChKeywords extends RefCounted

# The one glossary every part tooltip reads, so a concept looks and reads the same on every part.
# Descriptions mark keywords explicitly as {key} or {key:shown text}: no word matching, so "fires"
# (shoots) is never painted as the fire element.

const DARK_TEXT := Color(0.08, 0.08, 0.1)

const ENTRIES := {
	&"flame": {"name": "Flame", "color": Color("#ff6060"),
		"text": "Each second, deals damage equal to its stacks. Loses 1 stack a second, and Wet or Freeze cancels it."},
	&"freeze": {"name": "Frozen", "color": Color("#6fb6e8"),
		"text": "While above 0, a part's cooldown is paused and a wheel locks. Loses 1 stack a second, and Flame cancels it."},
	&"block": {"name": "Block", "color": Color("#c9ccd4"),
		"text": "Absorbs weapon hits and Acid before they reach the part (or HP, on the body). Flame and Shock go straight past it. Doesn't wear off."},
	&"acid": {"name": "Acid", "color": Color("#9be04a"),
		"text": "Each second, deals damage equal to its stacks, hitting Block first. Loses 1 stack a second, and Wet cancels it."},
	&"wet": {"name": "Wet", "color": Color("#3f7fe0"),
		"text": "Cancels Flame and Acid, doubles Freeze gained and extends Shock. Never fades: reactions use it up."},
	&"oil": {"name": "Oil", "color": Color("#b08a3c"),
		"text": "Keeps the part from getting Wet and doubles Flame gained. Never fades: reactions use it up."},
	&"shock": {"name": "Shock", "color": Color("#f2e04a"),
		"text": "Each second, deals damage equal to its stacks, and part of it jumps to touching parts. Loses 1 stack a second. A shocked part sets off gunpowder, TNT and flammable gas it touches, or that touch the water or steel it touches."},
	&"speedup": {"name": "Speedup", "color": Color("#4fd6c4"),
		"text": "While above 0, cooldowns run at double speed. Loses 1 stack a second, and Slow cancels it."},
	&"slow": {"name": "Slow", "color": Color("#c070a0"),
		"text": "While above 0, cooldowns run at half speed. Loses 1 stack a second, and Speedup cancels it."},
	&"sparks": {"name": "Sparks", "color": Color("#ff8c42"),
		"text": "Hot sparks that fly from cuts. They can set flammable ground alight."},
	&"energy": {"name": "Energy", "color": ChUi.ACCENT,
		"text": "Parts spend energy to fire. Your chariot refills it over time."},
	&"charges": {"name": "Charges", "color": Color("#a98be0"),
		"text": "Fires this many times per battle, then stops."},
	&"proximity": {"name": "Proximity", "color": Color("#5fbf8f"),
		"text": "Affects your own parts within range. The garage shows the range as a circle while you hover."},
	&"press": {"name": "Press", "color": ChUi.ACCENT,
		"text": "Fires when you press Space, if it's ready and you have the energy. Ready parts glow."},
	&"passive": {"name": "Passive", "color": Color("#9aa0aa"),
		"text": "Works on its own. No press needed."},
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
