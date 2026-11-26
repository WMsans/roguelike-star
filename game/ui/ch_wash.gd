class_name ChWash
extends TextureRect
## The slow Celeste colour wash: tiled noise, additive, drifting in whole art pixels.

const ALPHA := 0.15  # the battle's: the Celeste source's own, over a bright sky
const SHOP_ALPHA := 0.06  # over the dark Dusk backdrop 0.15 reads as blotches, not the mockup's haze
const SPEED := Vector2(2, 2)  # UI px (ChUi.PX each) per second

var _tex_size := Vector2(256, 144)  # in UI pixels: the rect is drawn at ChUi.PX, so one texel is one


static func drift_at(seconds: float) -> Vector2:
	return (SPEED * seconds).floor()


func _init(alpha := ALPHA) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	noise.fractal_octaves = 2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.45, 0.25, 0.8), Color(0.9, 0.3, 0.55), Color(1, 0.6, 0.25)])
	var tex := NoiseTexture2D.new()
	tex.width = int(_tex_size.x)
	tex.height = int(_tex_size.y)
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	modulate.a = alpha
	stretch_mode = TextureRect.STRETCH_TILE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale = Vector2(ChUi.PX, ChUi.PX)


func _process(_delta: float) -> void:
	# Grown by one texture so sliding it back by the wrapped drift never shows an edge. The anchors
	# would fight the offsets, so the rect is set explicitly. Under a CanvasLayer (the battle) the
	# parent is no Control, so the viewport is the base.
	var parent := get_parent()
	var base: Vector2 = (parent as Control).size if parent is Control else get_viewport_rect().size
	var drift := drift_at(Time.get_ticks_msec() / 1000.0)
	var wrapped := Vector2(fposmod(drift.x, _tex_size.x), fposmod(drift.y, _tex_size.y))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = base / ChUi.PX + _tex_size
	position = -wrapped * ChUi.PX
