class_name ChFx extends Sprite2D

# One baked pixelfx effect playing in the battle's cell space: a sprite sheet from textures/fx/ (made by
# tools/fx/bake.mjs; its manifest fx.json gives each sheet's frames, fps and pivot). One sheet pixel is one
# cell, the scale the effects were drawn at. A one-shot frees itself on its last frame; a loop plays until
# something takes the node off the tree. Pure decoration: nothing here is read by the fight, so a missing
# parent or sheet just plays nothing.
# Everything a baked effect emits is inside its frames, so it is the node's transform that places every
# pixel of it: only the world node may own one. Anything a moving thing throws is either dropped into the
# world as a puff (ChProjectile's trail, the Flamethrower's nozzle) or, for the 1-cell sparks under it,
# thrown into the world's particle pool (PixelWorld.spawn_visual_particles).
# The effects face right; face() turns them to a part's facing, mirroring instead of rotating past
# vertical so smoke and flame still rise on a left-facing part.

const DIR := "res://textures/fx/"
const Z := 5  # above every body (z 0), below the part markers (ChBattle.MARKER_Z)
# A one-shot's sheet fades in its own frames; a loop has no start or end of its own, so it fades in when it
# is spawned and out when its owner calls fade_out(), instead of popping on and off the fight.
const FADE_IN := 0.15  # seconds a looping effect takes to come up to full
const FADE_OUT := 0.2  # seconds fade_out() takes to take it off

static var _manifest: Dictionary = {}

var _fps := 30.0
var _frames := 1
var _loop := false
var _t := 0.0
var _fade_in_left := 0.0
var _fade_out_left := -1.0  # >= 0 once fade_out() is called
var _fade_from := 1.0  # the alpha the fade-out started from


# Plays `fx` under `parent` at `at` (parent-local; the world's transform is the arena's identity, so a
# world point there), turned to `dir`. Returns the node, or null when there is nothing to play it on.
# The parent has to be the world: a baked sheet carries the whole cloud of its effect's particles in
# its own frames, so parenting it to a body would move every one of them with that body's transform.
static func spawn(parent: Node, fx: StringName, at: Vector2, dir := Vector2.RIGHT) -> ChFx:
	if parent == null or not is_instance_valid(parent):
		return null
	if parent is not PixelWorld:
		push_warning("ChFx: %s will not parent to a node that moves" % fx)
		return null
	var meta := _meta(fx)
	if meta.is_empty():
		push_warning("ChFx: no baked effect %s" % fx)
		return null
	var node := ChFx.new()
	node.texture = load(DIR + "%s.png" % fx)
	node.hframes = int(meta["columns"])
	node.vframes = ceili(float(meta["frames"]) / float(meta["columns"]))
	node.centered = false
	node.offset = -Vector2(meta["pivot"][0], meta["pivot"][1])
	node.z_index = Z
	node._fps = float(meta["fps"])
	node._frames = int(meta["frames"])
	node._loop = bool(meta["loop"])
	node._fade_in_left = FADE_IN if node._loop else 0.0
	node.modulate.a = 0.0 if node._loop else 1.0
	node.position = at
	node.face(dir)
	parent.add_child(node)
	return node


static func _meta(fx: StringName) -> Dictionary:
	if _manifest.is_empty():
		var json := load(DIR + "fx.json") as JSON
		if json != null:
			_manifest = json.data
	return _manifest.get(String(fx), {})


func face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	# Mirrored for a left-facing part (scale.x -1 maps the sheet's +x onto -x), then rotated the rest of the way.
	var left := dir.x < 0.0
	scale.x = -1.0 if left else 1.0
	rotation = (-dir).angle() if left else dir.angle()


# Fades a looping effect out and frees it, rather than cutting it: a loop taken off the tree mid-cycle
# pops, and the eye reads that pop as the effect breaking rather than ending.
func fade_out() -> void:
	if _fade_out_left >= 0.0:
		return
	_fade_from = modulate.a
	_fade_out_left = FADE_OUT


func _physics_process(delta: float) -> void:
	if _fade_out_left >= 0.0:
		_fade_out_left -= delta
		if _fade_out_left <= 0.0:
			queue_free()
			return
		modulate.a = _fade_from * _fade_out_left / FADE_OUT
	elif _fade_in_left > 0.0:
		_fade_in_left = maxf(0.0, _fade_in_left - delta)
		modulate.a = 1.0 - _fade_in_left / FADE_IN
	# The fight's own frame clock, the one ChProjectile and the world step on.
	_t += delta
	var f := int(_t * _fps)
	if _loop:
		frame = f % _frames
	elif f >= _frames:
		queue_free()
		return
	else:
		frame = f
