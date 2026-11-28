class_name ChPartRuntime extends RefCounted

# One part of a live chariot (spec §5.7 status-from-sampling): the object the chariot builder
# (Task 9), the part behaviours (Tasks 12-14) and the battle loop (Task 10) all hang on.
# Status lives in `statuses`; ChBattleContext's status second reads the cells over sample_rect().
# A part knows its own `side` and anchor_world(), which is what ChEventBus's proximity filter reads.

const SAMPLE_MARGIN := 2  # cells sample_rect grows beyond the part's own footprint


var def: ChPartDef = null  # the static definition this part was built from
var side: int = 0  # 0 = the player's chariot, 1 = the enemy's (the ChariotLayout index)
var path: Array[int] = []  # the slot/extension indices this part sits at
var flipped: bool = false  # the slot's left/right flip (ChariotLayout.toggle_flip)
var integrity: int = 0  # wear left; the builder (Task 9) seeds it from def.integrity
var cooldown_left: float = 0.0  # seconds until ready; 0 means ready
var tick_left: float = 0.0  # seconds until a continuous part's next tick; 0 swings at once
var running: bool = false  # whether a continuous part ran on the last tick
var charges_left: int = -1  # fires before the part runs out; -1 = unlimited (def.charges)
# Refreshed from the stat hook at the start of every tick (ChBattleContext._tick_chariot):
var cost: int = 0  # energy the volley pays to fire this part
var rate: float = 0.0  # energy a second the held button pays while this runs or drives
var cooldown: float = 0.0  # seconds the volley resets cooldown_left to after a fire
var bonus_damage: int = 0  # flat damage this part adds to its own hits, for the battle
var fire_cells_per_hit: int = 0  # fire cells a hit from this part spawns on its target (U30)
var statuses := ChStatuses.new()  # the nine stacking statuses
var broken: bool = false  # set by ChChariotRuntime.break_part (Task 10)
# shortcut: body stays loose-typed on purpose; Task 9 is the only caller that hands a real
# PixelRigidBody, and a : PixelRigidBody annotation rejects the fake bodies the tests use.
var body: Object = null  # the PixelRigidBody this part hangs on (Task 9 attaches it)
var visual: Node2D = null  # the "Visual" child of `body` (the builder's, Task 6), what juice moves
var outline: Sprite2D = null  # the hidden ring ChBattle._show_ready lights while this part is ready; null for a passive part
var joint: Node = null  # null for a part that hangs straight off the chassis
var parent: ChPartRuntime = null  # the part this one is mounted on, null for a body slot
var children: Array[ChPartRuntime] = []  # the parts mounted on this one
var behaviour: Object = null  # the ChBehaviour Task 10 declares (Task 9 instantiates def.behaviour
# into it); loose because ChBehaviour does not exist yet, so annotating it would not parse here
# The last body reading, kept so anchor_world()/facing() answer after the body has left the tree.
var last_anchor: Vector2 = Vector2.ZERO
var last_facing: float = 0.0


func anchor_world() -> Vector2:
	# The part's own world position. ChEventBus's proximity filter measures from here.
	# A part always has a body while it is in the fight: the builder (Task 9) mounts the
	# PixelRigidBody before anything samples or emits. The body goes away only when the chariot's
	# nodes leave the tree (a battle freed mid-loop, a teardown) while a listener still holds this
	# RefCounted, and then `body` is a freed object: reading it is the crash, not a null check.
	# The last position read is kept for exactly that case, so a stray listener measures from where
	# the part last stood instead of reading a dead object.
	if body != null and is_instance_valid(body):
		last_anchor = Vector2(body.global_position.x, body.global_position.y)
	return last_anchor


func facing() -> Vector2:
	# The direction this part fires: its body's +x turned by its rotation, mirrored when the slot
	# is flipped (spec §5.4 facing: a part fires the way its slot faces, no auto-aim).
	# Same liveness rule as anchor_world(): a body that has left the tree keeps the last facing that
	# was read while it was alive, which sample_rect() and any late listener then use.
	if body != null and is_instance_valid(body):
		last_facing = body.global_rotation
	var dir := Vector2.RIGHT.rotated(last_facing)
	return -dir if flipped else dir


func status_box() -> Rect2:
	# def.size cells centred on the anchor: the same box as ChBehaviour._part_box.
	var size := Vector2(maxi(1, def.size.x), maxi(1, def.size.y)) if def != null else Vector2.ONE
	return Rect2(anchor_world() - size * 0.5, size)


func is_frozen() -> bool:
	return statuses.count(ChStatuses.FREEZE) > 0


func tick_rate() -> float:
	# How the statuses scale this part's ticks: Speedup doubles, Slow halves. Both a cooldown and a
	# continuous part read this, so a status change cannot make one run at a different rate.
	return 2.0 if statuses.count(ChStatuses.SPEEDUP) > 0 \
		else (0.5 if statuses.count(ChStatuses.SLOW) > 0 else 1.0)


func is_burning() -> bool:
	return statuses.count(ChStatuses.FLAME) > 0


func sample_rect() -> Rect2i:
	# The cells a tick's status comes from: the part's world AABB (spec §5.7 "cells in a margin
	# around its body") grown by the margin. The battle loop samples it with PixelWorld.count_materials
	# (Task 10's tick).
	# The body's box is def.size cells centred on its position, which is what the engine joins: PhysicsWorld::add_body
	# builds b2MakeBox(w/2, h/2) about bd.position and offsets every other shape by the same half.
	# So the footprint is that box turned by the body's rotation and mirrored by the slot's flip.
	# shortcut: the footprint is that def.size box, not the shape a stamped body actually joins: PixelRigidBody
	# binds no bounds getter, so a texture-stamped body (SHAPE_HULL/SHAPE_BOXES in Task 9) samples its
	# def.size AABB rather than the hull its pixels make.
	var anchor := anchor_world()
	var size := Vector2.ONE
	if def != null:
		# def.size is in cells; a 0-wide def would give an empty box, so clamp at one cell.
		size = Vector2(maxi(1, def.size.x), maxi(1, def.size.y))
	# The footprint's axes: facing() is the body's x axis already (rotation read from the body, negated
	# when flipped), so the y axis is its perpendicular. An AABB needs only the axes' absolute spans,
	# which is why a mirror or a turn past 90° cannot shrink the box here.
	var fx := facing()
	var fy := Vector2(-fx.y, fx.x)
	var half := size * 0.5
	var span := Vector2(half.x * absf(fx.x) + half.y * absf(fy.x),
		half.x * absf(fx.y) + half.y * absf(fy.y))
	# A cell at integer (x, y) covers the world span x .. x + 1, so the box covers floor(min) up to
	# ceil(max) exclusive: a part whose edge lands mid-cell counts that cell.
	var min_cell := Vector2i(floori(anchor.x - span.x), floori(anchor.y - span.y))
	var max_cell := Vector2i(ceilf(anchor.x + span.x), ceilf(anchor.y + span.y))
	var box := Rect2i(min_cell, max_cell - min_cell)
	return Rect2i(box.position - Vector2i(SAMPLE_MARGIN, SAMPLE_MARGIN),
		box.size + Vector2i(2 * SAMPLE_MARGIN, 2 * SAMPLE_MARGIN))


# A part the held button runs: continuous by mode, with a def, intact and not frozen. This is the
# continuous step's own gate, as is_ready is the volley's.
func can_run() -> bool:
	return def != null and def.is_continuous() and not broken and not is_frozen()


func is_ready() -> bool:
	# A triggered part (mode cooldown) that a press may fire: counted down, intact, not frozen and
	# with a charge left. charges_left -1 is unlimited, so only 0 means spent. A clock passive
	# (mode passive, cooldown or not) never joins a volley, so its cooldown never gates anything.
	return def != null and def.mode == ChPartDef.MODE_COOLDOWN and not broken and cooldown_left <= 0.0 \
		and charges_left != 0 and not is_frozen()


func tick_cooldown(delta: float, rate := NAN) -> bool:
	# Count the cooldown down by one tick and report whether the part is ready to fire. It no
	# longer implies a fire: ChBattleContext fires only on a press, and resets cooldown_left to
	# def.cooldown when the part fires.
	# A passive part has no cooldown to gate (cooldown 0 in the def), so it never becomes ready and
	# a press never fires it. A part with no def has nothing to gate either.
	if def == null or def.cooldown <= 0.0:
		return false
	# Freeze pauses the countdown; Speedup runs it at double speed, Slow at half. The caller may pass
	# the rate the stat hook folded (R26), which replaces tick_rate() rather than multiplying it.
	if is_frozen():
		return false
	var scale := tick_rate() if is_nan(rate) else rate
	# clamp at 0 rather than negative, so an over-tick reports ready once and stays ready.
	cooldown_left = maxf(0.0, cooldown_left - delta * scale)
	# The brief's rule: true when the countdown reaches 0. Past 0 it stays ready, so the caller owns
	# the reset.
	return cooldown_left <= 0.0
