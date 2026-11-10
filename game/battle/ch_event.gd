class_name ChEvent extends RefCounted

# One battle happening, named by `type` and carried to the bus (spec §5.5). An event is a value
# object: the part that made it fills the fields, listeners only read them, and nothing here keeps
# state, so a listener that wants an event later keeps it itself.
# `side` is 0 for the player's chariot and 1 for the enemy's, matching ChariotLayout/chariot
# indices; a source-less (chariot-wide) event has no side to give and leaves it 0.

var type: StringName = &""
var side: int = 0
var source: Object = null  # the ChPartRuntime that acted, or null for a chariot-wide event
var position: Vector2 = Vector2.ZERO  # world cells
var data: Dictionary = {}  # event-specific payload, e.g. {"part": ..., "amount": ...}

const PART_FIRED: StringName = &"part_fired"
const HIT: StringName = &"hit"
const CAUGHT_FIRE: StringName = &"caught_fire"
const FROZEN: StringName = &"frozen"
const THAWED: StringName = &"thawed"
const PART_BROKEN: StringName = &"part_broken"
const CELLS_CUT: StringName = &"cells_cut"
const ENERGY_GAINED: StringName = &"energy_gained"
const HAZARD_HIT: StringName = &"hazard_hit"  # a material blast hurt a chariot; no source part
