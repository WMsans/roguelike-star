extends ChBehaviour

# The Hearth (spec §5.4): it charges for 1 s, then rings fire into the air cells 2 cells out from its
# own chariot's hull, every 0.25 s, and pays the enemy bodies standing in that ring. The ring is the
# burn's source: ChPartRuntime samples those cells and sets its own parts alight, which is chain 3's
# risk. The charge's tint belongs to the renderer, so the charge itself is a timer here.
# shortcut: PULSES x PULSE_SECONDS is 2.25 s of ring, the plan's "45 total over 9 pulses"; the brief's
# "3 s" window would pay 60, so the pulse count is what the plan pins.

const CHARGE_SECONDS := 1.0
const RING := 2  # cells the ring sits out from the own hull
const PULSE_SECONDS := 0.25
const PULSES := 9
const PULSE_DAMAGE := 5

var charge_left := 0.0  # seconds of charge left before the ring opens
var pulse_left := 0.0  # seconds until the next pulse
var pulses_left := 0  # pulses still to spend

func fire(ctx: ChBattleContext) -> void:
	# The ring opens when the charge runs out, and the first pulse lands on that tick.
	# shortcut: the countdown lives in process, so a hearth pays nothing on the tick it is fired.
	# A ring of one chariot at a time is the whole rule: the hull's box is re-read each pulse, so a
	# hull that moved since the fire still gets a ring around where it stands.
	# shortcut: the box is read per pulse rather than cached, which is what keeps a rolling rig ringed.
	# The hearth needs no subscription, so setup stays the base's no-op: nothing here listens, and the
	# pulses run off process, which ChBattleContext.tick calls for every part whatever it is ready to do.
	# shortcut: no setup call means no listener to leak, which is why setup is not overridden here.
	# Task 15 owns the setup call in game/; a behaviour that did subscribe would stay dead without it.
	charge_left = CHARGE_SECONDS
	pulses_left = PULSES
	pulse_left = 0.0

func process(ctx: ChBattleContext, delta: float) -> void:
	# A hearth still charging rings nothing, so the charge gates both the fill and the damage.
	if charge_left > 0.0:
		# shortcut: only the charge counts down before the ring opens, so an idle hearth costs nothing.
		# The tint the brief names belongs to the HUD (Task 15), since nothing here renders a part.
		# shortcut: upgrade to a real tint if a part ever gains a renderer hook.
		charge_left = maxf(0.0, charge_left - delta)
		if charge_left > 0.0:
			return
	if pulses_left <= 0:
		# The ring is over: a hearth that spent its pulses does nothing until the loop fires it again.
		# shortcut: the loop owns the cooldown reset and the charge spend, so nothing is banked here.
		return
	pulse_left -= delta
	if pulse_left > 0.0:
		return
	# The countdown restarts against the leftover so 9 pulses land 0.25 s apart whatever the frame rate.
	# shortcut: restarting rather than counting seconds keeps the pulses on the fight's own clock.
	# A pulse that found nothing in the ring still spends itself, which is the brief's "per pulse":
	# an enemy that steps out of the ring mid-window pays fewer than 9 hits, not the full 45.
	pulse_left += PULSE_SECONDS
	pulses_left -= 1
	_ring(ctx)


func _ring(ctx: ChBattleContext) -> void:
	var chariot: ChChariotRuntime = ctx.own(part)
	if chariot == null or chariot.chassis == null:
		return
	# ChBehaviour's own-hull box, the same footprint the melee scan measures.
	var hull := _hull_box(chariot)
	# A cell at (x, y) spans x .. x + 1, so floor/ceil is the cell box that touches the hull.
	var hull_cells := Rect2i(Vector2i(floori(hull.position.x), floori(hull.position.y)),
		Vector2i(ceilf(hull.end.x) - floori(hull.position.x), ceilf(hull.end.y) - floori(hull.position.y)))
	_fill_ring(ctx, hull_cells)
	_pulse(ctx, hull_cells)

func _fill_ring(ctx: ChBattleContext, hull_cells: Rect2i) -> void:
	# The ring is the cell box between the hull and the hull grown by RING cells; fire only goes into
	# air cells, so the hull's own cells and everything solid stays as it is.
	# shortcut: a per-cell write over the band (~80 cells for a 10x6 hull, x 9 pulses); upgrade to one
	# fill_rect per edge if a bigger body makes this hot.
	if ctx.world == null:
		return
	for y in range(hull_cells.position.y - RING, hull_cells.end.y + RING):
		for x in range(hull_cells.position.x - RING, hull_cells.end.x + RING):
			if hull_cells.has_point(Vector2i(x, y)):
				continue
			var at := Vector2i(x, y)
			# get_material_at answers &"air" inside a loaded chunk and &"" off one, so both count as air.
			var cell := ctx.world.get_material_at(at)
			if cell == &"air" or cell == &"":
				ctx.world.set_cell(at, &"fire")

func _pulse(ctx: ChBattleContext, hull_cells: Rect2i) -> void:
	# The ring pays the bodies standing in the band: a body whose box overlaps the grown box and
	# whose box is not fully inside the hull's own box. ChBehaviour's _part_box and _hull_box are the same
	# footprints the melee scan measures, so a ring and a weapon agree about what a body covers.
	for other in ctx.chariots:
		if other == null or other.side == part.side:
			# Only the other sides pay; the ring burns its own chariot's ground, not its HP.
			# shortcut: own-side bodies are never deal_hit here, so chain 3 lands as a catch.
			continue
		var bodies: Array = [[other.chassis, _hull_box(other)]]
		for foe in other.parts:
			if foe.broken or foe.def == null:
				continue
			bodies.append([foe.body, _part_box(foe)])
		for entry in bodies:
			var box: Rect2 = entry[1]
			if not Rect2(hull_cells.grow(RING)).intersects(box):
				continue
			if Rect2(hull_cells).encloses(box):
				continue
			if entry[0] != null and is_instance_valid(entry[0]):
				ctx.deal_hit(part, entry[0], PULSE_DAMAGE)
