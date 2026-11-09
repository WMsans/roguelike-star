class_name ChFx extends Sprite2D

# One baked pixelfx effect playing in the battle's cell space: a sprite sheet from textures/fx/ (made by
# tools/fx/bake.mjs; its manifest fx.json gives each sheet's frames, fps and pivot). One sheet pixel is one
# cell, the scale the effects were drawn at. A one-shot frees itself on its last frame; a loop plays until
# stop(), which fades it out. Pure decoration: nothing here is read by the fight, so a missing parent or
# sheet just plays nothing.
# The effects face right; face() turns them to a part's facing, mirroring instead of rotating past
# vertical so smoke and flame still rise on a left-facing part.

const DIR := "res://textures/fx/"
const Z := 5  # above every body (z 0), below the part markers (ChBattle.MARKER_Z)
const FADE := 0.2  # seconds a stopped loop takes to fade out

static var _manifest: Dictionary = {}

var _fps := 30.0
var _frames := 1
var _loop := false
var _t := 0.0
var _fade_left := -1.0  # < 0 while playing; counts down once a loop is stopped


# Plays `fx` under `parent` at `at` (parent-local; the world's transform is the arena's identity, so a
# world point there), turned to `dir`. Returns the node, or null when there is nothing to play it on.
static func spawn(parent: Node, fx: StringName, at: Vector2, dir := Vector2.RIGHT) -> ChFx:
	if parent == null or not is_instance_valid(parent):
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


func stop() -> void:
	if _fade_left < 0.0:
		_fade_left = FADE


func _physics_process(delta: float) -> void:
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
	if _fade_left >= 0.0:
		_fade_left -= delta
		modulate.a = clampf(_fade_left / FADE, 0.0, 1.0)
		if _fade_left <= 0.0:
			queue_free()
