class_name ChPartDef extends Resource

# How a part fires (Stage 3): a cooldown part fires on a press and pays energy_cost, a melee or beam
# part runs while the button is held and pays energy_per_second, a wheel pays energy_per_second while
# the chariot drives, and a passive part does neither.
const MODE_COOLDOWN := &"cooldown"
const MODE_MELEE := &"melee"
const MODE_BEAM := &"beam"
const MODE_PASSIVE := &"passive"
const MODE_WHEEL := &"wheel"

# Static definition of one part. Slot/extension positions are cells: +x is the direction the
# part faces, so a flip negates them (see ChChariotLayout.anchor_of).

var id: StringName = &""
var display_name: String = ""
var tags: PackedStringArray = []
# Rarity is what the shop charges for this part (ChPrices.price); tags are what a shop theme's roll
# picks from. Both are pinned per part in the spec's part-data table.
var rarity: StringName = &"common"
var energy_cost: int = 0
var cooldown: float = 0.0  # seconds; 0 = no cooldown
var mode: StringName = MODE_COOLDOWN  # one of the MODE_* constants above
var energy_per_second: float = 0.0  # energy a second while a melee/beam part runs or a wheel drives
var damage: int = 0
var integrity: int = 100
var proximity_range: float = 0.0  # cells; 0 = none
# Cells from the part's own edge along its facing that a weapon brings to bear; 0 = no reach.
# proximity_range keeps its own meaning: the proximity-chain range.
var reach: float = 0.0
var charges: int = -1  # -1 = unlimited
var extension_slots: PackedVector2Array = []  # relative to the part anchor, +x = facing
var size: Vector2i = Vector2i(1, 1)  # cells
var color: Color = Color(0.8, 0.8, 0.8)
# The part's pixel art, facing +x; null draws the flat placeholder. Its opaque pixels must be the
# placeholder's (the box, or the wheel's disc): the body's mass and shape come from them.
var texture: Texture2D
var material: StringName = &""
var behaviour: Script
var description: PackedStringArray = []  # one tagged bullet per entry ({key} / {key:shown}, see ChKeywords)


func is_wheel() -> bool:
	# The tag is the wheel, so a wheel set is data rather than a part id (the builder's old WHEEL_ID).
	return tags.has("wheel")


func is_continuous() -> bool:
	# A part the held button runs, as opposed to one a press fires.
	return mode == MODE_MELEE or mode == MODE_BEAM
