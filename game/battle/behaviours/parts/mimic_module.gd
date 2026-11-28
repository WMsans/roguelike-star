extends ChBehaviour

# The Mimic Module (R37): before any behaviour's setup, it becomes the part in the nearest occupied
# slot ahead of it (the side it faces), never a wheel — running the front def's behaviour with the
# front def's numbers, but keeping its own id, integrity, size, texture, colour and description.
# A Mimic whose front slot holds another Mimic, or nothing, stays inert (parts-list §6: two Mimics
# facing each other do nothing). Its own id is what lets the next Mimic see it as one.
const ID := &"mimic_module"


func resolve(ctx: ChBattleContext) -> void:
	var front := _front_slot(ctx)
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


# The nearest own part ahead along facing(), never a wheel. A wheel is on the bottom edge and is not
# a part in a slot ahead to copy: copying it would put wheel tags and mode on the Mimic. Slots vary
# in spacing from body to body, so the nearest part ahead is the next occupied slot ahead.
func _front_slot(ctx: ChBattleContext) -> ChPartRuntime:
	var anchor := part.anchor_world()
	var facing := part.facing()
	var front: ChPartRuntime = null
	var best := 0.0
	for other in _own_parts(ctx):
		if other.def == null or other.def.is_wheel() or other.def.mode == ChPartDef.MODE_WHEEL:
			continue
		var d := (other.anchor_world() - anchor).dot(facing)
		if d > 0.0 and (front == null or d < best):
			front = other
			best = d
	return front
