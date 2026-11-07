extends RefCounted

# The balance runner's work, behind tools/balance/run.gd. run.gd loads this file at runtime
# rather than naming it: an entry script is compiled before the project's autoloads exist, and
# ChBattle reads the Feedback autoload, so naming any of these classes from run.gd breaks the
# compile. Usage, flags and exit codes are in run.gd's header and README.md.

const USAGE := """usage: tools/balance/run.sh <scenario.json> [--out <file>]
       tools/balance/run.sh --suite <name> [--out <file>]
       tools/balance/run.sh --list"""
const SUITES := "res://tools/balance/suites"
const ENEMIES := "res://game/data/enemies"
const PACING_FRAMES := 10

var tree: SceneTree = null


func main(args: PackedStringArray) -> int:
	# Without --fixed-fps 60 headless frames run uncapped while physics stays at 60 Hz, so the same
	# seed plays a different fight. Refuse rather than print numbers that don't reproduce.
	var physics_before := Engine.get_physics_frames()
	for _i in PACING_FRAMES:
		await tree.process_frame
	if Engine.get_physics_frames() - physics_before != PACING_FRAMES:
		print("balance: run with --headless --fixed-fps 60 (use tools/balance/run.sh) — without it fights don't reproduce")
		return 1
	var opts := _args(args)
	if opts.has("error"):
		print("balance: ", opts.error)
		print(USAGE)
		return 1
	var base := ChCatalog.load_default()
	if opts.has("list"):
		_list(base)
		return 0
	var parsed: Dictionary
	if opts.has("suite"):
		var path := "%s/%s.json" % [SUITES, opts.suite]
		if not FileAccess.file_exists(path):
			print("balance: no suite '%s'; known: %s" % [opts.suite, ", ".join(_suites())])
			return 1
		parsed = _load(path, base, true)
	else:
		parsed = _load(_resolve(opts.scenario), base, false)
	if not parsed.ok:
		for line in parsed.errors:
			print(line)
		return 1
	var matchups: Array = parsed.matchups
	var aggs: Array[Dictionary] = []
	var fights_by_name := {}
	var failures := PackedStringArray()
	for i in matchups.size():
		var m: ChBalanceMatchup = matchups[i]
		var fights: Array[Dictionary] = []
		for seed in m.seeds:
			fights.append(await _fight(m, seed))
		var agg := ChBalanceReport.aggregate(m.name, fights)
		aggs.append(agg)
		fights_by_name[m.name] = fights
		failures.append_array(ChBalanceReport.check_expect(agg, m.expect))
		print("[%d/%d] %s: %dW %dL %dD%s" % [i + 1, matchups.size(), m.name, agg.wins, agg.losses,
			agg.draws, " %d aborted (seeds %s)" % [agg.aborted, agg.aborted_seeds] if agg.aborted > 0 else ""])
	print(ChBalanceReport.summary_text(aggs))
	if opts.has("out"):
		var out_path := _resolve(opts.out)
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			print("balance: cannot write --out %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		else:
			file.store_string(JSON.stringify({"aggregates": aggs, "fights": fights_by_name,
				"failures": Array(failures)}, "  "))
			file.close()
	print(ChBalanceReport.result_line(aggs, failures))
	var code := 0
	if not failures.is_empty():
		code = 2
	for agg in aggs:
		if agg.aborted > 0:
			code = 3
	return code


func _fight(m: ChBalanceMatchup, seed: int) -> Dictionary:
	# A fresh battle.tscn per fight: start() builds its arena and HUD once (ChBattle's contract).
	var battle: ChBattle = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	tree.root.add_child(battle)
	battle.drivers = [ChBalanceDrivers.make(m.drive[0]), ChBalanceDrivers.make(m.drive[1])]
	var stats := ChFightStats.new()
	stats.bind(battle)
	var results: Array[StringName] = []
	battle.finished.connect(func(r: StringName): results.append(r))
	# CONTRACT (ChBattle.start): every path emits `finished`, aborted included, so this never hangs.
	await battle.start(m.player, m.enemy, m.catalog, seed)
	var fight := stats.fight(seed, results[0] if not results.is_empty() else &"aborted")
	battle.free()
	return fight


func _args(args: PackedStringArray) -> Dictionary:
	var opts := {}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--list":
			opts.list = true
		elif arg == "--suite" or arg == "--out":
			if i + 1 >= args.size():
				return {"error": "%s needs a value" % arg}
			opts[arg.substr(2)] = args[i + 1]
			i += 1
		elif arg.begins_with("--"):
			return {"error": "unknown option %s" % arg}
		elif opts.has("scenario"):
			return {"error": "one scenario file per run"}
		else:
			opts.scenario = arg
		i += 1
	var modes := int(opts.has("list")) + int(opts.has("suite")) + int(opts.has("scenario"))
	if modes != 1:
		return {"error": "give one of <scenario.json>, --suite <name> or --list"}
	return opts


func _resolve(path: String) -> String:
	# Godot resolves a relative path against the project, not the caller's shell, so a relative
	# path is taken from $PWD (which the shell sets and Godot leaves alone).
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return OS.get_environment("PWD").path_join(path)


func _load(path: String, base: ChCatalog, suite: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": PackedStringArray(["%s: no such file" % path])}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "errors": PackedStringArray(["%s: line %d: %s" % [path,
			json.get_error_line(), json.get_error_message()]])}
	if suite:
		return ChBalanceScenario.parse_suite(json.data, base, path)
	return ChBalanceScenario.parse(json.data, base, path)


func _list(base: ChCatalog) -> void:
	print("parts:\n  " + "\n  ".join(_sorted(base.parts.keys())))
	print("bodies:\n  " + "\n  ".join(_sorted(base.bodies.keys())))
	var layouts: Array = []
	for file in DirAccess.get_files_at(ENEMIES):
		if file.ends_with(".tres"):
			layouts.append("%s/%s" % [ENEMIES, file])
	print("layouts:\n  " + "\n  ".join(layouts))
	print("suites:\n  " + "\n  ".join(_suites()))


func _suites() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(SUITES):
		if file.ends_with(".json"):
			names.append(file.get_basename())
	return names


func _sorted(ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	out.sort()
	return out
