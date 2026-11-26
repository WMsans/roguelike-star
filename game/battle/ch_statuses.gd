class_name ChStatuses
extends RefCounted

# The nine stacking statuses on one holder. Pure data: the fight decides what a stack does.

const FLAME := &"flame"
const FREEZE := &"freeze"
const BLOCK := &"block"
const ACID := &"acid"
const WET := &"wet"
const OIL := &"oil"
const SHOCK := &"shock"
const SPEEDUP := &"speedup"
const SLOW := &"slow"

const ALL: Array[StringName] = [FLAME, FREEZE, BLOCK, ACID, WET, OIL, SHOCK, SPEEDUP, SLOW]
# Block, Wet and Oil stay until used or cancelled.
const DECAYS: Array[StringName] = [FLAME, FREEZE, ACID, SHOCK, SPEEDUP, SLOW]
# A gain spends itself against these, in list order.
const CANCELS := {
	FLAME: [WET, FREEZE], FREEZE: [FLAME], WET: [FLAME, ACID], ACID: [WET],
	SPEEDUP: [SLOW], SLOW: [SPEEDUP],
}
# Material touching the holder -> [status, stacks per second].
const GAIN_RATES := {
	&"fire": [FLAME, 2], &"lava": [FLAME, 6], &"frost": [FREEZE, 3], &"ice": [FREEZE, 1],
	&"water": [WET, 3], &"steam": [WET, 1], &"oil": [OIL, 3], &"acid": [ACID, 3], &"acid_gas": [ACID, 1], &"smoke": [SLOW, 1],
}

var stacks: Dictionary[StringName, int] = {}


func _init() -> void:
	for s in ALL:
		stacks[s] = 0


func count(status: StringName) -> int:
	return stacks[status]


func any() -> bool:
	for s in ALL:
		if stacks[s] > 0:
			return true
	return false


func gain(status: StringName, amount: int) -> Dictionary:
	var cancelled: Array = []
	if status == WET and stacks[OIL] > 0:
		return {"added": 0, "cancelled": cancelled, "doubled": 0}
	var rest := amount
	for opposite: StringName in CANCELS.get(status, []):
		var spent := mini(rest, stacks[opposite])
		if spent > 0:
			stacks[opposite] -= spent
			rest -= spent
			cancelled.append([opposite, spent])
	var doubled := 0
	var fuel := OIL if status == FLAME else (WET if status == FREEZE else &"")
	if fuel != &"":
		doubled = mini(rest, stacks[fuel])
		stacks[fuel] -= doubled
	var added := rest + doubled
	stacks[status] += added
	return {"added": added, "cancelled": cancelled, "doubled": doubled}


func clear(status: StringName) -> int:
	var removed := stacks[status]
	stacks[status] = 0
	return removed


# One status second: -1 on each decaying status not in `skip`. Returns the ones that just ran out.
func decay(skip: Array = []) -> Array[StringName]:
	var ended: Array[StringName] = []
	for s in DECAYS:
		if stacks[s] > 0 and s not in skip:
			stacks[s] -= 1
			if stacks[s] == 0:
				ended.append(s)
	return ended


func absorb(damage: int) -> int:
	var used := mini(damage, stacks[BLOCK])
	stacks[BLOCK] -= used
	return used


# counts: material -> cell count in the sample rect. A material filling over half of it counts double.
static func material_gains(counts: Dictionary, area: int) -> Dictionary:
	var gains := {}
	for material in counts:
		if counts[material] <= 0 or not GAIN_RATES.has(material):
			continue
		var rate: Array = GAIN_RATES[material]
		var amount: int = rate[1] * (2 if counts[material] * 2 > area else 1)
		gains[rate[0]] = gains.get(rate[0], 0) + amount
	return gains
