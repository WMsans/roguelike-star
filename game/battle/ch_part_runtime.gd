class_name ChPartRuntime extends RefCounted

# One part of a live chariot (spec §5.7 status-from-sampling): the object the chariot builder
# (Task 9), the part behaviours (Tasks 12-14) and the battle loop (Task 10) all hang on.
# Status is sampled, not tracked in the sand: the battle loop counts materials over sample_rect()
# (PixelWorld.count_materials) and hands those cell counts to apply_sample each tick. The count
# keys are material names: fire, lava, burning, water, frost, ice.
# A part knows its own `side`, so the status events it emits carry side + source + position: that
# is what ChEventBus's proximity filter reads duck-typed (an int `side` and anchor_world()).

const BURN_CELLS := 3  # fire + lava + burning cells that set a part alight
const DOUSE_CELLS := 6  # water cells that put a burning part out
const FREEZE_BUILD := 0.6  # freeze built per second per group of 4 frost/ice cells
const FREEZE_GROUPS := 4  # frost/ice cells that count as one group
const FREEZE_DECAY := 0.25  # freeze lost per second when nothing cold is in reach
const LAVA_WEAR := 20.0  # integrity worn per second of lava contact
const SAMPLE_MARGIN := 2  # cells sample_rect grows beyond the part's own footprint


var def: ChPartDef = null  # the static definition this part was built from
var side: int = 0  # 0 = the player's chariot, 1 = the enemy's (the ChariotLayout index)
var path: Array[int] = []  # the slot/extension indices this part sits at
var flipped: bool = false  # the slot's left/right flip (ChariotLayout.toggle_flip)
var integrity: int = 0  # wear left; the builder (Task 9) seeds it from def.integrity
var cooldown_left: float = 0.0  # seconds until ready; 0 means ready
var charges_left: int = -1  # fires before the part runs out; -1 = unlimited (def.charges)
var burning: bool = false
var freeze: float = 0.0  # 0..1; is_frozen at 1.0
var broken: bool = false  # set by ChChariotRuntime.break_part (Task 10)
# shortcut: body stays loose-typed on purpose; Task 9 is the only caller that hands a real
# PixelRigidBody, and a : PixelRigidBody annotation rejects the fake bodies the tests use.
var body: Object = null  # the PixelRigidBody this part hangs on (Task 9 attaches it)
var joint: Node = null  # null for a part that hangs straight off the chassis
var parent: ChPartRuntime = null  # the part this one is mounted on, null for a body slot
var children: Array[ChPartRuntime] = []  # the parts mounted on this one
var behaviour: Object = null  # the ChBehaviour Task 10 declares (Task 9 instantiates def.behaviour
# into it); loose because ChBehaviour does not exist yet, so annotating it would not parse here


func anchor_world() -> Vector2:
	# The part's own world position. ChEventBus's proximity filter measures from here.
	# A part always has a body: the builder (Task 9) mounts the PixelRigidBody before anything
	# samples or emits.
	return body.global_position


func facing() -> Vector2:
	# The direction this part fires: its body's +x turned by its rotation, mirrored when the slot
	# is flipped (spec §5.4 facing: a part fires the way its slot faces, no auto-aim).
	var dir := Vector2.RIGHT.rotated(body.global_rotation)
	return -dir if flipped else dir


func is_frozen() -> bool:
	# The freeze meter is a build-up: only a full one freezes.
	return freeze >= 1.0


func sample_rect() -> Rect2i:
	# The cells a tick's status comes from: the part's footprint grown by the margin. The battle
	# loop samples it with PixelWorld.count_materials (Task 10's tick).
	# shortcut: the footprint is a 1-cell box at the anchor because a body here may be a test fake
	# carrying position and rotation only; ask the body's collision shape once PixelRigidBody is
	# attached in Task 9.
	var anchor := anchor_world()
	# Vector2i() truncates towards zero, so floor the world position to the cell it sits in.
	var cell := Vector2i(floori(anchor.x), floori(anchor.y))
	var size := Vector2i(1, 1)
	if def != null:
		# def.size is in cells; a 0-wide def would give an empty box, so clamp at one cell.
		size = Vector2i(maxi(1, def.size.x), maxi(1, def.size.y))
	var box := Rect2i(cell, size)
	return Rect2i(box.position - Vector2i(SAMPLE_MARGIN, SAMPLE_MARGIN),
		box.size + Vector2i(2 * SAMPLE_MARGIN, 2 * SAMPLE_MARGIN))


func _emit(bus: ChEventBus, type: StringName) -> void:
	# The three status events share this shape: a part knows its own side, source and anchor, which
	# is what ChEventBus's proximity filter reads (an int `side` and anchor_world()). data stays
	# empty: a status event carries no payload (the HIT/PART_FIRED payloads are Task 10's), and a
	# listener that wants the counts or the freeze value reads the part off source.
	var event := ChEvent.new()
	event.type = type
	event.side = side
	event.source = self
	event.position = anchor_world()
	# ChEvent is a value object (RefCounted, listeners only read it), so a fresh one per emit is the
	# shape here: nothing copies or reuses an event.
	# The bus is the battle's one (ChBattleContext, Task 10), not the part's, so the caller hands it
	# over. emit is synchronous and breadth-first, so a listener acts inside this call.
	# shortcut: a part that breaks unsubscribes through break_part (Task 10) on the same seam; these
	# three only announce status, so a broken part that keeps burning still emits CAUGHT_FIRE.
	bus.emit(event)


func apply_sample(counts: Dictionary, delta: float, bus: ChEventBus) -> void:
	# Turn one tick's cell counts (the caller samples sample_rect with count_materials) into status.
	# The state before this sample is what the three transitions compare against, so read it first.
	# Burning is a state, not per-tick damage: the chariot-wide damage over time is ChDamage.burn_tick
	# (Task 10), applied once while any of its parts burns.
	var was_burning := burning
	var was_frozen := is_frozen()
	# fire + lava + burning cells at the threshold sets the part alight. The "burning" key is a cheap
	# extra the addon never writes (no FLAG_BURNING writer, Task 2's ruling), so burning comes from
	# fire and lava cells today.
	burning = counts.get(&"fire", 0) + counts.get(&"lava", 0) + counts.get(&"burning", 0) >= BURN_CELLS
	# Water contact puts the part out even while it stands in fire (spec §5.7: water puts out burning).
	# shortcut: water wins over the fire count; if a caller wants deep fire to survive shallow water,
	# this branch needs a fire-vs-water comparison instead.
	if counts.get(&"water", 0) >= DOUSE_CELLS:
		burning = false
	# frost and ice are the two names the same cold material answers under in the material set.
	# Dictionary.get returns Variant, so the cell counts need the int annotation to add as ints.
	var cold: int = counts.get(&"frost", 0) + counts.get(&"ice", 0)
	# GDScript int division counts whole groups only, so 3 cells build nothing and 7 build one.
	var groups := cold / FREEZE_GROUPS
	if groups > 0:
		# clampf at 1.0: past that the part is frozen, so an overshoot would only hide the state.
		freeze = clampf(freeze + FREEZE_BUILD * delta * groups, 0.0, 1.0)
	elif cold == 0:
		# maxf at 0 so a long tick cannot make decay go negative.
		freeze = maxf(0.0, freeze - FREEZE_DECAY * delta)
	# cold present but under one group neither builds nor decays: the brief's rule reads groups.
	# Lava wears integrity here rather than through ChDamage, whose rules cover hit wear only: this
	# per-tick environmental wear is the brief's own 20 * delta.
	if counts.get(&"lava", 0) > 0:
		# round(), half away from zero, as ChDamage documents. shortcut: wear is whole integrity per
		# tick, so a tick shorter than 0.025 s of lava wears nothing; a float accumulator would fix
		# that if a caller ever ticks that finely.
		# maxi at 0: integrity never goes negative. Reaching 0 breaks the part, which is Task 10's
		# break_part rule, so nothing here marks `broken`.
		integrity = maxi(0, integrity - int(round(LAVA_WEAR * delta)))
	# The transitions, not the states: an already burning or already frozen part stays quiet. These
	# are the chain events spec §5.5 asks for.
	if not was_burning and burning:
		_emit(bus, ChEvent.CAUGHT_FIRE)
	if not was_frozen and is_frozen():
		_emit(bus, ChEvent.FROZEN)
	if was_frozen and not is_frozen():
		_emit(bus, ChEvent.THAWED)


func tick_cooldown(delta: float) -> bool:
	# Count the cooldown down by one tick and report whether the part is ready to fire. ChBattleContext
	# (Task 10) asks for energy only for a ready part and resets cooldown_left to def.cooldown when
	# the part fires.
	# A passive part has no cooldown to gate (cooldown 0 in the def), so it never becomes ready and
	# never asks for energy. A part with no def has nothing to gate either.
	if def == null or def.cooldown <= 0.0:
		return false
	# A frozen part's countdown pauses (spec §5.7: a weapon's cooldown pauses; the wheel motor is
	# Task 9's drive). cooldown_left keeps what a frozen part's countdown would have spent, so a thaw
	# resumes from where it stopped rather than restarting.
	# shortcut: a frozen part reports not ready whatever cooldown_left is, so Task 10 never requests
	# energy for it; a caller that thaws it has to call tick_cooldown again.
	if is_frozen():
		return false
	# clamp at 0 rather than negative, so an over-tick reports ready once and stays ready.
	cooldown_left = maxf(0.0, cooldown_left - delta)
	# The brief's rule: true when the countdown reaches 0. Past 0 it stays ready, so the caller owns
	# the reset.
	return cooldown_left <= 0.0
