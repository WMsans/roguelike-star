class_name ChBodyDef extends Resource

# Static definition of one body. Slot positions are body-local cells: origin = body centre,
# +x = forward. ChChariotLayout swaps bodies by comparing these against each other.
# The two lowest slots of every slice body are its wheel mounts, and they sit on the hull's bottom
# edge (y = size.y / 2): a 12-cell wheel anchored there hangs its tyre below the hull, so the wheels
# carry the chariot. Measured with the plan's Step-5 build: a wheel mounted three cells inside the
# edge left the hull resting on the sand with its wheels buried - the motors turned and the chassis
# did not move a cell - and on the edge the same build drives the length of the arena. A body's
# lowest slots are what tests/data/test_catalog.gd checks the enemy's wheels against.

var id: StringName = &""
var display_name: String = ""
var hp: int = 0
var energy_cap: int = 0
var energy_regen: float = 0.0
var size: Vector2i = Vector2i(1, 1)  # cells
var material: StringName = &""
var color: Color = Color(0.8, 0.8, 0.8)
var slots: PackedVector2Array = []  # body-local cells, index is the body slot index
