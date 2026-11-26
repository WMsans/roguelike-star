class_name ChJuice extends Node

# A juice beat on its parent: each juice_up starts a short decaying wiggle, and the springs carry
# whatever still needs a long settle (the tooltip's pop-in). attach() keeps it to one "Juice" child
# per target.

# A pop is slightly wider than tall: scale.y follows scale.x at this fraction of its travel.
const SQUASH := 0.6
# A beat lasts this long — over before the eye starts following it.
const BEAT_TIME := 0.3
# Wiggle frequencies, radians per second.
const SCALE_OMEGA := 50.0
const ROTATION_OMEGA := 42.0
# One beat's wiggle and every beat at once stay inside these offsets from rest.
const MAX_SCALE_OFFSET := 0.35
const MAX_ROTATION_OFFSET := deg_to_rad(25.0)

var scale_spring := ChSpring.new(1.0)
var rotation_spring := ChSpring.new(0.0)
# ChCard composes its own transform from scale_value()/rotation_value(), so it asks for the beat to
# run without the write. Only the write is gated: the beats age either way.
var writes_parent := true

# One entry per juice_up: {t: age in seconds, s: scale amplitude, r: rotation amplitude in radians}.
var _beats: Array[Dictionary] = []


func _init() -> void:
	name = "Juice"


func _process(delta: float) -> void:
	advance(delta)


func juice_up(scale_amp: float, rotation_amp_rad: float) -> void:
	_beats.append({"t": 0.0, "s": scale_amp, "r": rotation_amp_rad, "h": 0.0})


func scale_value() -> float:
	return scale_spring.value + _wiggle_scale()


func rotation_value() -> float:
	return rotation_spring.value + _wiggle_rotation()


func advance(delta: float) -> void:
	scale_spring.step(delta)
	rotation_spring.step(delta)
	_age_beats(delta)
	var target := get_parent()
	if target == null or not writes_parent:
		return
	var value := scale_value()
	# Plain Vector2.ONE * value would lose the squash on y, so the vector is built directly.
	var squash := Vector2(value, 1.0 + (value - 1.0) * SQUASH)
	# A Control scales around pivot_offset, which defaults to its top-left; centre it first.
	if target is Control:
		var control := target as Control
		control.pivot_offset = control.size * 0.5
		control.scale = squash
		control.rotation = rotation_value()
	elif target is Node2D:
		var node := target as Node2D
		node.scale = squash
		node.rotation = rotation_value()


func _age_beats(delta: float) -> void:
	# A beat's clock moves by exactly the delta it is stepped with: stepped by one whole BEAT_TIME it
	# lands on t == BEAT_TIME, which the drop below catches, so the wiggle is over and not left running.
	# shortcut: the beat list is walked three times per frame (both wiggles plus the drop); upgrade
	# if the beats alive on one object ever reach the hundreds.
	for beat in _beats:
		beat["t"] = float(beat["t"]) + delta
	var kept: Array[Dictionary] = []
	for beat in _beats:
		if float(beat["t"]) < BEAT_TIME:
			kept.append(beat)
	_beats = kept


func _wiggle_scale() -> float:
	var sum := 0.0
	for beat in _beats:
		sum += _wiggle(float(beat["s"]), float(beat["t"]), SCALE_OMEGA)
	return clampf(sum, -MAX_SCALE_OFFSET, MAX_SCALE_OFFSET)


func _wiggle_rotation() -> float:
	var sum := 0.0
	for beat in _beats:
		sum += _wiggle(float(beat["r"]), float(beat["t"]), ROTATION_OMEGA)
	return clampf(sum, -MAX_ROTATION_OFFSET, MAX_ROTATION_OFFSET)


static func _wiggle(amp: float, t: float, omega: float) -> float:
	# sin(0) is 0, so a beat never snaps the parent on the frame it arrives. The cubic envelope makes
	# the wiggle actually gone at t == BEAT_TIME rather than merely small.
	var envelope := 1.0 - t / BEAT_TIME
	return amp * sin(omega * t) * envelope * envelope * envelope


static func of(target: Node) -> ChJuice:
	return target.get_node_or_null("Juice") as ChJuice


static func attach(target: CanvasItem) -> ChJuice:
	var existing := of(target)
	if existing != null:
		return existing
	var juice := ChJuice.new()
	target.add_child(juice)
	return juice
