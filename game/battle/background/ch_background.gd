class_name ChBackground extends CanvasLayer

# The battle's sky: a CanvasLayer behind the world, so neither the camera's transform nor the
# world's light overlay (which lives in the world's own canvas) touches it. Parallax is done in the
# shaders: each frame the active camera's position and zoom go in as uniforms, and every layer
# samples its art at its own fraction of the camera's travel.

const ART_SIZE := Vector2(320, 180)
const REST := Vector2(240, 90)  # the arena centre: every layer shows its art centred here

## The fraction of camera travel each layer follows: 0 is pinned to the screen, 1 moves with the world.
@export var speeds := {&"Sky": 0.02, &"Mid": 0.25, &"Front": 0.55}
## A fixed art shift per layer, in texels: negative y lowers a ridge toward the horizon so the sky
## stays open above it.
@export var shifts := {&"Sky": Vector2.ZERO, &"Mid": Vector2(0, -25), &"Front": Vector2(0, -55)}


static func pan_for(camera: Vector2, speed: float) -> Vector2:
	# Whole texels, so a layer steps on the art grid instead of shimmering between texels.
	return ((camera - REST) * speed).floor()


static func art_uv(screen_uv: Vector2, screen_size: Vector2, zoom: float, camera: Vector2,
	speed: float) -> Vector2:
	# The shaders' art_uv (bg_common.gdshaderinc), kept here so the tests can pin the layout.
	var p := (screen_uv - Vector2(0.5, 0.5)) * screen_size / zoom + ART_SIZE * 0.5 + pan_for(camera, speed)
	return p / ART_SIZE


func _process(_delta: float) -> void:
	# Before the battle hands its camera over (the arena is still streaming) the layers hold the
	# rest pose at the widest zoom, which is the frame the fight opens on.
	# battle.tscn's camera is current from the start but parked at (0,0), zoom 1, until the first
	# fight tick frames the shot; read as a real view it would throw the ridges off and jump them at
	# that tick. A framed fight never zooms out past ZOOM_WIDEST, so a wider camera is an unframed one.
	var camera := get_viewport().get_camera_2d()
	var pos: Vector2 = REST
	var zoom: float = ChBattle.ZOOM_WIDEST
	if camera != null and camera.zoom.x >= ChBattle.ZOOM_WIDEST:
		pos = camera.get_screen_center_position()
		zoom = camera.zoom.x
	var size := get_viewport().get_visible_rect().size
	for layer_name in speeds:
		var rect := get_node_or_null(NodePath(layer_name)) as ColorRect
		if rect == null:
			continue
		var mat := rect.material as ShaderMaterial
		mat.set_shader_parameter("view_size", size)
		mat.set_shader_parameter("view_zoom", zoom)
		mat.set_shader_parameter("pan", pan_for(pos, speeds[layer_name]) + shifts.get(layer_name, Vector2.ZERO))
