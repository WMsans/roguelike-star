extends ChBehaviour

# The Detonator (U43): one firing lights every TNT and gunpowder cell within 40 cells of the part,
# capped so one press cannot walk the whole arena. world.ignite sets the cell burning; the engine's
# own scan turns it into a blast, which ChHazards owns by whoever laid the explosive.
const RANGE := 40  # cells from the part's anchor
const CAP := 200  # ignitions one firing
const IGNITED: Array[StringName] = [&"tnt", &"gunpowder"]  # the row's two explosives

func fire(ctx: ChBattleContext) -> void:
	if ctx.world == null:
		return
	var centre := Vector2i(part.anchor_world())
	var centre_f := Vector2(centre)
	var lit := 0
	for y in range(centre.y - RANGE, centre.y + RANGE + 1):
		for x in range(centre.x - RANGE, centre.x + RANGE + 1):
			if lit >= CAP:
				return
			var at := Vector2i(x, y)
			if Vector2(at).distance_squared_to(centre_f) > RANGE * RANGE:
				continue
			if not IGNITED.has(ctx.world.get_material_at(at)):
				continue
			if ctx.world.ignite(at):
				lit += 1
