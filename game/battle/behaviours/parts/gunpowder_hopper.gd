extends ChBehaviour

# The Gunpowder Hopper (C28): a 12-cell line of gunpowder on the surface in front. Each cell is
# dropped on the first solid cell under it, so the line follows the ground it is poured onto.
const CELLS := 12  # cells in the line

func fire(ctx: ChBattleContext) -> void:
	if ctx.world == null:
		return
	var from := part.anchor_world()
	var facing := part.facing()
	for i in CELLS:
		var at := from + facing * float(i + 1)
		var cell := Vector2i(roundi(at.x), roundi(at.y))
		while cell.y < ctx.world.arena.end.y and _open(ctx, cell):
			cell.y += 1
		ctx.spawn(part, &"gunpowder", Vector2(cell.x, cell.y - 1), 1)

func _open(ctx: ChBattleContext, cell: Vector2i) -> bool:
	# Air (or an unloaded cell) is open; the ground the line is poured onto is not.
	var m := ctx.world.get_material_at(cell)
	return m == &"" or m == &"air"
