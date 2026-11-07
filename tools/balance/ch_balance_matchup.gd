class_name ChBalanceMatchup extends RefCounted

# One runnable pairing out of a scenario: the two layouts, the catalog they build against (the
# default one plus any hp overrides this pairing asked for), the seeds to fight and how each side
# drives. ChBalanceScenario makes these; run.gd fights them.

var name: String = ""
var player: ChChariotLayout = null
var enemy: ChChariotLayout = null
var catalog: ChCatalog = null
var seeds: Array[int] = []
var drive: PackedStringArray = ["ai", "ai"]  # [player, enemy], each one of ChBalanceDrivers.POLICIES
var expect: Dictionary = {}  # dotted metric path -> [min, max], checked by ChBalanceReport
