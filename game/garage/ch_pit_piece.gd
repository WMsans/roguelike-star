class_name ChPitPiece extends Node2D

# Task 9: one drawn thing in the garage pit - the hull, or a mounted part. The node's origin is the
# point `ChPartCard.paint` used to be called at, so a piece moves and pops without the pit's maths
# knowing; the scale and rotation belong to the Juice child, so nothing here sets them.

var part_def: ChPartDef = null  # what show_part drew; null on a hull piece
var body_def: ChBodyDef = null  # what show_hull drew; null on a part piece
var flipped := false  # the part's facing, and whether the notch is drawn


func _init() -> void:
	# The juice node is the piece's own from the start, so a kick needs no setup step before it.
	ChJuice.attach(self)


func show_part(def: ChPartDef, flipped_in: bool) -> void:
	part_def = def
	body_def = null
	flipped = flipped_in
	queue_redraw()


func show_hull(def: ChBodyDef) -> void:
	body_def = def
	part_def = null
	flipped = false
	queue_redraw()


func _draw() -> void:
	if body_def != null:
		# The hull, centred on the origin: the cells at the pit's zoom, in the body's own colour.
		var hull := Vector2(maxi(1, body_def.size.x), maxi(1, body_def.size.y)) * ChGarage.ZOOM
		if body_def.outline.size() >= 3:
			# A Transform2D scales the whole polygon; PackedVector2Array has no * float.
			var shape: PackedVector2Array = Transform2D().scaled(Vector2.ONE * ChGarage.ZOOM) * body_def.outline
			draw_colored_polygon(shape, body_def.color)
			draw_polyline(shape + PackedVector2Array([shape[0]]), body_def.color.darkened(0.3), 1.0)
		else:
			draw_rect(Rect2(-hull * 0.5, hull), body_def.color)
		return
	if part_def == null:
		return
	ChPartCard.paint(self, Vector2.ZERO, part_def, ChGarage.ZOOM)
	if flipped:
		# The facing edge, which is what a flip means: +x is forward and a flip negates the
		# extension offsets, so the notch says which way the part and its children point.
		var half := Vector2(maxi(1, part_def.size.x), maxi(1, part_def.size.y)).x * ChGarage.ZOOM * 0.5
		draw_line(Vector2(-half, -4.0), Vector2(-half, 4.0), ChGarage.HOVER_COLOR)
