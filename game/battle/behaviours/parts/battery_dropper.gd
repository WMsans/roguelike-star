extends ChBehaviour

# The Battery Dropper (C23): a 4x4 block of battery on the first solid surface 10 cells ahead. The
# block is cells, so ChSparks records it and it discharges once a status second.
const AHEAD := 10  # cells in front of the part the drop is aimed at
const CELLS := 16  # a 4x4 block

func fire(ctx: ChBattleContext) -> void:
	if ctx.world == null:
		return
	var at := part.anchor_world() + part.facing() * AHEAD
	var cell := Vector2i(roundi(at.x), roundi(at.y))
	# The first solid cell below the aim point is the surface; the block's centre sits two cells up.
	while cell.y < ctx.world.arena.end.y and _open(ctx, cell):
		cell.y += 1
	ctx.spawn(part, &"battery", Vector2(cell.x, cell.y - 2), CELLS)

func _open(ctx: ChBattleContext, cell: Vector2i) -> bool:
	# Air (or an unloaded cell) is open; rock, a liquid and a part's own material are not.
	var m := ctx.world.get_material_at(cell)
	return m == &"" or m == &"air"
