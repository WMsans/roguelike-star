extends ChBehaviour

# The Ring of Fire (spec §5.4): fire fills an expanding ring from the part's own anchor, radius 0 -> 24
# over 1 s, and every body the ring crosses pays its damage (the def's 10) once -- both sides, the chassis it hangs on included.
# The crossing test is geometric (radius vs body box, ChBehaviour's own footprints), so the fire cells
# and the damage stay independent, which is what makes a body behind a wall of fire still pay.

const RADIUS := 24.0
const STEPS := 10  # one step every 0.1 s over the 1 s expansion
const STEP_SECONDS := 0.1

var steps_left := 0  # steps of the expansion left to run
var step_left := 0.0  # seconds until the next step
var crossed: Array = []  # the bodies the ring has already paid


func fire(ctx: ChBattleContext) -> void:
	# The crossing list restarts with the ring, so a second fire pays the same bodies again.
	# shortcut: one ring at a time; overlapping rings would want a per-ring list.
	steps_left = STEPS
	step_left = 0.0
	crossed.clear()

func process(ctx: ChBattleContext, delta: float) -> void:
	# A ring that finished expanding does nothing until the loop fires the part again.
	if steps_left <= 0:
		return
	step_left -= delta
	if step_left > 0.0:
		return
	# The step countdown restarts against the leftover, so 10 steps land 0.1 s apart at any frame rate.
	# shortcut: the ring's clock is the fight's delta, the same one cooldowns and pools count against.
	step_left += STEP_SECONDS
	steps_left -= 1
	_expand(ctx)

func _expand(ctx: ChBattleContext) -> void:
	var at := part.anchor_world()
	# The ring is STEPS steps of RADIUS/STEPS, so the first step is 2.4 cells out and the last is 24.
	# shortcut: the step at radius 0 has no circumference, so nothing is written at t = 0.
	var r := RADIUS * float(STEPS - steps_left) / float(STEPS)
	_fill_ring(ctx, at, r)
	_cross(ctx, at, r)

func _fill_ring(ctx: ChBattleContext, at: Vector2, r: float) -> void:
	# Fire goes into air cells only, on the ring's own cell: within r of the anchor and not yet inside
	# the r - 1 circle inside it, which makes the band one cell thick whatever the radius.
	if ctx.world == null:
		return
	for y in range(floori(at.y - r), ceilf(at.y + r) + 1):
		for x in range(floori(at.x - r), ceilf(at.x + r) + 1):
			# shortcut: the step scans its whole square (~2.4k cells at r = 24, x 10 steps); upgrade to
			# walking the circumference by angle if a bigger ring makes this hot.
			var cell := Vector2(x + 0.5, y + 0.5)
			var near := at.distance_to(cell)
			if near > r or near <= r - 1.0:
				continue
			var spot := Vector2i(x, y)
			# get_material_at answers &"air" inside a loaded chunk and &"" off one, so both count as air.
			var material := ctx.world.get_material_at(spot)
			if material == &"air" or material == &"":
				ctx.world.set_cell(spot, &"fire")

func _cross(ctx: ChBattleContext, at: Vector2, r: float) -> void:
	# The ring crosses a body once its radius reaches the body's nearest edge, measured against ChBehaviour's
	# footprints. The scan takes every chariot whatever its side, which is the brief's "own chassis included".
	for other in ctx.chariots:
		if other == null:
			continue
		var bodies: Array = [[other.chassis, _hull_box(other)]]
		for foe in other.parts:
			if foe.broken or foe.def == null:
				continue
			bodies.append([foe.body, _part_box(foe)])
		for entry in bodies:
			var body: Object = entry[0]
			if body == null or not is_instance_valid(body):
				continue
			if body == part.body:
				# The ring expands out from the part's own anchor, so the circumference never crosses the
				# body it leaves from: the emitter pays itself nothing, and the hull it hangs on still pays.
				continue
			if body in crossed:
				# The ring pays a body once, so a later step that still covers it spends nothing.
				# shortcut: identity is the key, so a body that fell off a broken part is out of the list.
				continue
			if _reaches(at, r, entry[1]):
				crossed.append(body)
				ctx.deal_hit(part, body, part.def.damage)

func _reaches(at: Vector2, r: float, box: Rect2) -> bool:
	# The nearest point of the body's box to the ring's anchor: the ring crossed the body when the
	# radius got that far, so an anchor inside the box crosses at the first step.
	var near := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
	return at.distance_to(near) <= r
