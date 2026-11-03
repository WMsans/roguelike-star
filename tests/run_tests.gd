extends SceneTree

# Runs every `test_*` method of every `test_*.gd` under res://tests/ (recursively).
# Output ends with "N passed, M failed"; the exit code is non-zero if anything failed.
# The suite runs on the first process_frame signal, not in _init: Engine.get_main_loop()
# is null while _init runs, and test methods may await frames (ChTest.make_world).
var _started := false


func _init() -> void:
	self.process_frame.connect(_run)


func _run() -> void:
	# The signal fires every frame; the suite runs once.
	if _started:
		return
	_started = true
	var filter := _filter_arg()
	var passed := 0
	var failed := 0
	for test_file in _test_paths("res://tests"):
		var file_name: String = test_file.get_file()
		# shortcut: the filter matches test file names only (`engine`, `layout`, `energy`);
		# upgrade to match directory names if a suite wants `-- battle`.
		if filter != "" and not file_name.contains(filter):
			continue
		var script = load(test_file)
		if script == null:
			failed += 1
			print("FAIL ", file_name, ": did not load")
			continue
		var inst = script.new()
		# A file that does not extend ChTest has no `failures` to read; counting it as a
		# failure here is better than raising, which would hang the run with no count.
		if inst == null or not ("failures" in inst):
			failed += 1
			print("FAIL ", file_name, ": not a ChTest")
			continue
		# shortcut: test methods take no arguments; upgrade if a suite needs parameters.
		for method in inst.get_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			var before: int = inst.failures.size()
			# ChTest assertions record into inst.failures instead of raising; await lets a
			# coroutine test (ChTest.make_world waits for its world) finish before the delta.
			await inst.call(method_name)
			var problems = inst.failures.slice(before)
			if problems.size() == 0:
				passed += 1
				print("PASS ", file_name, " ", method_name)
			else:
				failed += 1
				print("FAIL ", file_name, " ", method_name, ": ", "; ".join(problems))
	print(passed, " passed, ", failed, " failed")
	quit(1 if failed > 0 else 0)


func _filter_arg() -> String:
	# Filter forms: `... run_tests.gd -- engine` and `... run_tests.gd engine`.
	var user_args = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args[0]
	# Same filter without the `--` separator: it lands after the script path.
	var argv = OS.get_cmdline_args()
	var at := argv.find("--script")
	if at >= 0 and at + 2 < argv.size() and not argv[at + 2].begins_with("-"):
		return argv[at + 2]
	return ""


func _test_paths(dir: String) -> Array:
	var found: Array = []
	var dir_access = DirAccess.open(dir)
	if dir_access == null:
		return found
	for file_name in dir_access.get_files():
		# run_tests.gd and ch_test.gd never match, so the runner does not collect itself;
		# `<name>.gd.uid` side files do not end in .gd.
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(dir.path_join(file_name))
	for sub_dir in dir_access.get_directories():
		# Later suites live in tests/engine, tests/data and tests/battle.
		found.append_array(_test_paths(dir.path_join(sub_dir)))
	return found
