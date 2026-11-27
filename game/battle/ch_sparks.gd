class_name ChSparks extends RefCounted

# Sparks: a discharge floods through touching water and steel, lights the explosives it reaches
# (world.ignite, as a blast lights them), draws an arc of spark cells, and shocks every holder
# whose sample rect it reached. Batteries are blocks of battery cells that discharge once a status
# second and leak acid where a cell broke, checked every tick.
# An instance at ctx.sparks, because the recorded batteries are per fight.

const CONDUCTORS: Array[StringName] = [&"water", &"steel"]
const EXPLOSIVES := ChHazards.EXPLOSIVES
const SPARK_SHOCK := 2
const MAX_CELLS := 600  # reached cells, seeds included
const ARC_CELLS := 24  # air cells turned to spark per discharge
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var _batteries: Array = []  # each an Array[Vector2i] of the battery cells still standing
var _gases := {}  # the world's gas-class material names, read on the first tick with a battery


static func discharge(ctx: ChBattleContext, seeds: Array[Vector2i], shock := true) -> Array:
	# Answers the holders shocked, each chariot by side, its body, then its parts in mount order.
	var world := ctx.world
	var reached := {}
	var queue: Array[Vector2i] = []
	for at in seeds:
		if reached.size() < MAX_CELLS and not reached.has(at):
			reached[at] = true
			queue.append(at)
	var head := 0
	while head < queue.size() and reached.size() < MAX_CELLS:
		var at := queue[head]
		head += 1
		for d in DIRS:
			var next := at + d
			if reached.size() >= MAX_CELLS or reached.has(next) or world.get_material_at(next) not in CONDUCTORS:
				continue
			reached[next] = true
			queue.append(next)
	var arc := ARC_CELLS
	for at in queue:
		if world.get_material_at(at) in EXPLOSIVES:
			world.ignite(at)
		for d in DIRS:
			var next := at + d
			if reached.has(next):
				continue
			var m := world.get_material_at(next)
			if m in EXPLOSIVES:
				world.ignite(next)
			elif m == &"air" and arc > 0:
				world.set_cell(next, &"spark")
				arc -= 1
	var shocked: Array = []
	if not shock:
		return shocked
	for chariot in ctx.chariots:
		if chariot == null or chariot.hp <= 0:
			continue
		var holders: Array = [chariot]
		holders.append_array(chariot.parts.filter(func(p: ChPartRuntime) -> bool: return not p.broken))
		for holder in holders:
			var rect: Rect2i = holder.sample_rect()
			if queue.any(func(at: Vector2i) -> bool: return rect.has_point(at)):
				shocked.append(holder)
	for holder in shocked:
		ctx.give_status(holder, ChStatuses.SHOCK, SPARK_SHOCK, 1, null, &"sparks")
	return shocked


func add_battery(ctx: ChBattleContext, rect: Rect2i) -> void:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if ctx.world.get_material_at(Vector2i(x, y)) == &"battery":
				cells.append(Vector2i(x, y))
	if not cells.is_empty():
		_batteries.append(cells)


func tick(ctx: ChBattleContext) -> void:
	# Every frame, so a blast's crater is read before sand refills it: a recorded cell that is now air
	# or any gas (fire, smoke, steam...) broke and leaks acid; one that is now anything else (sand
	# fell in) is forgotten dry. A block with no cells left is dropped.
	if _batteries.is_empty():
		return
	if _gases.is_empty():
		for m in ctx.world.material_set.materials:
			if m.material_class == PixelMaterial.CLASS_GAS:
				_gases[m.name] = true
	for block in _batteries:
		var left: Array[Vector2i] = []
		for at in block:
			var m := ctx.world.get_material_at(at)
			if m == &"battery":
				left.append(at)
			elif m == &"air" or _gases.has(m):
				ctx.world.set_cell(at, &"acid")
		block.assign(left)
	_batteries = _batteries.filter(func(block: Array) -> bool: return not block.is_empty())


func second(ctx: ChBattleContext) -> void:
	# Once a status second, before the holders are snapshotted: each block with cells left discharges
	# from them.
	for block in _batteries:
		discharge(ctx, block)
