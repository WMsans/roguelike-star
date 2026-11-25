class_name ChWash
extends TextureRect
## The slow Celeste colour wash: tiled noise, additive, drifting in whole art pixels.

const ALPHA := 0.15
const SPEED := Vector2(4, 4)  # art px per second

var _tex_size := Vector2(512, 288)


static func drift_at(seconds: float) -> Vector2:
	return (SPEED * seconds).floor()


func _init() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.004
	noise.fractal_octaves = 2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.45, 0.25, 0.8), Color(0.9, 0.3, 0.55), Color(1, 0.6, 0.25)])
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 288
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	modulate.a = ALPHA
	stretch_mode = TextureRect.STRETCH_TILE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _process(_delta: float) -> void:
	# Grown by one texture so sliding it back by the wrapped drift never shows an edge. The anchors
	# would fight the offsets, so the rect is set from the parent's size.
	var parent := get_parent() as Control
	if parent == null:
		return
	var drift := drift_at(Time.get_ticks_msec() / 1000.0)
	var wrapped := Vector2(fposmod(drift.x, _tex_size.x), fposmod(drift.y, _tex_size.y))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = parent.size + _tex_size
	position = -wrapped
