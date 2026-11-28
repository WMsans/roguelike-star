extends ChBehaviour

# The Oil Sprayer (U01): a straight shot that soaks the body it meets in oil, on it and under it.
const SPEED := 200.0  # cells per second along facing()
const CELLS := 8  # oil cells in each patch

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var at := Vector2(shot.get("position", part.anchor_world()))
	ctx.spawn(part, &"oil", at, CELLS)
	# The patch under the body: one cell below the box's bottom edge.
	var box := _body_box(ctx, shot.get("collider"))
	if box.size != Vector2.ZERO:
		ctx.spawn(part, &"oil", Vector2(box.get_center().x, box.end.y + 1.0), CELLS)

func _body_box(ctx: ChBattleContext, body: Object) -> Rect2:
	# The box of the part hit, or of the chariot body for a hull hit: the split deal_hit makes.
	var holder: Object = ctx.part_of_body(body)
	if holder != null:
		return holder.status_box()
	var chariot := ctx.chariot_of_body(body)
	return ChBattle.hull_box(chariot) if chariot != null else Rect2()
