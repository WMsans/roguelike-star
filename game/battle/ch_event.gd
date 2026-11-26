class_name ChEvent extends RefCounted

# One battle happening, named by `type` and carried to the bus (spec §5.5). An event is a value
# object: the part that made it fills the fields, listeners only read them, and nothing here keeps
# state, so a listener that wants an event later keeps it itself.
# `side` is 0 for the player's chariot and 1 for the enemy's, matching ChariotLayout/chariot
# indices; a source-less (chariot-wide) event has no side to give and leaves it 0.

var type: StringName = &""
var side: int = 0
var source: Object = null  # the ChPartRuntime that acted, the ChChariotRuntime for a status on the body, or null for a chariot-wide event
var position: Vector2 = Vector2.ZERO  # world cells
var data: Dictionary = {}  # event-specific payload, e.g. {"part": ..., "amount": ...}

const PART_FIRED: StringName = &"part_fired"
const PART_SKIPPED: StringName = &"part_skipped"  # a ready part the volley's pool refused; data: cost
const HIT: StringName = &"hit"
const PART_BROKEN: StringName = &"part_broken"
const CELLS_CUT: StringName = &"cells_cut"
const ENERGY_GAINED: StringName = &"energy_gained"
const STATUS_GAINED: StringName = &"status_gained"  # data: status, amount, before
const STATUS_LOST: StringName = &"status_lost"  # data: status, and shatter: true on a Shatter's thaw
const STATUS_CANCELLED: StringName = &"status_cancelled"  # data: status, against, amount
const STATUS_DOUBLED: StringName = &"status_doubled"  # data: status, amount
const SHOCK_JUMPED: StringName = &"shock_jumped"  # data: from, amount
const HAZARD_HIT: StringName = &"hazard_hit"  # a material blast hurt a chariot; no source part
const EXPLOSION: StringName = &"explosion"  # side = owner (-1 unowned); data: size, radius, dig, owner, material, source


# The holder's first stack of `status`: "caught fire" for Flame, "frozen" for Freeze.
static func first_stack(event: ChEvent, status: StringName) -> bool:
	return event.type == STATUS_GAINED and event.data.get("status") == status \
		and event.data.get("before", -1) == 0


static func caught_fire(event: ChEvent) -> bool:
	return first_stack(event, ChStatuses.FLAME)


static func thawed(event: ChEvent) -> bool:
	return event.type == STATUS_LOST and event.data.get("status") == ChStatuses.FREEZE
