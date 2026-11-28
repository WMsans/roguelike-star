extends ChBehaviour

# The Grounding Spike (U19): a spark into the first solid cell under its tip, which then runs along
# the water and steel it finds to the first part it reaches.

func fire(ctx: ChBattleContext) -> void:
	if ctx.world == null:
		return
	var box := part.status_box()
	var cell := Vector2i(roundi(box.get_center().x), ceili(box.end.y))
	while cell.y < ctx.world.arena.end.y and _open(ctx, cell):
		cell.y += 1
	if cell.y >= ctx.world.arena.end.y:
		# Nothing solid under the tip: there is no conductor to send the spark through.
		return
	ctx.throw_sparks(part, Vector2(cell) + Vector2(0.5, 0.5), 1, true)

func _open(ctx: ChBattleContext, cell: Vector2i) -> bool:
	# Air (or an unloaded cell) is open; rock, a liquid and a part's own material are not.
	var m := ctx.world.get_material_at(cell)
	return m == &"" or m == &"air"
