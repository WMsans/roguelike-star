class_name ChBodyDef extends Resource

# Static definition of one body. Slot positions are body-local cells: origin = body centre,
# +x = forward. ChChariotLayout swaps bodies by comparing these against each other.

var id: StringName = &""
var display_name: String = ""
var hp: int = 0
var energy_cap: int = 0
var energy_regen: float = 0.0
var size: Vector2i = Vector2i(1, 1)  # cells
var material: StringName = &""
var color: Color = Color(0.8, 0.8, 0.8)
var slots: PackedVector2Array = []  # body-local cells, index is the body slot index
