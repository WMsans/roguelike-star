class_name ChBattle extends Node2D

# Task 15: one fight, in one place. This scene owns the arena, the two chariots, the tick loop and
# the result, so game/ has exactly one fight: ChMain (Task 16) wraps this scene and ChArenaBuilder
# / ChChariotBuilder / ChBattleContext stay its only parts. It is also the one place that calls
# behaviour.setup(ctx) — without that call the subscribing behaviours (Ember Battery, Rocket
# Ignition) are dead in a real fight, which is what Tasks 12-14 left a note about.
# start() runs the fight as a coroutine, one ctx.tick per awaited frame (the world runs its own
# sim steps on those frames, see _step), so a
# headless test drives the same loop the game runs on screen: the fight's clock is the fixed TICK,
# not the host's frame rate, which is what makes a 60 s fight deterministic.
# HUD and camera follow the brief: the HUD (ChBattleHud, on ChUi's shared theme) shows both sides'
# names and HP, the player's energy as pips with the volley a press would spend marked on them; the camera frames the two
# chariots (the shot lives on the scene's PhantomCamera2D, `pcam`, which the Camera2D's host copies), a
# marker sits on every part, and the bus's events are played by the battle's own ChBattleFeedback.
# Feedback's screen shake lands on the scene's own noise emitter while a fight runs.
# There is no event feed and no hint line anywhere: the screen shows the fight, not a log of it.

# &"win", &"loss" or &"draw" from the fight, &"aborted" if it could not start
signal finished(result: StringName)
# Once per fight tick, after ctx.tick and before the result check, so the fight's last tick is
# included. The balance runner samples a fight here; nothing in the game listens.
signal stepped(ctx: ChBattleContext)

const ARENA := Rect2i(0, 0, 480, 180)
const VIEW := Vector2(1280, 720)  # project.godot's viewport: the HUD lays out in these pixels
const TICK := 1.0 / 60.0  # one 60 fps frame: the delta every part, cooldown and pool counts against
const FIGHT_TICKS := 3600  # 60 s of ticks: the ceiling the brief gives a fight
const WORLD_WAIT := 600  # frames the world is given to load before the arena fill starts
const CAMERA_MARGIN := 48.0  # cells of arena kept beside both chariots when the camera zooms
const ZOOM_WIDEST := 4.0  # the pull-back bound: its view is 320x180 cells, exactly the pit's height
# The magnify bound: the pit around a brawl is part of the read, so a fight frames at least a
# 284x160-cell view rather than filling the screen with two hulls (8.0 here showed 160x90).
const ZOOM_CLOSEST := 4.5
const CAMERA_EASE := 0.15  # the share of the remaining gap the camera covers per fight tick
const READY_GLOW := Color(2.4, 2.0, 0.6)  # above 1 on purpose: the battle's hdr_2d lets an HDR modulate bloom
const READY_PULSE_HZ := 2.0  # the glow breathes at this rate so it reads as live, not as paint
const MARKER_Z := 10  # the marker layer's z_index: above every body, which all sit at 0
# The bright look. The world's light overlay multiplies the whole lit area, sky included, so a full
# ambient is what stops it greying the pit and the parallax sky behind it; LIGHT_HEADROOM lets fire
# and lava lift cells above their own colour, which only survives the multiply on an HDR canvas: the
# battle turns hdr_2d on for its viewport while it is in the tree (see _enter_tree). The backdrop goes transparent so the air shows the ChBackground layer.
const AMBIENT := 1.0
const AMBIENT_TINT := Color(1.0, 0.98, 0.94)
const LIGHT_HEADROOM := 1.8
const BACKDROP := Color(0, 0, 0, 0)

var ctx: ChBattleContext = null
var world: PixelWorld = null
var player: ChChariotRuntime = null  # side 0
var enemy: ChChariotRuntime = null  # side 1
var ai: ChEnemyAI = null  # the enemy's drive decision
var camera: Camera2D = null
var pcam: PhantomCamera2D = null  # the live shot: the host under $Camera drives it from here
var hud: ChBattleHud = null  # the HUD itself, a Control under the $HUD CanvasLayer
var marks: Node2D = null  # the per-part markers, drawn in the world layer
var feedback: ChBattleFeedback = null  # the bus listener that turns this fight's events into beats
var outcome := &""  # what this fight decided, once _step names it; "" while neither hull is dead
var _hdr_before := false  # the viewport's use_hdr_2d before this battle turned it on
var _camera_primed := false  # the live camera has been put on a composed frame at least once
var started := false  # read-only: start() has passed its arena build and may still be ticking
var ticking := false  # read-only: start()'s tick loop is running now (see the contract below)
# CONTRACT: one entry per side. A valid Callable `func(battle: ChBattle, side: int) -> float`
# replaces that side's drive; an empty one keeps the default (held keys for side 0, the AI for
# side 1). A headless run has no input, so the balance runner drives the player through here.
# shortcut: untyped, because a caller holding the battle as Node2D assigns a plain Array literal and
# Godot refuses that for an Array[Callable] property.
var drivers: Array = [Callable(), Callable()]
var _fire_held := false  # the fire key's state at the previous fight tick: _player_press's edge
# CONTRACT: the same shape for the button: a valid `func(battle: ChBattle, side: int) -> bool`
# replaces that side's press (true = the button went down this tick). The defaults are the Space key's
# edge for side 0 and ChEnemyAI.should_press for side 1. A headless run has no keys, so tests and the
# balance runner press the player through here.
var pressers: Array = [Callable(), Callable()]


func _init() -> void:
	# Only the input actions go here: a scene's own nodes ($Camera, $HUD) are not in the tree yet
	# while _init runs, so the HUD is built when the fight starts.
	_add_input_actions()


func _enter_tree() -> void:
	# HDR is the battle's alone: the garage shares the root viewport and keeps the 8-bit, sRGB-blended
	# canvas its UI was laid out on, so the battle hands the viewport back as it found it.
	_hdr_before = get_viewport().use_hdr_2d
	get_viewport().use_hdr_2d = true


func _add_input_actions() -> void:
	# The brief's input actions: ui_left/ui_right are built in, A/D are not, and both are added
	# only when missing so a project that already binds them keeps its own binding. `fire` (Space) is
	# the one button: it is a new action, so it is added first when missing.
	# shortcut: physical_keycode only, so an "A" with a modifier key reads as a different event.
	for pair in [[&"ui_left", KEY_A], [&"ui_right", KEY_D]]:
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], key):
			InputMap.action_add_event(pair[0], key)
	if not InputMap.has_action(&"fire"):
		InputMap.add_action(&"fire")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	if not InputMap.action_has_event(&"fire", space):
		InputMap.action_add_event(&"fire", space)


func _build_hud() -> void:
	# The HUD is one Control in the viewport's pixels under the CanvasLayer, which ignores the camera:
	# a 60-cell zoom cannot move the HUD. ChBattleHud needs no size from here — it fills the layer in
	# its own _ready and lays its two blocks out against the viewport's corners.
	hud = ChBattleHud.new()
	# shortcut: this build's CanvasLayer exposes no writable size (get_property_list lists only
	# layer/offset/rotation/scale/transform/canvas_items/...), so the layer's pixels are the viewport's
	# by construction — project.godot sets 1280x720 and ChBattleHud lays out in those.
	$HUD.add_child(hud)
	# The marker container is made here and parented in _build_world: it belongs to the world's Node2D
	# layer, not this CanvasLayer, so the camera's position and zoom are what put the markers on the
	# parts (a CanvasLayer would draw them at raw arena numbers, on nothing).
	marks = Node2D.new()
	# Draw order sorts by z_index before tree order, so the markers need a layer of their own or the
	# hulls added later would bury them; no body or node under game/ sets z_index, so MARKER_Z clears them.
	marks.z_index = MARKER_Z
	marks.draw.connect(_draw_markers)


func start(player_layout: ChChariotLayout, enemy_layout: ChChariotLayout,
	catalog: ChCatalog, seed: int) -> void:
	# The whole fight, once: arena, two builds, the setup calls every behaviour subscribes on, then
	# the ticks. The ticks stop at the result, and a fight nobody dies in stops at its own budget, so
	# `finished` follows an ended fight rather than announcing a result mid-fight.
	# shortcut: one fight per scene — start() builds the HUD and the arena from scratch, so a caller
	# that wants a second fight instantiates the scene again rather than reusing this node's nodes.
	outcome = &""
	camera = $Camera
	pcam = $PCam
	_camera_primed = false
	_build_hud()
	# CONTRACT: every path that cannot run a fight emits `finished` with &"aborted" — the two fight
	# results stay &"win"/&"loss" — so a caller awaiting the signal never hangs on a broken arena.
	if not await _build_world(seed):
		finished.emit(&"aborted")
		return
	# Feedback reads this fight's world and shakes this fight's camera. The scope is this battle, not the
	# world: the chariot bodies are its children and the HUD's CanvasLayer sits here too, which is the
	# routing Task 5's particle path reads. _exit_tree unbinds both.
	Feedback.bind_shake($Shake)
	Feedback.bind_world(world, self)
	var spawn: Dictionary = ChArenaBuilder.build(world, seed)
	if not spawn.has("spawn_left") or not spawn.has("spawn_right") or not _arena_landed():
		# fill_rect answers 0 cells for a grid that never loaded, so the counts are the arena's own
		# evidence; a push_error alone would let the chariots fall through nothing.
		push_error("battle: the arena holds no ground, so the fight cannot run")
		finished.emit(&"aborted")
		return
	# The enemy is the same layout read the other way round: mirrored() inverts its flips and
	# mirror_x negates its anchors, so its parts face the player (spec 5.9).
	player = ChChariotBuilder.build(world, self, player_layout, catalog, 0, spawn["spawn_left"],
		false)
	enemy = ChChariotBuilder.build(world, self, enemy_layout.mirrored(), catalog, 1,
		spawn["spawn_right"], true)
	if player == null or enemy == null:
		push_error("battle: a chariot did not build, so the fight cannot run")
		finished.emit(&"aborted")
		return
	ctx = ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	var rigs: Array[ChChariotRuntime] = [player, enemy]
	ctx.chariots = rigs
	ai = ChEnemyAI.new()
	for rig in rigs:
		for part in rig.parts:
			# The setup call Tasks 12-14 wait for: it is where a behaviour subscribes, so without
			# it a subscribing part (Rocket's Ignition, Ember Battery) is dead in a real fight.
			if part.behaviour != null:
				part.behaviour.setup(ctx)
	# The bus's events, played: one listener key for the seven types, held here so the fight keeps it.
	feedback = ChBattleFeedback.new(ctx, hud)
	feedback.subscribe()
	# CONTRACT: `finished` is the fight's end, not an announcement made while it runs. It fires once,
	# from the last statement of start() on every leg, with `ticking` false - the loop has stopped, or
	# never started - so a listener may free this node on any later frame: there is no suspended
	# coroutine under it. The world is the one difference between the legs: the fight's own result sets
	# `world.simulating` false with the loop, while the three `aborted` legs emit with the world built
	# but never run, so its sim flag is still true. Freeing is safe on all of them because the world is
	# a child of this node and leaves the tree with it. Freeing before that is still forbidden - both
	# start() legs (streaming the arena, then the ticks) are a coroutine that resumes on the tree's own
	# frames, so freeing the node mid-await deletes the object it resumes into.
	# shortcut: there is no stop: a caller that wants a fight over early has to wait for its loop,
	# because ending a fight on someone else's say-so is not part of ChBattle's contract.
	started = true
	ticking = true
	# One ctx.tick per awaited frame until someone dies: _step stores the result it sees and the break
	# ends the fight. A fight with no result still spends its FIGHT_TICKS frames, so a draw is the
	# fight's own budget running out and never another node's clock.
	for _tick in FIGHT_TICKS:
		_step(TICK)
		if outcome != &"":
			break
		await get_tree().process_frame
	ticking = false
	# The world's own switch (pixel_world.cpp:331 gates the sim step on it) goes off with the loop, so
	# a finished fight leaves nothing simulating behind it - which is what makes the free above safe.
	world.simulating = false
	# The loop ended with neither hull dead: the time limit ran out, and that is a result too.
	finished.emit(outcome if outcome != &"" else &"draw")

static func result_for(player_dead: bool, enemy_dead: bool) -> StringName:
	# Review Focus 4: both chariots reaching 0 HP on one tick is the player's loss. A Ring of Fire
	# pays its own chassis as it expands, so one tick really can end both, and the fight must
	# resolve rather than hang or call itself a win.
	if player_dead:
		return &"loss"
	if enemy_dead:
		return &"win"
	return &""  # neither dead is not a result, which is what the fight loop tests against


func _build_world(seed: int) -> bool:
	# ChTest.make_world's shape, in game/: the material set, the arena and the indestructible border
	# go on the world before it joins the tree, because PixelWorld's _ready bails out when the set is
	# missing — and the arena is then given frames to stream its chunks before anything fills it.
	world = PixelWorld.new()
	world.material_set = ResourceLoader.load("res://game/materials/game_set.tres")
	world.arena = ARENA
	world.arena_border_material = &"concrete"
	world.ambient = AMBIENT
	world.ambient_tint = AMBIENT_TINT
	world.light_headroom = LIGHT_HEADROOM
	world.backdrop_color = BACKDROP
	# The arena streams a window of chunks around its target cell, and a chunk is 64 cells, so the
	# window has to reach the chunk holding the arena's far corner or is_area_ready never turns true
	# (the same reading ChTest.make_world takes, and the reason a fill would silently write nothing).
	# shortcut: the window stays centred on chunk (0,0), which holds while the fight leaves follow_target
	# unset; a battle that follows a node has to widen around that chunk instead.
	var near_chunk := Vector2i(floori(ARENA.position.x / 64.0), floori(ARENA.position.y / 64.0))
	var far_chunk := Vector2i(floori((ARENA.end.x - 1) / 64.0), floori((ARENA.end.y - 1) / 64.0))
	world.load_radius = Vector2i(maxi(absi(near_chunk.x), absi(far_chunk.x)),
		maxi(absi(near_chunk.y), absi(far_chunk.y)))
	add_child(world)
	# The markers go under the world, so their arena numbers get the camera's transform like the parts
	# do; under the HUD CanvasLayer they sat at raw world numbers, on nothing.
	world.add_child(marks)
	var frames := 0
	while not world.is_area_ready(ARENA):
		frames += 1
		if frames >= WORLD_WAIT:
			push_error("battle: the arena %s never loaded after %d frames" % [ARENA, frames])
			return false
		await get_tree().process_frame
	return true


func _exit_tree() -> void:
	# HDR is the battle's alone: the garage shares the root viewport, so hand it back as it was found.
	get_viewport().use_hdr_2d = _hdr_before
	# The manager holds nodes from this fight (the world for particle routing, the emitter for shake);
	# a battle that leaves the tree must not leave them bound. Both are children of this node and go
	# with it, which is why the unbind is the whole cleanup. The world is also the marker that this
	# fight bound them at all: a scene freed before start() must not unbind another fight's world.
	if ctx != null and feedback != null:
		# The feedback holds ctx and the bus holds the feedback, so dropping the listener is what
		# lets this fight's bus/context/runtime graph go; without it every fight leaks one.
		ctx.bus.unsubscribe_all(feedback)
	if world != null:
		Feedback.unbind_shake()
		Feedback.unbind_world()


func _arena_landed() -> bool:
	# The fill's own evidence, per the arena builder's note: an unloaded grid answers 0 cells, so
	# a fight that found no sand and no rock has nothing to stand on.
	var counts: Dictionary = world.count_materials(ARENA)
	return counts.get(&"sand", 0) > 0 and counts.get(&"rock", 0) > 0


func _step(delta: float) -> void:
	# One fight tick: both sides' drives, the loop, the sim, the HUD and the win/lose check.
	# The drive decision is ChEnemyAI's, paid by ChEnergy inside ChBattleContext.tick exactly like
	# the player's, which is the spec's "it pays the same energy rules".
	if not _alive(player) or not _alive(enemy):
		# A side whose hull is gone has no position to aim from, no hull to drive and nothing to frame.
		# Nothing under game/ frees a chassis (break_part leaves a broken part's body in the world),
		# but the branch's own seam queue_frees one mid-fight, so the per-tick path uses the same
		# liveness check the rest of the fight uses instead of reading it blind. The frames still run,
		# so a fight that lost a hull ends on its budget: only HP reaching 0 names a result.
		return
	# Half a hull each along the axis the fight lines the two chariots up on: the centre-to-centre gap
	# that keeps the two boxes apart. ChEnemyAI holds at least this far out, so an enemy whose shortest
	# reach is the Mace's 6 cells (measured from a part on the hull's edge) still stops outside the
	# player's hull instead of grinding into it.
	var drives: Array[float] = [
		drivers[0].call(self, 0) if drivers[0].is_valid() else _player_drive(),
		drivers[1].call(self, 1) if drivers[1].is_valid() else ai_drive(1)]
	var presses: Array = [
		pressers[0].call(self, 0) if pressers[0].is_valid() else _player_press(),
		pressers[1].call(self, 1) if pressers[1].is_valid() else ai_press(1)]
	var fired := ctx.tick(delta, drives, presses)
	# A press that fired nothing is a dud: the hull flinches, so the button always answers. Feedback
	# is visual only, so a hull without a visual (a fake rig, a freed body) just skips it.
	if presses[0] and fired[0] == 0 and player.chassis_visual != null \
			and is_instance_valid(player.chassis_visual):
		Feedback.play(&"nudge", player.chassis_visual)
	_show_ready()
	stepped.emit(ctx)
	# The world runs its own simulation steps on the physics frames this tick awaited, which is the
	# seam ChProjectile flies on (Task 13's ruling): adding world.step here would run the sim twice
	# per tick and double every chariot's movement against the fight's clock.
	_hud_tick()
	_camera_at()
	var result := result_for(player.is_dead(), enemy.is_dead())
	if result != &"":
		# Stored, not emitted: the loop in start() breaks on this and then speaks, so `finished` only
		# ever arrives with the fight already over (see the contract there).
		outcome = result


func _show_ready() -> void:
	# Lights the outline of every part a press would fire right now (is_ready), and hides it again
	# once the press spends the part. Outline only, no fill tint and no count: the rim is the whole cue.
	# Run after ctx.tick so it shows the state the player is about to act on.
	# The builder does not flip a Visual for a flipped slot (the art is mirrored by its anchor
	# only), so the outline, which is the same shape, needs no flip either.
	var pulse := 0.75 + 0.25 * sin(TAU * READY_PULSE_HZ * ctx.time)
	for chariot in [player, enemy]:
		for part in chariot.parts:
			if part.outline == null or not is_instance_valid(part.outline):
				continue
			var ready: bool = part.is_ready()
			part.outline.visible = ready
			if ready:
				part.outline.modulate = Color(READY_GLOW.r * pulse, READY_GLOW.g * pulse, READY_GLOW.b * pulse, 1.0)


func ai_drive(side: int, style: StringName = &"") -> float:
	# ChEnemyAI's decision for either side, toward the other chariot: side 1 is the enemy's own drive,
	# and side 0 lets a headless run drive the player by the same rule. A non-empty style overrides
	# the body's drive_style (the balance runner's kite and brawl policies).
	var me := player if side == 0 else enemy
	var other := enemy if side == 0 else player
	return ai.decide(me.chassis.global_position.x, other.chassis.global_position.x,
		ai.reach(me), _half_width(me), _half_width(other), style if style != &"" else me.body_def.drive_style)


func ai_press(side: int) -> bool:
	# ChEnemyAI's press decision for either side, toward the other chariot (see ai_drive).
	var me := player if side == 0 else enemy
	var other := enemy if side == 0 else player
	return ChEnemyAI.should_press(me, other.chassis.global_position.x, _half_width(other))


func _player_press() -> bool:
	# The button's edge: holding Space fires once, so the volley is a decision and not a held key.
	# The edge is derived from the held state against the previous fight tick's, not read from
	# is_action_just_pressed: that one is keyed to the engine's own frame, and the fight ticks on
	# process frames, so a press injected between them (a test's, or a key tapped inside one
	# physics frame) could be missed or counted twice. The fight's own clock is the one that counts.
	var held := Input.is_action_pressed(&"fire")
	var edge := held and not _fire_held
	_fire_held = held
	return edge


func _player_drive() -> float:
	# The held direction, -1/0/1: ui_left/ui_right plus the A/D keys _add_input_actions put in.
	var left := -1.0 if Input.is_action_pressed(&"ui_left") else 0.0
	return left + (1.0 if Input.is_action_pressed(&"ui_right") else 0.0)


func _hud_tick() -> void:
	# The HUD reads the fight's numbers, then the markers redraw over the parts they mark.
	hud.show_state(player, enemy, ctx.volley_cost(player))
	marks.queue_redraw()


func _camera_at() -> void:
	# Midpoint of both chassis framed close: camera_frame composes the shot and the live shot (the pcam)
	# eases toward it from the second tick on, so a chase glides between ticks instead of jumping; the
	# Camera2D only follows the pcam through its host. The first tick takes the shot outright: the scene's
	# pcam starts at (0,0) zoom 1, and easing from it would open every fight on the whole pit, tiny, with
	# world outside ARENA in frame.
	if not _alive(player) or not _alive(enemy):
		# The frame a hull went missing: the camera keeps the last frame it could compose rather than
		# reading a freed position.
		return
	# The box the camera has to show: both hulls end to end plus the margin, so a Dozer and a Cutter
	# get one frame whatever their lengths.
	var pad := Vector2(maxf(hull_box(player).size.x, hull_box(enemy).size.x),
		maxf(hull_box(player).size.y, hull_box(enemy).size.y)) * 0.5
	pad += Vector2(CAMERA_MARGIN, CAMERA_MARGIN)
	var want: Dictionary = camera_frame(player.chassis.global_position,
		enemy.chassis.global_position, pad)
	var step: Dictionary = camera_eased(pcam.global_position, pcam.zoom.x, want, _camera_primed)
	_camera_primed = true
	pcam.global_position = step["at"]
	# One number, put back on both axes, so the frame never goes anamorphic.
	var zoom := float(step["zoom"])
	pcam.zoom = Vector2(zoom, zoom)


static func camera_eased(from_at: Vector2, from_zoom: float, want: Dictionary,
		primed: bool) -> Dictionary:
	# The first tick has no frame behind it: battle.tscn's pcam sits at (0,0) zoom 1, so easing from
	# there would open every fight on the whole pit, tiny and off-centre, for the ~15 ticks the glide
	# takes to climb to its shot - and show world outside ARENA while it did. Primed, the fight opens
	# on the shot; every tick after that eases CAMERA_EASE of the remaining gap.
	if not primed:
		return {"at": want["at"], "zoom": float(want["zoom"])}
	var zoom := lerpf(from_zoom, float(want["zoom"]), CAMERA_EASE)
	return {"at": from_at + ((want["at"] as Vector2) - from_at) * CAMERA_EASE, "zoom": zoom}


static func camera_frame(a: Vector2, b: Vector2, pad: Vector2) -> Dictionary:
	# The shot that holds both chariots: the a–b span plus pad on every side, magnified as far as
	# the bounds allow. Godot 4 divides the viewport by the zoom (the view is VIEW / zoom), so a
	# bigger number is a closer shot — the opposite of the box / VIEW multiply this replaces, which is
	# why a fight at 320x180 showed neither chariot.
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - pad
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + pad
	var box := Rect2(lo, hi - lo)
	# The biggest zoom that still fits the box on both axes: whichever axis runs out first.
	var zoom := clampf(minf(VIEW.x / box.size.x, VIEW.y / box.size.y), ZOOM_WIDEST, ZOOM_CLOSEST)
	# Then snap down to a half step: a zoom that slides between ticks makes the world's pixels
	# shimmer. Clamping wins over snapping, so a snap past a bound goes back to that bound.
	zoom = clampf(floorf(zoom / 0.5) * 0.5, ZOOM_WIDEST, ZOOM_CLOSEST)
	var view := VIEW / zoom
	# The centre, pushed back into the pit so the view never shows the world outside the arena.
	# At ZOOM_WIDEST the view is 320x180 cells, no wider or taller than ARENA, so clampf's min never
	# sits above its max — which is what used to park the camera against one wall.
	var at := box.get_center()
	at.x = clampf(at.x, ARENA.position.x + view.x * 0.5, ARENA.end.x - view.x * 0.5)
	at.y = clampf(at.y, ARENA.position.y + view.y * 0.5, ARENA.end.y - view.y * 0.5)
	return {"at": at, "zoom": zoom}


func _alive(chariot: ChChariotRuntime) -> bool:
	# The fight's own liveness check: the same is_instance_valid that ChBehaviour._bodies,
	# ChChariotRuntime.drive and ChHarpoon.process already use. The per-tick path read both chassis
	# unguarded, which is the inconsistency the review named: a freed hull is a freed read that stops
	# the fight mid-body instead of letting it run out.
	return chariot != null and chariot.chassis != null and is_instance_valid(chariot.chassis)


func _half_width(chariot: ChChariotRuntime) -> float:
	# Half the hull along x, the axis the two chariots face each other on.
	return maxi(1, chariot.body_def.size.x) * 0.5


static func hull_box(chariot: ChChariotRuntime) -> Rect2:
	# The chassis box in arena cells, the same reading ChBehaviour's _hull_box takes.
	var size := Vector2(maxi(1, chariot.body_def.size.x), maxi(1, chariot.body_def.size.y))
	return Rect2(chariot.chassis.global_position - size * 0.5, size)


func _draw_markers() -> void:
	# The per-part markers, drawn in the world layer: the mapping to the marker container is read off
	# both global transforms, so the camera's position and zoom are what land a marker on its part.
	if marks == null or world == null:
		return
	var onto := marks.get_global_transform().affine_inverse() * world.get_global_transform()
	for rig in [player, enemy]:
		if rig == null or not _alive(rig):
			continue
		for part in rig.parts:
			if part.def == null:
				continue
			if part.body == null or not is_instance_valid(part.body):
				# A part whose body left the world has no place to mark.
				continue
			if not (part.broken or part.burning or part.is_frozen()):
				continue
			var size := Vector2(maxi(1, part.def.size.x), maxi(1, part.def.size.y))
			var at: Vector2 = onto * part.anchor_world()
			var box := Rect2(at - size * 0.5, size)
			if part.is_frozen():
				marks.draw_rect(box, Color(0.2, 0.4, 1.0, 0.4), true)  # blue tint
			if part.burning:
				marks.draw_rect(box, Color(1.0, 0.15, 0.1), false)  # red outline
			if part.broken:
				# An X: the wreck is out of the fight, and its body is still lying in the sand.
				marks.draw_line(box.position, box.end, Color(1.0, 1.0, 1.0))
				marks.draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y),
					Color(1.0, 1.0, 1.0))
