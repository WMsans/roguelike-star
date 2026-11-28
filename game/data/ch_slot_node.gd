class_name ChSlotNode extends Resource

# One part mounted in a slot: which part, whether it faces the other way, and what hangs off
# its own extension slots. Keys are the extension slot indices from ChPartDef.extension_slots.

var part_id: StringName = &""
var flipped: bool = false
# What this copy of the part carries between runs: a Piggy Bank's sell_bonus, a Scrap Cannon's
# damage_bonus. The shop always offers a part in its base state, so this travels with the copy.
var state: Dictionary = {}
var children: Dictionary[int, ChSlotNode] = {}
