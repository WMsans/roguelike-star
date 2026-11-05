class_name ChSlotNode extends Resource

# One part mounted in a slot: which part, whether it faces the other way, and what hangs off
# its own extension slots. Keys are the extension slot indices from ChPartDef.extension_slots.

var part_id: StringName = &""
var flipped: bool = false
var children: Dictionary[int, ChSlotNode] = {}
