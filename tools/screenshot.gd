extends SceneTree

# The design session's shot script, kept in the repo: it runs the real game (main.tscn: ChMain with
# its garage and ChBattle) in a real window and saves what the player actually sees. The headless
# suite can only assert numbers; a frame being *readable* is a thing to look at. Not a test: it
# asserts nothing, it only prints what it saw.
#   godot --path . --resolution 1280x720 -s res://tools/screenshot.gd -- <outdir>
# <outdir> is made if missing and should live OUTSIDE the repo, so no PNG ever lands in git.
# It needs a window server, so it runs WITHOUT --headless on purpose: a headless window has no
# rendered frame to grab.
# project.godot's window/size/mode=2 (maximized) makes --resolution only what the window starts at, so
# the PNG is the letterboxed 1280x720 canvas scaled into the screen (measured here: 2449x1378), not
# 1280x720. That is what the player sees, which is the point.

const GARAGE_FRAMES := 60  # frames the garage gets before garage.png
const BATTLE_FRAMES := 400  # frames of fighting before battle.png, the brief's 400
const MAIN_WAIT := 600  # frames ChMain is given to put its fight in the tree
const RESULT_WAIT := 600  # frames the forced win is given to reach the result panel after battle.png
const MOUNTS := [[[0], &"wheel"], [[1], &"wheel"], [[3], &"ice_cream_mace"]]  # the brief's kit

var outdir := ""
var started := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	outdir = args[0] if not args.is_empty() else ""
	self.process_frame.connect(_run)


func _run() -> void:
	# The signal fires every frame; the script runs once, like tests/run_tests.gd's runner.
	if started:
		return
	started = true
	if outdir == "":
		print("usage: godot --path . -s res://tools/screenshot.gd -- <outdir>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	var main: Node = ResourceLoader.load("res://game/main.tscn").instantiate()
	get_root().add_child(main)
	# The garage's own drop path builds the kit, on the body ChMain starts a run on (a Cutter).
	for mount in MOUNTS:
		if not main.garage.drop_part(mount[1], mount[0]):
			print("tool: %s would not mount at %s" % [mount[1], mount[0]])
	for _frame in GARAGE_FRAMES:
		await process_frame
	_shot("garage.png")
	# The part tooltip, from a card and from a mounted part. Signals stand in for the pointer, which a
	# script cannot put over a window; ~0.3 s lets the pop-in settle.
	var garage = main.garage  # untyped: a ChGarage hint compiles it before the Feedback autoload exists
	for id in [&"flamethrower", &"wheel", &"strut"]:
		var card = garage._card_for(id)
		card.mouse_entered.emit()
		for _frame in 20:
			await process_frame
		_shot("tooltip_%s.png" % id)
		card.mouse_exited.emit()
	garage._follow_pointer(garage.screen_of([3]))
	for _frame in 20:
		await process_frame
	_shot("tooltip_hull.png")
	main.garage.request_fight()
	var frames := 0
	while main.battle == null and frames < MAIN_WAIT:
		await process_frame
		frames += 1
	if main.battle == null:
		print("tool: no fight reached the tree, so there is nothing to shoot")
		quit(1)
		return
	for _frame in BATTLE_FRAMES:
		await process_frame
	var battle = main.battle
	if battle.player == null or battle.enemy == null or battle.ctx == null:
		print("tool: the fight never built its chariots (result %s)" % battle.outcome)
		quit(1)
		return
	print("fight: result %s ticking %s clock %.2f s" % [battle.outcome, battle.ticking,
		battle.ctx.time])
	# The camera's own numbers, so a shot that looks wrong can be tied to a frame that is.
	var zoom := float(battle.camera.zoom.x)
	var view: Vector2 = battle.VIEW / zoom
	var at: Vector2 = battle.camera.position
	print("camera at %s zoom %.3f -> view %s cells, x %.0f..%.0f y %.0f..%.0f" % [at, zoom, view,
		at.x - view.x * 0.5, at.x + view.x * 0.5, at.y - view.y * 0.5, at.y + view.y * 0.5])
	for rig in [battle.player, battle.enemy]:
		var hull: Vector2 = rig.chassis.global_position
		var size := Vector2(rig.body_def.size.x, rig.body_def.size.y)
		print("side %s hull %s size %s" % [rig.side, hull, size])
	_shot("battle.png")
	# Task 6: the result panel. The win is forced by emptying the enemy's hull (ChBattle._step reads
	# is_dead each tick), so the shot does not wait on the melee build landing a hit; ChMain then puts
	# its panel up over the stopped fight.
	battle.enemy.hp = 0
	frames = 0
	while main.screen != &"result" and frames < RESULT_WAIT:
		await process_frame
		frames += 1
	if main.screen != &"result":
		print("tool: the forced win never reached the result panel (screen %s)" % main.screen)
		quit(1)
		return
	# Two frames for the panel's own layout (a Container sorts its children at the end of a frame)
	# before the grab, so the shot is the rect the player gets rather than a half-sorted one.
	for _frame in 2:
		await process_frame
	var panel = main.result_panel
	var rect: Rect2 = panel.get_global_rect()
	print("result: %s, panel \"%s\" at %s size %s, centre %s of viewport %s" % [battle.outcome,
		panel.title.text, rect.position, rect.size, rect.get_center(), battle.VIEW])
	_shot("result.png")
	quit(0)


func _shot(file: String) -> void:
	# The window's own pixels, straight off the root viewport (the same grab the design session used).
	var path := outdir.path_join(file)
	var err := get_root().get_texture().get_image().save_png(path)
	print("saved %s (%s)" % [path, "ok" if err == OK else err])
