class_name ChRun extends RefCounted

# The run itself: which fight is being fought, on what build, against whose cook, for what pay.
# No nodes and no screens: the shop phase (Task 7), the fight rules (Task 8) and the main loop
# (Task 13) all read this one object.
# shortcut: rules() is deliberately absent. Its return type is ChFightRules, which Task 8 defines,
# and that task writes the method (one line over modifiers.get(index) and kind(index)) with its tests.

const FIRST_HP := 500  # enemy HP at fight 0; Task 13's balance runner tunes this one line
const LAST_HP := 1500  # the ramp's top, reached at the last elite, before that fight's x1.25
const LAST_INDEX := 9  # a run is 10 fights, 0-based, and the last one is the boss
const ELITE_INDEXES := [2, 5, 8]
const MODIFIERS := [&"fire_halved", &"time_limit", &"chains_weak"]
const ENEMY := "res://game/data/enemies/dozer_cook.tres"  # the run's one enemy build, as data

var seed: int = 0
var rng: RandomNumberGenerator = null  # every draw in the run comes off this one rng
var catalog: ChCatalog = null  # player_layout re-reads the body's HP through it
var fight_index := 0
var gold := 20  # the spec's start gold
var hp_bonus := 0  # what the shop's +100 max HP option adds, on top of the body's own HP
var inventory: ChInventory = null
var layout: ChChariotLayout = null
var modifiers: Dictionary = {}  # fight index -> a modifier StringName; elites and the boss only


static func start(seed: int, catalog: ChCatalog) -> ChRun:
	# The kit a run begins with: the Cutter on its wheels with one chainsaw, an empty five-slot
	# inventory, 20 gold, and the elite/boss modifiers drawn now so the seed replays the same run.
	var run := ChRun.new()
	run.seed = seed
	run.rng = RandomNumberGenerator.new()
	# rng.seed is a fixed int, so the same run seed gives the same draws and the same fight seeds.
	run.rng.seed = seed
	run.catalog = catalog
	run.inventory = ChInventory.new()
	run.inventory.capacity = ChInventory.CAPACITY
	# The starting build, mounted through place() so it is a build like any other the garage edits.
	run.layout = ChChariotLayout.new()
	run.layout.body_id = &"cutter"
	var body: ChBodyDef = catalog.body(&"cutter")
	# shortcut: a catalog with no Cutter def leaves the run on an empty build; every caller here hands
	# in the default catalog, which the catalog tests keep populated.
	if body != null:
		# The two lowest slots are the wheel mounts (ch_body_def.gd's header): +y is down, so the
		# largest y is the lowest. Read off the def, so a re-tuned body moves the mounts with it.
		var order: Array[int] = []
		for i in body.slots.size():
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return body.slots[a].y > body.slots[b].y)
		var mounts: Array[int] = order.slice(0, 2)
		for mount in mounts:
			run.layout.place([mount], &"wheel")
		for i in body.slots.size():
			if not mounts.has(i):
				# The first slot that is not a wheel mount, i.e. the first one a weapon can use.
				run.layout.place([i], &"cutter_chainsaw")
				break
	for index in ELITE_INDEXES + [LAST_INDEX]:
		run.modifiers[index] = MODIFIERS[run.rng.randi_range(0, MODIFIERS.size() - 1)]
	return run


func kind(index: int) -> StringName:
	if index == LAST_INDEX:
		return &"boss"
	if ELITE_INDEXES.has(index):
		return &"elite"
	return &"normal"


func reward(index: int) -> int:
	# The spec's pay table. The boss pays nothing because beating it ends the run.
	match kind(index):
		&"elite":
			return 10
		&"boss":
			return 0
	return 5


func enemy_hp(index: int) -> int:
	# FIRST_HP at fight 0 up to LAST_HP at the last elite, then that fight's multiplier (elite x1.25,
	# boss x1.5). The ramp stops at the last elite, so the boss is LAST_HP x1.5.
	var ramp: int = ELITE_INDEXES[ELITE_INDEXES.size() - 1]
	var at := lerpf(FIRST_HP, LAST_HP, mini(index, ramp) / float(ramp))
	if index == LAST_INDEX:
		return roundi(at * 1.5)
	if ELITE_INDEXES.has(index):
		return roundi(at * 1.25)
	return roundi(at)


func enemy_layout(index: int) -> ChChariotLayout:
	# The cook, with this fight's HP. load() returns one cached instance for the whole process, so
	# the copy has to be real: duplicate(true) drops this script's own fields (body_id, max_hp, slots),
	# and mirrored() twice inverts every flip back to what the file has. The battle mirrors the enemy
	# itself, so what the run hands out stays unmirrored.
	var cook: ChChariotLayout = ResourceLoader.load(ENEMY)
	var copy := cook.mirrored().mirrored()
	copy.max_hp = enemy_hp(index)
	return copy


func player_layout() -> ChChariotLayout:
	# A copy, so the fight never edits the build the garage is showing, and the max HP is re-read from
	# the body's def through the catalog, so a body swap re-derives it instead of keeping the old one.
	var copy := layout.mirrored().mirrored()
	var body: ChBodyDef = catalog.body(layout.body_id)
	copy.max_hp = (body.hp if body != null else 0) + hp_bonus
	return copy


func fight_seed(index: int) -> int:
	# The seed a fight's arena is built from: the same run and fight index give the same fight.
	return hash([seed, index])


func is_last(index: int) -> bool:
	return index == LAST_INDEX
