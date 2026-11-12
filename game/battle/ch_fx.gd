class_name ChFx extends Sprite2D

# One baked pixelfx effect playing in the battle's cell space: a sprite sheet from textures/fx/ (made by
# tools/fx/bake.mjs; its manifest fx.json gives each sheet's frames, fps and pivot). One sheet pixel is one
# cell, the scale the effects were drawn at. A one-shot frees itself on its last frame; a loop plays until
# something takes the node off the tree. Pure decoration: nothing here is read by the fight, so a missing
# parent or sheet just plays nothing.
# Everything a baked effect emits is inside its frames, so it is the node's transform that places every
# pixel of it: only the world node may own one. Anything a moving thing throws goes through the world's
# particle pool instead (PixelWorld.spawn_visual_particles), which ChProjectile and the Flamethrower do.
# The effects face right; face() turns them to a part's facing, mirroring instead of rotating past
# vertical so smoke and flame still rise on a left-facing part.

const DIR := "res://textures/fx/"
const Z := 5  # above every body (z 0), below the part markers (ChBattle.MARKER_Z)

static var _manifest: Dictionary = {}

var _fps := 30.0
var _frames := 1
var _loop := false
var _t := 0.0


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
