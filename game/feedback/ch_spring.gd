class_name ChSpring extends RefCounted

# One damped spring per scalar: the settle behind the feedback that outlives a beat (scale, rotation),
# and (Task 2) the long travel of a ChCard chasing its slot.
# Semi-implicit Euler at a fixed substep, so one frame's motion reads the same at any frame rate.
const MAX_OFFSET := 2.0
# A longer frame is split into substeps of at most this, which is what keeps a stiff spring
# from blowing up when one frame stalls.
const MAX_STEP := 1.0 / 120.0

var value: float
var velocity := 0.0
var rest: float
var stiffness := 400.0
var damping := 38.0
# The value never sits further than this from rest: a bound on the spring's own travel, so a
# stalled frame cannot fling it off. Juice springs keep the default (they live around rest 1.0);
# a ChCard follow spring crosses hundreds of pixels and lifts this to INF.
var max_offset := MAX_OFFSET


func _init(rest_in: float) -> void:
	rest = rest_in
	value = rest_in


func step(delta: float) -> void:
	# shortcut: a long frame costs one substep per 1/120 s with no upper bound (a 10 s frame is
	# 1200 steps); cap the loop if a stalled frame ever reaches the springs.
	var remaining := delta
	while remaining > 0.0:
		var h := minf(remaining, MAX_STEP)
		velocity += (-stiffness * (value - rest) - damping * velocity) * h
		value += velocity * h
		value = clampf(value, rest - max_offset, rest + max_offset)
		remaining -= h
