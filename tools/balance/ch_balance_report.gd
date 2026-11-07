class_name ChBalanceReport extends RefCounted

# Pure: per-fight dictionaries (ChFightStats.fight) in, aggregates, expectation failures and text
# out. No fight runs here, so every rule below is tested on hand-made fights.


static func aggregate(name: String, fights: Array[Dictionary]) -> Dictionary:
	# An aborted fight never played, so it stays out of every mean and out of the win_rate
	# denominator; a draw is a real fight, counted with its full 60 s.
	var real: Array[Dictionary] = []
	var counts := {"win": 0, "loss": 0, "draw": 0, "aborted": 0}
	var aborted_seeds: Array = []
	var draw_seeds: Array = []
	var seconds := 0.0
	for f in fights:
		counts[f.result] += 1
		if f.result == "aborted":
			aborted_seeds.append(f.seed)
			continue
		if f.result == "draw":
			draw_seeds.append(f.seed)
		real.append(f)
		seconds += f.fight_seconds
	return {"name": name, "fights": fights.size(), "wins": counts.win, "losses": counts.loss,
		"draws": counts.draw, "aborted": counts.aborted,
		"win_rate": float(counts.win) / real.size() if not real.is_empty() else 0.0,
		"mean_fight_seconds": seconds / real.size() if not real.is_empty() else 0.0,
		"aborted_seeds": aborted_seeds, "draw_seeds": draw_seeds,
		"player": _side_means(real, 0), "enemy": _side_means(real, 1)}


static func _side_means(real: Array[Dictionary], side: int) -> Dictionary:
	var sides: Array = []
	for f in real:
		sides.append(f.sides[side])
	var out := _means(sides, ["parts"])
	var by_key := {}
	for s in sides:
		for key in s.get("parts", {}):
			if not by_key.has(key):
				by_key[key] = []
			by_key[key].append(s.parts[key])
	var parts := {}
	for key in by_key:
		var list: Array = by_key[key]
		var part := _means(list, ["part", "path", "broke_at_seconds"])
		part.part = list[0].part
		part.path = list[0].path
		# When a part breaks is only meaningful over the fights it broke in; how often is its own field.
		var broke: Array = list.filter(func(p): return p.broke_at_seconds >= 0.0)
		part.broke_fraction = float(broke.size()) / list.size()
		var broke_total := 0.0
		for p in broke:
			broke_total += p.broke_at_seconds
		part.broke_at_seconds = broke_total / broke.size() if not broke.is_empty() else -1.0
		parts[key] = part
	out.parts = parts
	return out


static func _means(dicts: Array, skip: Array) -> Dictionary:
	# Every numeric field averaged; the keys come from the first entry since they all share a shape.
	var out := {}
	if dicts.is_empty():
		for key in ChFightStats._zero_side():
			if not skip.has(key):
				out[key] = 0.0
		return out
	for key in dicts[0]:
		if skip.has(key):
			continue
		var total := 0.0
		for d in dicts:
			total += float(d[key])
		out[key] = total / dicts.size()
	return out


static func check_expect(agg: Dictionary, expect: Dictionary) -> PackedStringArray:
	# Paths are dotted into the aggregate; ranges are inclusive. An unknown path is a failure, so a
	# misspelt regression check cannot pass by checking nothing.
	var failures := PackedStringArray()
	for path in expect:
		var value: Variant = agg
		for step in String(path).split("."):
			value = value.get(step) if value is Dictionary else null
		if not (value is float or value is int):
			failures.append("%s: expect %s: no such metric" % [agg.name, path])
			continue
		var lo: float = expect[path][0]
		var hi: float = expect[path][1]
		if value < lo or value > hi:
			failures.append("%s: expect %s: %s not in [%s, %s]" % [agg.name, path, _num(value), lo, hi])
	return failures


static func summary_text(aggs: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	for agg in aggs:
		lines.append("== %s ==" % agg.name)
		lines.append("  %dW %dL %dD %d aborted   win_rate %s   mean_fight_seconds %s" % [agg.wins,
			agg.losses, agg.draws, agg.aborted, _num(agg.win_rate), _num(agg.mean_fight_seconds)])
		if not agg.aborted_seeds.is_empty():
			lines.append("  aborted seeds: %s" % [agg.aborted_seeds])
		for side in ["player", "enemy"]:
			var s: Dictionary = agg[side]
			lines.append("  %s: hp_left %s  dps_dealt %s  energy_spent %s  starved_s %s  flipped_s %s  rams %s" % [
				side, _num(s.hp_left), _num(s.dps_dealt), _num(s.energy_spent),
				_num(s.energy_starved_seconds), _num(s.flipped_seconds), _num(s.rams)])
			if s.parts.is_empty():
				continue
			lines.append("    %-28s %8s %6s %8s %10s %9s" % ["part", "firings", "hits", "damage",
				"dmg/energy", "waiting_s"])
			for key in s.parts:
				var p: Dictionary = s.parts[key]
				lines.append("    %-28s %8s %6s %8s %10s %9s" % [key, _num(p.firings), _num(p.hits),
					_num(p.damage_dealt), _num(p.damage_per_energy), _num(p.seconds_waiting)])
	return "\n".join(lines)


static func result_line(aggs: Array[Dictionary], failures: PackedStringArray) -> String:
	# CONTRACT: one line, last on stdout, so an agent can take the final line and parse it.
	var ok := failures.is_empty()
	var scenarios: Array = []
	for agg in aggs:
		ok = ok and agg.aborted == 0
		scenarios.append({"name": agg.name, "win_rate": agg.win_rate,
			"mean_fight_seconds": agg.mean_fight_seconds, "aborted": agg.aborted})
	return "RESULT " + JSON.stringify({"ok": ok, "scenarios": scenarios, "failures": Array(failures)})


static func _num(value: float) -> String:
	# Two decimals at most, no trailing noise: 7 stays "7", 0.333 reads "0.33".
	return str(snappedf(value, 0.01))
