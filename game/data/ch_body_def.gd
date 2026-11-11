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
# The hull's pixel art, nose at +x; null draws the flat placeholder. Its opaque pixels must be
# ChTextures.polygon's for the outline: the chassis is built from them.
var texture: Texture2D
var slots: PackedVector2Array = []  # body-local cells, index is the body slot index
# A convex hull in body-local cells; empty means the hull is the size box. size must equal its
# bounding box, so every reader of size (hull box, half-width, camera, pit) stays right.
var outline: PackedVector2Array = []
# 0 / -1 leave the engine's own value alone.
var mass: float = 0.0
var friction: float = 0.0
var restitution: float = -1.0
var drive_style: StringName = &""  # &"brawler", &"kiter" or empty
var type_name: String = ""  # "Wedge", "Tower", "Barge": shown in the garage


func copy() -> ChBodyDef:
	# Field by field: duplicate() drops a script resource's own (non-exported) properties on this
	# build (the copy answers an empty id and 0 HP). Walking the script variables keeps a field added
	# later from being forgotten here.
	var out := ChBodyDef.new()
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.set(prop.name, get(prop.name))
	return out
