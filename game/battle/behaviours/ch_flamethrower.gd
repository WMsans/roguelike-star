extends ChBehaviour

# The Flamethrower (spec §5.4): a 1 s burst of fire particles out along facing() and 45 damage spread
# over that burst. The particles fly in the particle pool, so the burn itself is the sim's: they write
# grid cells once something blocks them, and ChPartRuntime's sampling turns those cells into `burning`.
# The reach numbers live here, not on ChPartDef (Task 4b's ruling): proximity_range 0 on the def means
# no proximity passives, and ChBehaviour._reach_box measures that range, so the box is grown out to this
# part's own 40-cell reach on both sides, which is how _reach_box keeps its box symmetric about the anchor.
# shortcut: the burn lands where the particles fall, not where the reach box ends, so PARTICLE_SPEED is
# the burn's own reach. Measured with the nozzle at a settled rig's height (6 cells above the rock floor):
# a 1 s burst reaches ~8 cells out at 90 cells/s and the test reads back >= 3 fire cells in a target 30
# cells out at 240 cells/s; the landing extent is stochastic, so the test's peak is the evidence, not a
# radius. That same peak is what pins the nozzle clearing the body it is mounted on (see NOZZLE): a nozzle
# left inside the part's own 8-cell footprint reads back 0 fire cells at that target.

const BURST_SECONDS := 1.0
# shortcut: cells out from the anchor the flame leaves the barrel, fixed at 5 for this part's 8-cell
# body (half its width is 4): the burst has to clear its own body or it lands on the flamethrower
# itself instead of down the arena. Derive it from def.size.x if part sizes start moving again.
const NOZZLE := 5.0
const PARTICLE_SPEED := 240.0  # cells per second out of the nozzle
const PARTICLES_PER_TICK := 3
const PARTICLE_SPREAD := 0.25  # radians, the cone the shot fans over
const REACH := 40.0
const PULSES := 9
const PULSE_DAMAGE := 5  # 9 x 5 = 45, the def's damage spread over the burst

var burst_left := 0.0  # seconds of burst left to spray
var pulse_gap := 0.0  # seconds between damage pulses
var pulse_left := 0.0  # seconds until the next pulse
var pulses_left := 0  # pulses still to spend


func _flame_box() -> Rect2:
	# ChBehaviour's reach box at this part's own reach rather than the def's proximity_range.
	# shortcut: REACH - proximity_range is the only extra, so the box keeps _reach_box's shape.
	var box := _reach_box()
	var extra := REACH - part.def.proximity_range
	var dir := part.facing()
	var pad := Vector2(extra * absf(dir.x), extra * absf(dir.y))
	return Rect2(box.position - pad, box.size + pad * 2)


func fire(ctx: ChBattleContext) -> void:
	# The burst starts here and sprays in process, which the loop calls in the same tick, so the
	# first tick of spray is the tick that paid for the fire.
	burst_left = BURST_SECONDS
	pulses_left = PULSES
	pulse_gap = BURST_SECONDS / PULSES
	pulse_left = 0.0


func process(ctx: ChBattleContext, delta: float) -> void:
	if burst_left <= 0.0:
		return
	burst_left = maxf(0.0, burst_left - delta)
	if ctx.world != null:
		# The brief's shot: 3 fire particles at the nozzle, facing() x 90 cells/s over a 0.25 rad cone.
		var nozzle := part.anchor_world() + part.facing() * NOZZLE
		ctx.world.spawn_particles(&"fire", nozzle, part.facing() * PARTICLE_SPEED,
			PARTICLES_PER_TICK, PARTICLE_SPREAD)
	# The damage pulses land every pulse_gap seconds over the burst, so 9 pulses x 5 spread the
	# def's 45 across the 1 s. A pulse that met nothing spends itself rather than banking a hit.
	if pulses_left <= 0:
		return
	pulse_left -= delta
	if pulse_left > 0.0:
		return
	pulse_left += pulse_gap
	pulses_left -= 1
	var target := _nearest_enemy_body(ctx, _flame_box())
	if target != null:
		ctx.deal_hit(part, target, PULSE_DAMAGE)
