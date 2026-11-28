extends ChBehaviour

# The Condenser (U72): every frame, the steam within range of its anchor turns back into water.
func process(ctx: ChBattleContext, _delta: float) -> void:
	var r := int(ctx.range_of(part))
	if r <= 0:
		return
	var at := Vector2i(roundi(part.anchor_world().x), roundi(part.anchor_world().y))
	var rect := Rect2i(at - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1))
	ctx._swap_cells(rect, [&"steam"], &"water", rect.get_area())