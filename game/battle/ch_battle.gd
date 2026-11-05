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
# HUD and camera follow the brief: HP bars both sides, the player's energy bar with queue-size pips,
# the last 4 events as text, a marker per part, and a 0.2 s pulse on a part the player just fired.

# &"win", &"loss" or &"draw" from the fight, &"aborted" if it could not start
signal finished(result: StringName)

const ARENA := Rect2i(0, 0, 480, 180)
const VIEW := Vector2(1280, 720)  # project.godot's viewport: the HUD lays out in these pixels
const TICK := 1.0 / 60.0  # one 60 fps frame: the delta every part, cooldown and pool counts against
const FIGHT_TICKS := 3600  # 60 s of ticks: the ceiling the brief gives a fight
const WORLD_WAIT := 600  # frames the world is given to load before the arena fill starts
const CAMERA_MARGIN := 24.0  # cells of arena kept beside both chariots when the camera zooms
const ZOOM_WIDEST := 4.0  # the pull-back bound: its view is 320x180 cells, exactly the pit's height
const ZOOM_CLOSEST := 8.0  # the magnify bound: closer than this and a chariot outruns its own frame
const CAMERA_EASE := 0.15  # the share of the remaining gap the camera covers per fight tick
const PULSE_SECONDS := 0.2  # the HUD's pulse on a part the player just fired
const TICKER_LINES := 4  # events the ticker keeps
const BAR := 64.0  # HP/energy bar width in pixels
const BAR_H := 5.0  # and height
const MARKER_Z := 10  # the marker layer's z_index: above every body, which all sit at 0

var ctx: ChBattleContext = null
var world: PixelWorld = null
var player: ChChariotRuntime = null  # side 0
var enemy: ChChariotRuntime = null  # side 1
var ai: ChEnemyAI = null  # the enemy's drive decision
var camera: Camera2D = null
var hud: CanvasLayer = null  # the HUD's root layer, at the viewport's 1280x720
var marks: Node2D = null  # the per-part markers, drawn in the world layer
var bars: Array[ColorRect] = []  # [player HP fill, enemy HP fill, player energy fill]
var pips: Array[ColorRect] = []  # queue-size pips, made on demand
var ticker_labels: Array[Label] = []
var ticker_text: Array[String] = []  # the ticker's lines, oldest first
var pulses: Array = []  # of {"part": ChPartRuntime, "left": seconds}
var hud_listener: RefCounted = null  # the key the HUD's subscriptions unsubscribe under
var outcome := &""  # what this fight decided, once _step names it; "" while neither hull is dead
var started := false  # read-only: start() has passed its arena build and may still be ticking
var ticking := false  # read-only: start()'s tick loop is running now (see the contract below)


func _init() -> void:
	# Only the input actions go here: a scene's own nodes ($Camera, $HUD) are not in the tree yet
	# while _init runs, so the HUD is built when the fight starts.
	_add_input_actions()


func _add_input_actions() -> void:
	# The brief's input actions: ui_left/ui_right are built in, A/D are not, and both are added
	# only when missing so a project that already binds them keeps its own binding.
	# shortcut: physical_keycode only, so an "A" with a modifier key reads as a different event.
	for pair in [[&"ui_left", KEY_A], [&"ui_right", KEY_D]]:
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], key):
			InputMap.action_add_event(pair[0], key)


func _build_hud() -> void:
	# Bars, pips and ticker lines lay out in viewport pixels under the CanvasLayer, which ignores
	# the camera: a 60-cell zoom cannot move the HUD.
	hud = $HUD
	# shortcut: this build's CanvasLayer exposes no writable size (get_property_list lists only
	# layer/offset/rotation/scale/transform/canvas_items/...), so the layer's pixels are the viewport's
	# by construction — project.godot sets 1280x720 and every piece below lays out in VIEW.
	_bar(hud, 0, 6.0, 6.0)  # player HP
	_bar(hud, 1, VIEW.x - BAR - 6.0, 6.0)  # enemy HP
	_bar(hud, 2, 6.0, 16.0)  # player energy
	for at in TICKER_LINES:
		var label := Label.new()
		# 150 rather than 156: four 8px lines at a 6px pitch end at 174, and 156 put the fourth
		# line's glyphs past the bottom edge of the 320x180 viewport this ticker was laid out in
		# (measured on the display; the 1280x720 viewport leaves the line where it is until Task 5).
		label.position = Vector2(6.0, 150.0 + at * 6.0)
		label.add_theme_font_size_override("font_size", 8)
		label.text = ""
		hud.add_child(label)
		ticker_labels.append(label)
	# The marker container is made here and parented in _build_world: it belongs to the world's Node2D
	# layer, not this CanvasLayer, so the camera's position and zoom are what put the markers on the
	# parts (a CanvasLayer would draw them at raw arena numbers, on nothing).
	marks = Node2D.new()
	# Draw order sorts by z_index before tree order, so the markers need a layer of their own or the
	# hulls added later would bury them; no body or node under game/ sets z_index, so MARKER_Z clears them.
	marks.z_index = MARKER_Z
	marks.draw.connect(_draw_markers)


func _bar(canvas: CanvasLayer, kind: int, at_x: float, at_y: float) -> void:
	# A bar is a dark backing plus a fill whose width carries the fraction; the fill is what the
	# HUD updates every tick.
	var back := ColorRect.new()
	back.position = Vector2(at_x, at_y)
	back.size = Vector2(BAR, BAR_H)
	back.color = Color(0.1, 0.1, 0.12, 0.9)
	canvas.add_child(back)
	var front := ColorRect.new()
	front.position = Vector2(at_x, at_y) + Vector2(1.0, 1.0)
	front.size = Vector2(BAR - 2.0, BAR_H - 2.0)
	front.color = [Color(0.3, 0.75, 0.35), Color(0.8, 0.3, 0.25), Color(0.95, 0.8, 0.3)][kind]
	canvas.add_child(front)
	bars.append(front)


func start(player_layout: ChChariotLayout, enemy_layout: ChChariotLayout,
	catalog: ChCatalog, seed: int) -> void:
	# The whole fight, once: arena, two builds, the setup calls every behaviour subscribes on, then
	# the ticks. The ticks stop at the result, and a fight nobody dies in stops at its own budget, so
	# `finished` follows an ended fight rather than announcing a result mid-fight.
	# shortcut: one fight per scene — start() builds the HUD and the arena from scratch, so a caller
	# that wants a second fight instantiates the scene again rather than reusing this node's nodes.
	# The HUD collections are cleared here so a second call cannot write the first fight's nodes.
	bars.clear()
	pips.clear()
	ticker_labels.clear()
	ticker_text.clear()
	pulses.clear()
	outcome = &""
	camera = $Camera
	_build_hud()
	# CONTRACT: every path that cannot run a fight emits `finished` with &"aborted" — the two fight
	# results stay &"win"/&"loss" — so a caller awaiting the signal never hangs on a broken arena.
	if not await _build_world(seed):
		finished.emit(&"aborted")
		return
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
	_subscribe_hud()
	# CONTRACT: `finished` is the fight's end, not an announcement made while it runs. It fires once,
	# after the tick loop has stopped, with `ticking` already false and `world.simulating` already
	# false, so a listener may free this node on any later frame: there is no suspended coroutine and
	# no simulating world left under it. Freeing before that is still forbidden - both start() legs
	# (streaming the arena, then the ticks) are a coroutine that resumes on the tree's own frames, so
	# freeing the node mid-await deletes the object it resumes into.
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
	var drives: Array[float] = [_player_drive(),
		ai.decide(enemy.chassis.global_position.x, player.chassis.global_position.x,
			ai.reach(enemy), _half_width(enemy), _half_width(player))]
	ctx.tick(delta, drives)
	# The world runs its own simulation steps on the physics frames this tick awaited, which is the
	# seam ChProjectile flies on (Task 13's ruling): adding world.step here would run the sim twice
	# per tick and double every chariot's movement against the fight's clock.
	_hud_tick(delta)
	_camera_at()
	var result := result_for(player.is_dead(), enemy.is_dead())
	if result != &"":
		# Stored, not emitted: the loop in start() breaks on this and then speaks, so `finished` only
		# ever arrives with the fight already over (see the contract there).
		outcome = result


func _player_drive() -> float:
	# The held direction, -1/0/1: ui_left/ui_right plus the A/D keys _add_input_actions put in.
	var left := -1.0 if Input.is_action_pressed(&"ui_left") else 0.0
	return left + (1.0 if Input.is_action_pressed(&"ui_right") else 0.0)


func _subscribe_hud() -> void:
	# The HUD hears every event type through one listener key, so the ticker sees the chain a part
	# caused (caught_fire, then energy_gained) and the pulse sees the player's own fires. The listener
	# needs no unsubscribing: the bus belongs to this fight's context and dies with it.
	hud_listener = RefCounted.new()
	for type in [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.CAUGHT_FIRE, ChEvent.FROZEN,
		ChEvent.THAWED, ChEvent.PART_BROKEN, ChEvent.CELLS_CUT, ChEvent.ENERGY_GAINED]:
		ctx.bus.subscribe(hud_listener, type, _hear)


func _hear(event: ChEvent) -> void:
	# One callback for every event type, so the ticker line is the event's own name and the chain
	# a part caused reads as it happened (caught_fire, then energy_gained, then part_fired).
	ticker_text.append(String(event.type))
	while ticker_text.size() > TICKER_LINES:
		ticker_text.remove_at(0)
	if event.side == 0 and event.source != null and (event.type == ChEvent.PART_FIRED
		or event.type == ChEvent.ENERGY_GAINED):
		# The brief's pulse on the player's own fire, on the part that made it.
		pulses.append({"part": event.source, "left": PULSE_SECONDS})


func _hud_tick(delta: float) -> void:
	_set_bar(0, float(player.hp) / maxf(1.0, float(player.body_def.hp)))
	_set_bar(1, float(enemy.hp) / maxf(1.0, float(enemy.body_def.hp)))
	var pool: ChEnergy = player.energy
	_set_bar(2, pool.value / maxf(1.0, pool.cap))
	_pips(pool.queue_size())
	for line in ticker_labels.size():
		ticker_labels[line].text = ticker_text[line] if line < ticker_text.size() else ""
	var at := 0
	while at < pulses.size():
		pulses[at]["left"] = float(pulses[at]["left"]) - delta
		if pulses[at]["left"] <= 0.0:
			pulses.remove_at(at)
		else:
			at += 1
	marks.queue_redraw()


func _set_bar(at: int, fraction: float) -> void:
	# The fill's width is the fraction of the bar, clamped so a part that went past 0 HP or a pool
	# that went past its cap cannot grow the bar out of its backing.
	bars[at].size.x = (BAR - 2.0) * clampf(fraction, 0.0, 1.0)


func _pips(count: int) -> void:
	# One pip per part waiting in the energy queue, made on demand and hidden when unused: the
	# queue is what makes a part visibly wait, which is the chain the HUD has to show.
	while pips.size() < count:
		var pip := ColorRect.new()
		var at := pips.size()
		pip.position = Vector2(6.0 + at * 4.0, 24.0)
		pip.size = Vector2(3.0, 4.0)
		pip.color = Color(0.95, 0.5, 0.2)
		hud.add_child(pip)
		pips.append(pip)
	for at in pips.size():
		if at >= count:
			pips[at].hide()
		else:
			pips[at].show()


func _camera_at() -> void:
	# Midpoint of both chassis framed close: camera_frame composes the shot and the live camera
	# eases toward it, so a chase glides between ticks instead of jumping.
	if not _alive(player) or not _alive(enemy):
		# The frame a hull went missing: the camera keeps the last frame it could compose rather than
		# reading a freed position.
		return
	# The box the camera has to show: both hulls end to end plus the margin, so a Dozer and a Cutter
	# get one frame whatever their lengths.
	var pad := Vector2(maxf(_hull_box(player).size.x, _hull_box(enemy).size.x),
		maxf(_hull_box(player).size.y, _hull_box(enemy).size.y)) * 0.5
	pad += Vector2(CAMERA_MARGIN, CAMERA_MARGIN)
	var want: Dictionary = camera_frame(player.chassis.global_position,
		enemy.chassis.global_position, pad)
	var at: Vector2 = want["at"]
	camera.position += (at - camera.position) * CAMERA_EASE
	# One eased number, put back on both axes, so the frame never goes anamorphic.
	var zoom := lerpf(camera.zoom.x, float(want["zoom"]), CAMERA_EASE)
	camera.zoom = Vector2(zoom, zoom)


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


func _hull_box(chariot: ChChariotRuntime) -> Rect2:
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
	for pulse in pulses:
		var part: ChPartRuntime = pulse["part"]
		if part == null or part.broken or part.body == null or not is_instance_valid(part.body):
			continue
		# The 0.2 s pulse: a ring that grows out from the part over the window it has left.
		var left := maxf(0.0, float(pulse["left"]))
		var spot: Vector2 = onto * part.anchor_world()
		var grow := 1.0 - left / PULSE_SECONDS
		marks.draw_circle(spot, 4.0 + 10.0 * grow, Color(1.0, 0.9, 0.4, 1.0 - 0.8 * grow))
