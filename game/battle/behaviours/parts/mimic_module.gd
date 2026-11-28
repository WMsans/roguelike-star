extends ChBehaviour

# The Mimic Module (R37): before any behaviour's setup, it becomes the part in the slot immediately
# in front of it (the side it faces) — running the front def's behaviour with the front def's
# numbers, but keeping its own id, integrity, size, texture, colour and description.
# A Mimic whose front slot holds another Mimic, or nothing, stays inert (parts-list §6: two Mimics
# facing each other do nothing). Its own id is what lets the next Mimic see it as one.
const ID := &"mimic_module"
# One slot ahead is six cells: the rig's body slots and the frames' extension slots are six apart.
# shortcut: corsair and dozer space their body slots 9-18 cells apart, so a Mimic copies nothing on
# them; read the body's own slot spacing when a Mimic is expected to work on those bodies.
const SLOT_SPACING := 6.0


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


# The own part in the slot immediately in front, or null. A wheel is not a part in a slot ahead to
# copy: its slot sits off the row, so copying it would put wheel tags and mode on the Mimic.
func _front_slot(ctx: ChBattleContext) -> ChPartRuntime:
	var anchor := part.anchor_world()
	var facing := part.facing()
	var front: ChPartRuntime = null
	# +0.001: the joints can leave an adjacent slot a hair short of its six cells.
	var best := SLOT_SPACING + 0.001
	for other in _own_parts(ctx):
		if other.def == null or other.def.is_wheel():
			continue
		var d := (other.anchor_world() - anchor).dot(facing)
		if d <= 0.0 or d > best:
			continue
		front = other
		best = d
	return front
