extends SceneTree

# The balance runner's CLI (spec §5). Use tools/balance/run.sh, which adds the flags below:
#   godot --headless --fixed-fps 60 --path . -s res://tools/balance/run.gd -- <scenario.json> [--out <file>]
#   ... -- --suite <name> [--out <file>]
#   ... -- --list
# Exit codes: 0 ok, 1 usage / parse / frame-pacing error (no fights ran), 2 an expect failed,
# 3 a fight aborted. The highest that applies wins. The last stdout line is always `RESULT {...}`
# once fights ran. See tools/balance/README.md.

var _started := false


func _init() -> void:
	process_frame.connect(_run)


func _run() -> void:
	if _started:
		return
	_started = true
	# Loaded, not named: see ch_balance_cli.gd's header for why this indirection exists.
	var cli = load("res://tools/balance/ch_balance_cli.gd").new()
	cli.tree = self
	var code: int = await cli.main(OS.get_cmdline_user_args())
	# CONTRACT: RESULT is the last stdout line. Engine teardown prints RID-leak reports to stdout
	# (the test suite shows the same ones), so error printing goes off once the run's work is done.
	# shortcut: this also hides any other teardown error; drop the line to see them.
	Engine.print_error_messages = false
	quit(code)
