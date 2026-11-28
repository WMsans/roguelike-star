extends ChPartTest

# Task 7: the part sweep (Review Focus 1 and 2). Every part the catalog holds is mounted on slot 3
# of the mirrored side-1 RIG and fights a side-0 RIG carrying a Steel Plate for 3 s, both sides
# pressing and holding, with frames = false so the fight is the ctx clock alone.
# Two things are asserted: nothing a part does lands a HIT on its own side, and no part errors. A
# script error stops the test body, which the runner reads as a failure (ChTest's completion marker),
# so the id printed before each run is what names the part that broke.
# The second pass kills side 0 at 1 s (HP 0 and its chassis freed), so a part firing, holding or
# triggering with no target left must not error either.

const TICKS := 180  # 3 s at 60 fps, both sides pressing and holding
const KILL_TICK := 60  # 1 s: the second pass kills the target here
const TARGET: Array = [[3], &"steel_plate"]  # side 0's one part: a passive that only soaks


func test_every_part_fights_without_erroring() -> void:
	var catalog := ChCatalog.load_default()
	for id in _ids(catalog):
		await _sweep(catalog, id, false)
	_complete()


func test_every_part_fights_a_target_that_dies() -> void:
	var catalog := ChCatalog.load_default()
	for id in _ids(catalog):
		await _sweep(catalog, id, true)
	_complete()


func _ids(catalog: ChCatalog) -> Array[StringName]:
	# Sorted, so a failure names the part after the last id printed rather than a dictionary order.
	var out: Array[StringName] = []
	for id in catalog.parts:
		out.append(id)
	out.sort()
	return out


func _sweep(catalog: ChCatalog, id: StringName, kill_target: bool) -> void:
	print("sweep: %s%s" % [id, " (target dies)" if kill_target else ""])
	var ctx: ChBattleContext = await duel([TARGET], [[[3], id]])
	var hits: Array[ChEvent] = []
	ctx.bus.subscribe(RefCounted.new(), ChEvent.HIT, func(event: ChEvent): hits.append(event))
	var killed := false
	for tick in TICKS:
		if kill_target and not killed and tick >= KILL_TICK:
			# The target is gone: no HP and no hull, so a part that reads either has to hold.
			ctx.chariots[0].hp = 0
			ctx.chariots[0].chassis.free()
			killed = true
		ctx.tick(TICK, [0.0, 0.0], [true, true], [true, true])
	for hit in hits:
		assert_true(hit.data["target_side"] != hit.side, "%s: a HIT landed on its own side" % id)