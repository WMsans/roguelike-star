extends SceneTree

# Runs every `test_*` method of every `test_*.gd` under res://tests/ (recursively).
# Output ends with "N passed, M failed"; the exit code is non-zero if anything failed.
# The suite runs on the first process_frame signal, not in _init: Engine.get_main_loop()
# is null while _init runs, and test methods may await frames (ChTest.make_world).
var _started := false
var _passed := 0
var _failed := 0
var _matched := 0


func _init() -> void:
	self.process_frame.connect(_run)


func _run() -> void:
	# The signal fires every frame; the suite runs once.
	if _started:
		return
	_started = true
	var filter := _filter_arg()
	var files: Array = _test_paths("res://tests")
	# A filter that matches nothing (or an empty tests/ tree) is a runner-level error: the
	# later tasks dispatch with a filter, and `0 passed, 0 failed` would read as a green run.
	var missing := false
	if files.is_empty():
		print("NO TEST FILES UNDER: res://tests")
		missing = true
	for test_file in files:
		var file_name: String = test_file.get_file()
		# shortcut: the filter matches test file names only (`engine`, `layout`, `energy`);
		# upgrade to match directory names if a suite wants `-- battle`.
		if filter != "" and not file_name.contains(filter):
			continue
		_matched += 1
		# Each file runs inside _run_file, which returns true only if it got to its last
		# statement: a test file with a parse error loads as a half-built script whose .new()
		# call aborts, and that must count as a failure instead of killing the count line.
		if await _run_file(test_file) != true:
			_failed += 1
			print("FAIL ", file_name, ": did not run (parse error or runner abort)")
	# A filter that matches nothing (or an empty tests/ tree) is a runner-level error: the
	# later tasks dispatch with a filter, and `0 passed, 0 failed` would read as a green run.
	if filter != "" and _matched == 0:
		print("NO TESTS MATCHED: ", filter)
		missing = true
	print(_passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 or missing else 0)


func _run_file(test_file: String) -> bool:
	var file_name: String = test_file.get_file()
	var script = load(test_file)
	if script == null:
		_failed += 1
		print("FAIL ", file_name, ": did not load")
		return true
	# A file that does not extend ChTest has no `failures` to read; counting it as a
	# failure here is better than raising, which would hang the run with no count.
	var inst = script.new()
	if inst == null or not ("failures" in inst):
		_failed += 1
		print("FAIL ", file_name, ": not a ChTest")
		return true
	for method in inst.get_method_list():
		var method_name: String = method.name
		# shortcut: test methods take no arguments; upgrade if a suite needs parameters.
		if not method_name.begins_with("test_"):
			continue
		var before: int = inst.failures.size()
		var done_before: int = inst.completed
		# ChTest assertions record into inst.failures instead of raising; await lets a
		# coroutine test (ChTest.make_world waits for its world) finish before the delta.
		# Kept inline: when this await sits in a helper one level deeper, a test method that
		# waits for frames never resumes (its PASS/FAIL line never printed).
		await inst.call(method_name)
		var problems: Array[String] = inst.failures.slice(before)
		# GDScript has no exceptions: a runtime error prints and the body stops there, so the
		# last statement never ran. ChTest._complete() is the completion marker every test_*
		# method ends with; no bump means the body aborted, which is not a pass.
		# shortcut: a method missing the _complete() marker reads as a failure too; a suite that
		# wants to allow unmarked methods needs a different completion signal.
		if inst.completed == done_before:
			problems.append("did not reach _complete() (body aborted mid-way or marker missing)")
		if problems.size() == 0:
			_passed += 1
			print("PASS ", file_name, " ", method_name)
		else:
			_failed += 1
			print("FAIL ", file_name, " ", method_name, ": ", "; ".join(problems))
	return true


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
