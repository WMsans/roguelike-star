class_name ChPartDef extends Resource

# Static definition of one part. Slot/extension positions are cells: +x is the direction the
# part faces, so a flip negates them (see ChChariotLayout.anchor_of).

var id: StringName = &""
var display_name: String = ""
var tags: PackedStringArray = []
var energy_cost: int = 0
var cooldown: float = 0.0  # seconds; 0 = passive
var damage: int = 0
var integrity: int = 100
var proximity_range: float = 0.0  # cells; 0 = none
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
