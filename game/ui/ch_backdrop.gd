class_name ChBackdrop
extends Control
## The dusk glow with its grid (the shop) and the vignette (both screens). Opaque when dusk is on.

const CELL := 40.0

var dusk := true
var vignette_alpha := 0.7
var _glow: GradientTexture2D
var _vignette: GradientTexture2D


func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if dusk:
		if _glow == null:
			_glow = _radial(ChUi.DUSK_CENTRE, ChUi.DUSK_EDGE)
		draw_texture_rect(_glow, rect, false)
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), ChUi.GRID)
			x += CELL
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), ChUi.GRID)
			y += CELL
	if _vignette == null:
		var clear := Color(ChUi.INK, 0.0)
		_vignette = _radial(clear, Color(ChUi.INK, vignette_alpha))
	draw_texture_rect(_vignette, rect, false)
