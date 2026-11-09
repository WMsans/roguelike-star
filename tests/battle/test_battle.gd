extends ChTest

# Task 15: the battle scene — ChEnemyAI's drive decision, ChBattle's result rule, and one real
# headless fight that ends.
# Seam: the world, the arena fill, the two builds, the fight's tick loop and the win/lose emit
# live once in game/battle/ch_battle.gd. The tests below start a fight and watch frames only, so
# the fight loop is never re-implemented here.
# ChBattle.start is a coroutine that awaits one frame per tick, so a fight test awaits it.
# The catalog the fight tests hand over is ChCatalog.load_default's content with the Dozer's HP
# overridden to 30 (the brief's "the enemy with HP overridden to 30"), so one Rocket hit ends it.
# shortcut: the enemy HP override travels as a hand-built catalog because a def on disk is shared
# by every test in the run; mutating it would make a later test's Dozer fragile.

const FIGHT_SECONDS := 60.0  # the brief's ceiling: a headless fight has to finish inside this
const TICK := 1.0 / 60.0
const ENEMY_HP := 30  # the Dozer's HP overridden
const TALL_HP := 100000  # a hull no fight ends: enough HP that only the time limit can decide


# The seam every fight test uses: connect to finished, start the fight, then let frames run.
# Returns whatever `finished` announced, in order, so "emitted once" is a size check.
func _fight(battle: Node2D, player_layout: ChChariotLayout, enemy_layout: ChChariotLayout,
	catalog: ChCatalog, seed: int) -> Array[StringName]:
	var results: Array[StringName] = []
	var sink := results
	battle.finished.connect(func(result: StringName): sink.append(result))
	await battle.start(player_layout, enemy_layout, catalog, seed)
	return results


func test_ai_approaches_then_holds() -> void:
	var ai := ChEnemyAI.new()
	assert_eq(ai.decide(420.0, 60.0, 6.0), -1.0, "target to the left: drive left")
	assert_eq(ai.decide(60.0, 420.0, 6.0), 1.0, "target to the right: drive right")
	assert_eq(ai.decide(420.0, 414.0, 6.0), 0.0, "inside reach: hold")
	assert_eq(ai.decide(420.0, 426.0, 6.0), 0.0, "exactly at reach: hold, the rule is |dx| <= range")
	assert_eq(ai.decide(420.0, 426.5, 6.0), 1.0, "one hair past reach: close in")
	assert_eq(ai.decide(100.0, 100.0, 0.0), 0.0, "no range to close: hold still")
	# The reach table ChBattle hands that parameter: a weapon's proximity_range is its reach in
	# cells (ChBehaviour._reach_box), and the Harpoon owns its behaviour's own range, counted only
	# while it can fire.
	var catalog := ChCatalog.load_default()
	var mace := ChPartRuntime.new()
	mace.def = catalog.part(&"ice_cream_mace")
	mace.cooldown_left = mace.def.cooldown
	var harpoon := ChPartRuntime.new()
	harpoon.def = catalog.part(&"corsair_harpoon")
	harpoon.cooldown_left = harpoon.def.cooldown
	var parts: Array[ChPartRuntime] = [mace, harpoon]
	var rig := ChChariotRuntime.new()
	rig.parts = parts
	assert_near(ai.reach(rig), 6.0, 0.001, "the shortest reach the Dozer can bring to bear is the Mace's 6")
	# The Harpoon's 120 cells count only while it can fire, so a Harpoon whose cooldown is still
	# running owns no range at all and the driver has nothing to close.
	var ranged := ChChariotRuntime.new()
	var only: Array[ChPartRuntime] = [harpoon]
	ranged.parts = only
	assert_true(is_inf(ai.reach(ranged)), "an unready Harpoon leaves the chariot with no range")
	assert_eq(ai.decide(60.0, 420.0, ai.reach(ranged)), 0.0, "so it stays put instead of charging")
	harpoon.cooldown_left = 0.0
	assert_near(ai.reach(ranged), 120.0, 0.001, "a ready Harpoon counts at its own 120 cells")
	assert_near(ai.reach(rig), 6.0, 0.001, "and the Mace is still the shortest reach")
	_complete()


# Review item 5: `preferred_range` is a weapon's reach in cells, measured from the part - and a part
# mounts on the hull's edge. A Dozer is 30 cells wide and a Cutter 30, so a driver that holds at the
# Mace's 6 parks the two hulls inside each other, where Box2D grinds them (every body is CAT_BODY
# against CAT_BODY, physics.cpp:24-33 binds no per-body filter) instead of fighting. The hulls' own
# half-widths therefore ride along with the reach.
func test_ai_holds_off_the_hulls() -> void:
	var ai := ChEnemyAI.new()
	var catalog := ChCatalog.load_default()
	var dozer := float(catalog.body(&"dozer").size.x) * 0.5
	var cutter := float(catalog.body(&"cutter").size.x) * 0.5
	assert_near(dozer + cutter, 30.0, 0.001, "the two hulls need 30 cells between their centres")
	# 30 apart centre to centre is the two hulls touching: the old rule read it as "6 cells to go" and
	# drove the enemy into the player, which is the stalemate the fight tests kept landing in.
	assert_eq(ai.decide(420.0, 390.0, 6.0, dozer, cutter), 0.0, "30 apart is inside the hulls: hold")
	assert_eq(ai.decide(420.0, 384.0, 6.0, dozer, cutter), 0.0,
		"reach + both half-widths is the hold, and |dx| <= hold holds there")
	assert_eq(ai.decide(420.0, 383.0, 6.0, dozer, cutter), -1.0, "one cell further out: close in")
	assert_eq(ai.decide(384.0, 420.0, 6.0, dozer, cutter), 0.0, "the other way round holds too")
	assert_eq(ai.decide(383.0, 420.0, 6.0, dozer, cutter), 1.0, "and drives right to reach it")
	# The brief's rule is still the rule: the hold is the shortest reach the chariot can bring to bear,
	# so a weapon that reaches further than the hulls keeps the fight at its own range, and a driver
	# with no weapon that reaches anything still stays put.
	assert_eq(ai.decide(100.0, 122.0, 14.0, 4.0, 4.0), 0.0, "a Chainsaw's 14 still rules at 22 apart")
	assert_eq(ai.decide(100.0, 123.0, 14.0, 4.0, 4.0), 1.0, "and one cell past it closes in")
	assert_eq(ai.decide(100.0, 420.0, INF, dozer, cutter), 0.0,
		"nothing to reach (INF + widths is INF): stay put")
	# Without the widths the brief's three-argument call is unchanged, which is what every earlier
	# caller and test that never passes them relies on.
	assert_eq(ai.decide(420.0, 390.0, 6.0), -1.0, "no widths given: the brief's rule, unchanged")
	_complete()


# Review Focus 4: both chariots reaching 0 HP on the same tick (a Ring of Fire pays its own
# chassis as it expands, so one tick can end both) is a loss for the player, not a crash.
func test_simultaneous_death_is_loss() -> void:
	assert_eq(ChBattle.result_for(true, true), &"loss", "both dead: the player loses")
	assert_eq(ChBattle.result_for(true, false), &"loss", "a dead player alone loses")
	assert_eq(ChBattle.result_for(false, true), &"win", "a dead enemy alone wins")
	assert_eq(ChBattle.result_for(false, false), &"", "neither dead is not a result")
	_complete()


# --- Task 4: the camera's frame, as a pure function ------------------------------------------------
# Godot 4's zoom magnifies: what the camera shows is VIEW / zoom. The old _camera_at multiplied
# box / VIEW (a Godot 3 zoom-out), which left both chariots off screen at 320x180. These three
# call ChBattle.camera_frame directly, so the frame is checked without a world.
const PAD := Vector2(48, 24)  # the brief's pad, the same one all three tests hand over


func _view(frame: Dictionary) -> Rect2:
	# The rect the camera shows: centred on `at`, sized VIEW / zoom.
	var size := ChBattle.VIEW / float(frame["zoom"])
	return Rect2((frame["at"] as Vector2) - size * 0.5, size)


func _assert_framing(frame: Dictionary, zoom: float, zoom_msg: String) -> void:
	# What every camera test expects of the number: inside the two bounds, and on a half step so
	# the world's pixels keep one size between ticks (the design's zoom-snapping).
	assert_true(zoom >= ChBattle.ZOOM_WIDEST and zoom <= ChBattle.ZOOM_CLOSEST, zoom_msg)
	assert_near(fmod(zoom, 0.5), 0.0, 0.0001, "the zoom is a multiple of 0.5")


func test_camera_frames_both() -> void:
	# The spawns 140 cells apart: the view has to hold both chariots plus the pad.
	var a := Vector2(170, 100)
	var b := Vector2(310, 100)
	var frame: Dictionary = ChBattle.camera_frame(a, b, PAD)
	var view := _view(frame)
	for hull in [a, b]:
		assert_true(view.encloses(Rect2(hull - PAD, PAD * 2.0)),
			"%s plus its pad sits inside the view %s" % [hull, view])
	_assert_framing(frame, float(frame["zoom"]), "the zoom stays in [%s, %s]" % [
		ChBattle.ZOOM_WIDEST, ChBattle.ZOOM_CLOSEST])
	_complete()


func test_camera_close_when_close() -> void:
	# 20 cells apart: nothing caps the zoom, so it parks on the closest bound rather than
	# magnifying the sand past the whole arena (measured: the unclamped number is 11.03).
	var frame: Dictionary = ChBattle.camera_frame(Vector2(230, 100), Vector2(250, 100), PAD)
	assert_near(float(frame["zoom"]), ChBattle.ZOOM_CLOSEST, 0.001, "20 cells apart frames at 8")
	_assert_framing(frame, float(frame["zoom"]), "and that number is inside the bounds")
	_complete()


func test_camera_stays_in_arena() -> void:
	# A pair in the pit's bottom-left corner: the view is clamped into the arena, so the camera
	# never shows the world outside the pit.
	var frame: Dictionary = ChBattle.camera_frame(Vector2(10, 170), Vector2(30, 170), PAD)
	var pit := Rect2(Vector2(ChBattle.ARENA.position), Vector2(ChBattle.ARENA.size))
	assert_true(pit.encloses(_view(frame)),
		"the view %s lies inside the arena %s" % [_view(frame), ChBattle.ARENA])
	_assert_framing(frame, float(frame["zoom"]), "and the zoom still obeys the bounds")
	_complete()


func test_camera_first_tick_is_the_shot() -> void:
	# battle.tscn's camera starts at (0,0) zoom 1, so an eased tick 1 would show the whole 480x180 pit
	# tiny for the ~15 ticks the glide takes to climb to its shot, and would show world outside ARENA
	# while it did (measured before this pin: tick 1's live view was ~1113x626 cells near (36,16)).
	# The fight opens on its shot instead; `primed: false` is what start() holds on its first tick.
	var want: Dictionary = ChBattle.camera_frame(Vector2(170, 100), Vector2(310, 100), PAD)
	var first: Dictionary = ChBattle.camera_eased(Vector2.ZERO, 1.0, want, false)
	assert_eq(first["at"], want["at"], "an unprimed camera takes the shot's centre, not a step to it")
	assert_eq(float(first["zoom"]), float(want["zoom"]), "and its zoom, not a glide up from 1")
	_assert_framing(want, float(want["zoom"]), "the shot itself obeys the bounds")
	# The ease survives the fix: one primed tick covers CAMERA_EASE of the gap, so a chase still
	# glides between ticks and a camera already on its shot stays on it.
	var next: Dictionary = ChBattle.camera_eased(Vector2.ZERO, 1.0, want, true)
	assert_true(next["at"] != want["at"] and float(next["zoom"]) < float(want["zoom"]),
		"a primed tick eases toward the shot instead of snapping to it")
	var after: Dictionary = ChBattle.camera_eased(want["at"], float(want["zoom"]), want, true)
	assert_eq(after["at"], want["at"], "a camera already on its shot stays there")
	_complete()


# The pin the helper test above cannot make: that _camera_at actually passes the unprimed flag on the
# first tick. This is the shipped scene with a real arena, and _start_fight returns on the resume that
# set ctx - the same resume start() runs its first _step on - so the live camera has taken exactly one
# step: the shot. A regression that passes `true` unconditionally eases from the scene's (0,0) zoom 1
# instead: 1.67 at tick 1, still short of the widest 4 for ~14 ticks, so the one bound tells them apart.
# (start()'s `_camera_primed = false` reset stays defensive: a fresh scene starts false and ChBattle's
# contract is one fight per scene, so no test can reach a second start() to see the reset work.)
func test_camera_first_tick_is_the_shot_in_a_real_fight() -> void:
	var battle := _battle_scene()
	_start_fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP))
	# Task 7: the shot lives on the pcam now - _camera_at writes it and the camera host copies it onto
	# the Camera2D a process frame later - so the live shot is read off battle.pcam, not the camera.
	assert_true(battle.pcam.zoom.x >= ChBattle.ZOOM_WIDEST,
		"the live pcam's first frame is the shot (zoom %.2f, widest %s)"
			% [battle.pcam.zoom.x, ChBattle.ZOOM_WIDEST])
	# And the other half of the wiring: once primed, a tick must ease, not snap. Parked 1000 cells off
	# the shot at zoom 1, the fight's own next tick covers CAMERA_EASE of the gap, so the zoom lands
	# between 1 and the widest bound (measured 1.67 with the ease; a dropped `_camera_primed = true`
	# would snap onto the shot's 5.5 instead, which the bound catches).
	battle.pcam.global_position = Vector2(-1000, -1000)
	battle.pcam.zoom = Vector2.ONE
	await Engine.get_main_loop().process_frame
	assert_true(battle.pcam.zoom.x > 1.0 and battle.pcam.zoom.x < ChBattle.ZOOM_WIDEST,
		"the next live tick eased toward the shot (zoom %.2f, from 1 toward at least %s)"
			% [battle.pcam.zoom.x, ChBattle.ZOOM_WIDEST])
	# Spent to its result before the free: ChBattle.start's contract forbids freeing the scene while its
	# coroutine is suspended (ch_battle.gd's CONTRACT note above the tick loop). The low-HP catalog
	# keeps that cheap - this fight is over in 124 of its 3600 ticks.
	var frames := 0
	while battle.ticking and frames < CHAIN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(not battle.ticking, "the fight this test watched reached its own end")
	battle.free()
	_complete()


# Task 7: the shake path end to end. A beat played at a real fight's body has to reach the battle's own
# emitter through the manager's binding - a PhantomCameraNoiseEmitter2D on the layer the live pcam reads
# - and the amplitude/duration are the profile's own numbers, so a retune of profiles/broken.tres keeps
# this honest. A weaker beat landing while the shake runs must not cut the louder one short.
func test_shake_plays_through_the_emitter() -> void:
	var battle := _battle_scene()
	var results: Array[StringName] = []
	var sink := results
	battle.finished.connect(func(result: StringName): sink.append(result))
	_start_fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP))
	var shake: PhantomCameraNoiseEmitter2D = battle.get_node("Shake")
	var broken: ChFeedbackProfile = Feedback.profile(&"broken")
	Feedback.play(&"broken", battle.player.chassis_visual)
	assert_true(shake.is_emitting(), "the broken beat started the battle's emitter")
	assert_near(shake.noise.amplitude, 12.0 * broken.shake, 0.001,
		"at the profile's own amplitude")
	assert_near(shake.duration, 0.08 + 0.25 * broken.shake, 0.001, "and its own duration")
	Feedback.play(&"fired", battle.player.chassis_visual)
	assert_near(shake.noise.amplitude, 12.0 * broken.shake, 0.001,
		"a weaker beat did not replace the louder shake")
	assert_true(shake.is_emitting(), "and the loud shake is still running")
	# Then the fight has to end as any other: a shake is feedback on the fight, never a change to it.
	var frames := 0
	while battle.ticking and frames < CHAIN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(not battle.ticking, "the fight ran to its own end")
	assert_eq(results, [&"win"], "and still ended on its own result")
	battle.free()
	_complete()


func test_battle_finishes() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "the fight announced exactly one result")
	assert_eq(results, [&"win"], "the fight ended with a win inside the 60 s ceiling")
	# The markers have to sit on the parts at whatever zoom/pan the camera ends at, so they live under
	# the world's Node2D (the Camera2D's transform carries them) rather than the HUD CanvasLayer.
	assert_true(battle.marks.get_parent() == battle.world, "markers are parented to the world layer")
	# Same reason on the other axis: 2D draw order sorts by z_index before tree order, so a marker at
	# the bodies' own z sits under whichever hull or pile drew later and cannot be seen. Nothing under
	# game/ or the builders sets z_index, so the bodies answer 0 and the marker layer must beat them.
	assert_true(battle.marks.z_index > battle.player.chassis.z_index, "markers draw above the hulls")
	battle.free()
	_complete()


func _battle_scene() -> Node2D:
	# The scene itself, so the fight test drives the shipped scene rather than a copy of its loop.
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	# A headless run has no Space key, and since the volley is press-driven a fight nobody presses
	# in is a draw. The fights below pin what the player's parts do, so the player presses by the
	# enemy's own rule; the tests that pin the press itself replace this.
	battle.pressers[0] = func(b, s): return b.ai_press(s)
	Engine.get_main_loop().get_root().add_child(battle)
	return battle


# The &"aborted" contract, cheaply: a chariot whose body id the catalog has no def for cannot build,
# so start() returns early — and an early return still has to announce a result, or a caller awaiting
# `finished` hangs. This pays the world load and the arena fill only: the tick loop never starts, so
# there is no 60 s fight here. The ERROR lines the run prints are the contract's own push_error calls.
func test_aborted_battle_still_ends() -> void:
	var battle := _battle_scene()
	var broken := ChChariotLayout.new()
	broken.body_id = &"no_such_body"
	# This fight is built to fail on purpose, and the two diagnostics it makes are the abort path's
	# own: ch_chariot_builder.gd:18 ("body id no_such_body has no def") and ch_battle.gd:143 ("a
	# chariot did not build"). They are what the shipped game prints when a fight cannot start, so
	# the code keeps them; only their noise here is muted, over the frames this one fight runs, so a
	# real error anywhere else in the run still reaches the log.
	Engine.set_print_error_messages(false)
	var results := await _fight(battle, broken, _enemy_layout(), ChCatalog.load_default(), 12345)
	Engine.set_print_error_messages(true)
	assert_eq(results.size(), 1, "the aborted battle announced exactly one result")
	assert_eq(results, [&"aborted"], "a battle that cannot start ends with aborted")
	battle.free()
	_complete()


# Task 3: a result ends the fight. The loop stops at it, the world stops simulating with it, and the
# clock stays short of the budget, so the ticks past the end that used to run are gone.
func test_fight_stops_at_result() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "the fight announced exactly one result")
	assert_eq(results, [&"win"], "the win, once, and no second result behind it")
	assert_true(not battle.ticking, "the tick loop stopped at the result")
	assert_true(not battle.world.simulating, "and the world stopped simulating with it")
	assert_true(battle.ctx.time < FIGHT_SECONDS - 1.0,
		"the fight stopped short of its 60 s budget (clock at %.2f s)" % battle.ctx.time)
	battle.free()
	_complete()


# Review Focus 5, the fight's half: a fight that runs out its time with both hulls standing names a
# draw rather than saying nothing. ChMain's half (the panel that shows it) is Task 6's.
func test_timeout_is_draw() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(),
		_fight_catalog(TALL_HP, TALL_HP), 12345)
	assert_eq(results.size(), 1, "the fight that ran out its time announced exactly one result")
	assert_eq(results, [&"draw"], "the time limit reads as a draw, not a win or a loss")
	assert_near(battle.ctx.time, FIGHT_SECONDS, TICK, "and it spent its whole tick budget first")
	assert_true(not battle.ticking, "the loop ended on its own budget")
	battle.free()
	_complete()


# The contract Tasks 6 and 7 build on: `finished` is the fight's end, not a mid-fight announcement.
# Read from inside the handler, `ticking` and the world's sim are already down, so a listener may
# free this node on any later frame without cutting a coroutine or leaving a simulating world.
func test_finished_after_ticking_stops() -> void:
	var battle := _battle_scene()
	var at_emit: Array = []
	var sink := at_emit
	battle.finished.connect(func(result: StringName): sink.append(
		{"result": result, "ticking": battle.ticking, "simulating": battle.world.simulating}))
	await battle.start(_player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(at_emit.size(), 1, "one finished across the fight")
	assert_eq(at_emit[0]["result"], &"win", "naming the win")
	assert_true(not bool(at_emit[0]["ticking"]), "ticking was already false when the handler ran")
	assert_true(not bool(at_emit[0]["simulating"]), "and the world had already stopped simulating")
	battle.free()
	_complete()


# --- Review item 3: the spec's chains, read off a real fight --------------------------------------
# Everything above this line drives one seam in isolation. These two drive the shipped scene with a
# build made through the garage's own drop path, hold the fight's own drive keys the way a player
# holds D, and read what the fight's own event bus said. ChBattle has no stop, so each of these
# pays its fight to the end - at its own result if one arrives, otherwise at its 3600-frame budget -
# and both drive through the shipped scene's real tick loop.
const CHAIN_FRAMES := 4000  # the 3600-frame budget, plus the frames the arena takes to stream
const DRIVE_ON := 0.9  # seconds of held direction
const DRIVE_OFF := 0.3  # seconds released, so the queued parts are paid (drive is paid first)
const PLAYER_MARK_FRAMES := 120  # 2 s of fight: the player has driven, the Dozer has not arrived


func _garage_built(body_id: StringName, mounts: Array) -> ChChariotLayout:
	# The build the garage's pointer code makes: ChGarage.drop_part for each part, from an inventory
	# that carries it, onto the body the player picked. request_fight hands the fight a copy of exactly
	# this, so passing the layout on is what the Fight button does.
	var inventory := ChInventory.new()
	for mount in mounts:
		assert_true(inventory.add(mount[1]), "the kit carries %s" % [mount[1]])
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	var garage := ChGarage.new()
	garage.setup(inventory, layout, ChCatalog.load_default())
	for mount in mounts:
		assert_true(garage.drop_part(mount[1], mount[0]),
			"the garage drops %s into slot %s" % [mount[1], mount[0]])
	garage.free()
	return layout


# start() is a coroutine: it streams the arena on the tree's frames before its tick loop begins, so it
# is deliberately not awaited here. The caller waits for ctx (which owns the fight's bus), subscribes,
# then spends the frames the loop needs.
func _start_fight(battle: Node2D, player_layout: ChChariotLayout,
	enemy_layout: ChChariotLayout, catalog: ChCatalog = null) -> void:
	# A catalog is optional: the camera test hands over the low-HP one so its fight ends soon and it
	# can free the scene after the loop instead of mid-await.
	battle.start(player_layout, enemy_layout, catalog if catalog != null else ChCatalog.load_default(),
		12345)
	var frames := 0
	while battle.ctx == null and frames < 600:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(battle.ctx != null, "the fight reached its context")


# The drive keys: ChBattle._player_drive reads Input, so action_press is what holding the key at the
# keyboard is. Bursting it is what a player learns, because ChEnergy pays the drive before the queued
# parts and a direction held for ever starves the weapons. Returns `min_gap`, the narrowest the two
# hulls ever got centre to centre (the number the reach pins below read), and `mark`, the player's
# hull x at PLAYER_MARK_FRAMES: where its own driving had got it before the Dozer arrived, which is
# the only stretch of the fight that is the player's driving alone.
func _drive_fight_out(battle: Node2D) -> Dictionary:
	var frames := 0
	var min_gap := INF
	var mark := 0.0
	var held := false
	var next_flip := DRIVE_ON
	while battle.ticking and frames < CHAIN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
		var t: float = battle.ctx.time
		if t >= next_flip:
			held = not held
			next_flip = t + (DRIVE_OFF if held else DRIVE_ON)
			if held:
				Input.action_press(&"ui_right")
			else:
				Input.action_release(&"ui_right")
		min_gap = minf(min_gap, absf(battle.enemy.chassis.global_position.x
			- battle.player.chassis.global_position.x))
		if frames == PLAYER_MARK_FRAMES:
			mark = battle.player.chassis.global_position.x
	Input.action_release(&"ui_right")
	assert_true(frames < CHAIN_FRAMES, "the fight spent its own tick loop rather than the frame cap")
	return {"min_gap": min_gap, "mark": mark}


# Every event the fight names, in the order it said them, with the two fields the chains read. The
# sinks stay arrays of Dictionaries because a lambda closes over an array by reference.
func _hear_all(battle: Node2D, heard: Array) -> void:
	var key := RefCounted.new()
	for type in [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.CAUGHT_FIRE, ChEvent.ENERGY_GAINED,
		ChEvent.FROZEN, ChEvent.THAWED, ChEvent.CELLS_CUT, ChEvent.PART_BROKEN]:
		battle.ctx.bus.subscribe(key, type, func(event: ChEvent): heard.append({
			"type": event.type,
			"side": event.side,
			"source": &"" if event.source == null or event.source.def == null
				else event.source.def.id,
			"target_part": null if event.data.get("target_part") == null
				else (event.data["target_part"] as ChPartRuntime).def.id,
			"sparks": event.data.get("sparks", 0),
			"hp_damage": event.data.get("hp_damage", 0),
		}))


# Chain 1 (spec 5.5): the Chainsaw cuts, something ignites, the Ember Battery pays energy. Over a real
# fight the cut lands on the Chainsaw's own 0.5 s cooldown, its sparks set something alight, and the
# battery pays for that catch. The chainsaw sits on the Corsair's front slot, so its 14-cell reach
# clears the hull's own edge and the sparks land outside it; the asserts below are the chain in order -
# a cut with sparks, a catch after it, the battery paying after that catch, and the enemy's parts
# catching too.
# WHICH side catches first is not pinned: at the Task 4 spawns both hulls sit in the burning sand the
# saw cuts, so the first catch after the cut was the player's own saw in most runs (measured: event 30
# on side 0, eight runs) and the enemy's wheel in one run of fifteen - which of the two catches first
# turns on frame timing (the world steps on real time), not on the rule. What is stable, and what the
# count below pins, is that the enemy's parts catch many times after the saw's cut (measured 8-40 in
# 16 runs, counted from the cut onward), so the spec's "the target keeps burning" shows *because of
# this chain*: the enemy's own Hearth burns the same sand, so a count over the whole fight would pass
# with a saw that never cut. The order is the evidence, not the count: CAUGHT_FIRE carries no
# igniter (ChPartRuntime._emit), so a catch after the saw's cut in the same fight is the causal link
# this fight can show.
func test_chain1_cut_ignites_and_pays_energy_in_a_real_fight() -> void:
	var battle := _battle_scene()
	var heard: Array = []
	var layout := _garage_built(&"corsair", [[[0], &"wheel"], [[1], &"wheel"],
		[[6], &"cutter_chainsaw"], [[3], &"ember_battery"]])
	_start_fight(battle, layout, _enemy_layout())
	_hear_all(battle, heard)
	var driven := await _drive_fight_out(battle)
	var min_gap: float = driven["min_gap"]
	var cut := -1
	var caught := -1
	var paid := -1
	var enemy_catches := 0
	for at in heard.size():
		var entry: Dictionary = heard[at]
		if cut < 0 and entry["type"] == ChEvent.CELLS_CUT \
				and entry["source"] == &"cutter_chainsaw" and int(entry["sparks"]) >= 1:
			cut = at
		elif cut >= 0 and caught < 0 and entry["type"] == ChEvent.CAUGHT_FIRE:
			caught = at
		elif caught >= 0 and paid < 0 and entry["type"] == ChEvent.ENERGY_GAINED \
				and entry["source"] == &"ember_battery":
			paid = at
		# Only catches *after* the cut: the enemy's Hearth burns the same sand the saw cuts, so a count
		# over the whole fight would pass with a saw that never cut (cut stays -1 here, and then no
		# entry is after it).
		if cut >= 0 and at > cut and entry["type"] == ChEvent.CAUGHT_FIRE \
				and int(entry["side"]) == 1:
			enemy_catches += 1
	assert_true(cut >= 0, "the Chainsaw cut cells and threw sparks (heard %d events)" % heard.size())
	assert_true(caught > cut, "something caught fire after that cut")
	assert_true(paid > caught, "and the Ember Battery paid energy for the catch")
	# The chain does not need contact: the sparks fly, the sand burns, and the battery pays. The count
	# below is the spec's "the target keeps burning", and it is the stable form of the claim the first
	# catch's side cannot carry (see the note above).
	assert_true(enemy_catches >= 4,
		"the enemy's parts kept catching fire after the saw's cut (measured 8-40, got %d)"
			% enemy_catches)
	# The spawn gap is 140 cells now, so this only holds if the fight closes it: measured 39. The old
	# spawns were 360 apart, and this build's narrowest measured 130-183 cells there.
	assert_true(min_gap < 140.0,
		"and the two chariots closed the spawn gap (narrowest %.0f)" % min_gap)
	battle.free()
	_complete()


# Chain 2 (spec 5.5): the Freeze Charge's freeze on a Mace hit, then the Shatter's x3 on the frozen
# part. This is the harness the final review asked for - the plan's own build (a Mace and a Harpoon on
# the Corsair's front slots) fought for real through ChBattle, built by the garage's own drop path. It
# pins the two things that are stable run to run:
#   - the player's chariot drives off its spawn. That is what the wheel mounts buy (see
#     ChBodyDef): a loaded chariot used to sit with its motors on and the hulls could never meet,
#     which is the state this test used to pin as "min_gap > 100".
#   - the Mace swings on its own cooldown, so the fight pays it through ChBattleContext's loop.
# What it does NOT pin: how close the two hulls get. With the wheel mounts fixed they met (38 cells,
# the two hulls touching) in three runs of this build and stayed 186 apart in a fourth, because
# whether the sand and the two pools let the player across varies run to run; the fight resolves
# either way, at its own result or at its frame budget. Measured again at the Task 4 spawns: the two
# hulls got to 39 cells apart and the fight resolved as a win.
# The freeze lands. A Mace hits the Dozer's chassis almost every swing (its wheels hang below a
# Corsair's top slots), and the design call in the demo balance pass was that a hull hit puts its
# freeze on the target's part nearest the attacker (ChBattleContext.deal_hit), which then holds frozen
# while the meter decays (ChPartRuntime.is_frozen). Before that call this test pinned "nothing froze".
func test_chain2_melee_build_drives_out_of_its_corner() -> void:
	var battle := _battle_scene()
	var heard: Array = []
	var layout := _garage_built(&"corsair", [[[0], &"wheel"], [[1], &"wheel"],
		[[6], &"ice_cream_mace"], [[5], &"freeze_charge"], [[4], &"corsair_harpoon"]])
	_start_fight(battle, layout, _enemy_layout())
	_hear_all(battle, heard)
	var driven := await _drive_fight_out(battle)
	var min_gap: float = driven["min_gap"]
	var swung := 0
	var frozen := 0
	for entry in heard:
		if entry["type"] == ChEvent.PART_FIRED and entry["source"] == &"ice_cream_mace":
			swung += 1
		elif entry["type"] == ChEvent.FROZEN:
			frozen += 1
	assert_true(swung > 0, "the fight paid the Mace, so it swung on its own cooldown")
	# Measured 2 s in, with the Dozer still 83-91 cells away: the player's hull sat at x 184-191, i.e.
	# 14-21 cells off its 170 spawn, under nothing but its own wheels. That is the pin - not where the
	# fight leaves it: the Dozer comes to meet it at x ~206 and the pair shove each other from there, so
	# the ends measured 206-296 over 14 runs (36-126 cells of travel). A loaded chariot whose wheels
	# were buried moved 0 with these same keys; at the old x = 60 spawn the player crossed the pit
	# alone (180-220 cells) because the Dozer started 360 away.
	assert_true(float(driven["mark"]) - float(ChArenaBuilder.SPAWN_LEFT_X) > 10.0,
		"the player's chariot drove off its spawn (at x %.0f two seconds in, hulls %.0f apart at the end)"
			% [driven["mark"], min_gap])
	assert_true(frozen > 0, "the Mace's hull hits froze the Dozer's parts (see above)")
	battle.free()
	_complete()


func test_stepped_fires_every_tick_and_drivers_override() -> void:
	var battle := _battle_scene()
	var ticks := [0]
	battle.stepped.connect(func(_ctx): ticks[0] += 1)
	# Player charges, enemy holds: the player must close distance.
	battle.drivers = [func(b, s): return 1.0, func(b, s): return 0.0]
	var start_gap := [-1.0]
	battle.stepped.connect(func(ctx):
		if start_gap[0] < 0.0:
			start_gap[0] = absf(ctx.chariots[1].chassis.global_position.x - ctx.chariots[0].chassis.global_position.x))
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1)
	assert_eq(ticks[0], int(round(battle.ctx.time / ChBattle.TICK)), "one stepped per tick, last tick included")
	var end_gap := absf(battle.enemy.chassis.global_position.x - battle.player.chassis.global_position.x)
	assert_true(end_gap < start_gap[0], "the charging player closed the gap")
	battle.free()
	_complete()


func test_ai_drive_is_symmetric() -> void:
	# ai_drive on side 0 decides toward side 1 with the same rule the enemy uses.
	var battle := _battle_scene()
	battle.drivers = [func(b, s): return b.ai_drive(s), Callable()]
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "an AI-driven player still finishes the fight")
	battle.free()
	_complete()


# --- The button (Task 2) ----------------------------------------------------------------------------
func _count_fired(battle: Node2D, side_counts: Array) -> void:
	var key := RefCounted.new()
	battle.ctx.bus.subscribe(key, ChEvent.PART_FIRED, func(event: ChEvent): side_counts[event.side] += 1)
	battle.set_meta("fire_key", key)  # the bus holds the key weakly: keep it alive with the battle


func test_never_press_fires_nothing() -> void:
	var battle := _battle_scene()
	battle.pressers = [func(_b, _s): return false, func(_b, _s): return false]
	_start_fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP))
	await _frames_ready(battle)
	var counts := [0, 0]
	_count_fired(battle, counts)
	for _i in 120:
		await Engine.get_main_loop().process_frame
	assert_eq(counts, [0, 0], "ready parts sit unfired for 2 s when nobody presses")
	battle.free()
	_complete()


func _frames_ready(battle: Node2D) -> void:
	await Engine.get_main_loop().process_frame


func test_held_key_fires_once() -> void:
	var battle := _battle_scene()
	battle.pressers[0] = Callable()  # the real key
	battle.pressers[1] = func(_b, _s): return false
	var layout := _garage_built(&"corsair", [[[6], &"cutter_chainsaw"]])
	_start_fight(battle, layout, _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP))
	await _frames_ready(battle)
	var counts := [0, 0]
	_count_fired(battle, counts)
	# Parts start on a full cooldown; ready the saw so the press has something to fire (a press
	# at tick 1 would be a dud, and a held key never presses again).
	for part in battle.player.parts:
		part.cooldown_left = 0.0
	Input.action_press(&"fire")
	for _i in 120:
		await Engine.get_main_loop().process_frame
	Input.action_release(&"fire")
	assert_eq(counts[0], 1, "Space held for 120 ticks is one press: one volley, the Chainsaw once")
	battle.free()
	_complete()


func test_dud_press_nudges_hull() -> void:
	var battle := _battle_scene()
	battle.pressers = [func(_b, _s): return true, func(_b, _s): return false]
	_start_fight(battle, _player_layout(), _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP))
	# Every part cooling down: nothing is ready, so each press is a dud.
	for part in battle.player.parts:
		part.cooldown_left = 100.0
	var juice := ChJuice.of(battle.player.chassis_visual)
	await Engine.get_main_loop().process_frame
	assert_true(not is_zero_approx(juice.scale_spring.velocity), "a dud press kicked the hull")
	battle.free()
	_complete()
