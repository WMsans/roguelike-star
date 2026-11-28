extends ChBehaviour

# The Mimic Module (R37): before any behaviour's setup, it becomes the part in front of it — the
# nearest own part along the way it faces — running the front def's behaviour with the front def's
# numbers, but keeping its own id, integrity, size, texture, colour and description.
# A Mimic whose front part is another Mimic, or nothing, stays inert (parts-list §6: two Mimics
# facing each other do nothing). Its own id is what lets the next Mimic see it as one.
const ID := &"mimic_module"


func resolve(ctx: ChBattleContext) -> void:
	var front := _front_part(ctx)
	if front == null or front.def == null or front.def.id == ID:
		return
	var copied: ChPartDef = front.def.copy()
	copied.id = part.def.id
	copied.integrity = part.def.integrity
	copied.size = part.def.size
	copied.texture = part.def.texture
	copied.color = part.def.color
	copied.description = part.def.description
	part.def = copied
	if copied.behaviour != null:
		var behaviour = copied.behaviour.new()
		behaviour.part = part
		part.behaviour = behaviour
	# The builder seeded these from the Mimic's own def (all zero); the copy starts them at the
	# copied part's numbers, which is what the volley and the held button read before the first tick.
	part.cost = copied.energy_cost
	part.rate = copied.energy_per_second
	part.cooldown = copied.cooldown
