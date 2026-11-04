extends ChBehaviour

# The Corsair Harpoon (spec §5.4): a line along facing() hooks the enemy hull at its far end and
# reels both sides together for a second and a half. Not a projectile: the hook is a raycast, and
# the pull is one impulse per fight tick.
# The impulse is the engine's own scale: a hull's Box2D mass is 42 cells of wood for a 10x6 rig and
# 70 for a 10x10 one, and below roughly 1.6e4 a tick the hull does not move at all, which is Box2D's
# resistance rather than a rule this file adds. ChariotBuilder's 3e6 motor torque is the same family.

const RANGE := 120.0  # cells the line reaches
const PULL := 20000.0  # impulse per tick, toward the other hull
const ATTACH := 1.5  # seconds the line stays attached

var attach_left := 0.0  # seconds of pull left
var hook: Object = null  # the body the line is attached to
var line: Line2D = null  # the rope drawn while attached


func fire(ctx: ChBattleContext) -> void:
	# The attach window (1.5 s) always ends before this part's next fire (5 s cooldown), so there is
	# no running attach to close here.
	# shortcut: a harpoon whose cooldown went under the attach window would want _end_line() first.
	if ctx.world == null:
		return
	var anchor := part.anchor_world()
	# The mask is the brief's: bodies and solid terrain, so the segment stops at the near end of
	# whatever it met. Powders stay out of the mask, so the line runs through sand.
	# Measured: a hull face 27 cells out answers with that body; one 137 cells out answers empty,
	# and the arena floor 2 cells below the line never ends a flat shot.
	var shot: Dictionary = ctx.world.raycast(anchor, anchor + part.facing() * RANGE,
		PixelWorld.RAY_BODIES | PixelWorld.RAY_SOLID)
	var met: Object = shot.get("collider")
	if met == null or not is_instance_valid(met):
		# Ground, or nothing: the line hooked no hull, so no damage and no pull.
		# shortcut: a line that ends in terrain stays unattached rather than anchoring to the wall.
		return
	if ctx.chariot_of_body(met) == ctx.own(part):
		# The line hooked its own chariot, so the hook is dropped: the pull below moves both hulls
		# toward each other, which is not what a line anchored inside its own mount should do.
		return
	# The hook belongs to the fight, so it pays through the fight's one damage entry point.
	ctx.deal_hit(part, met, part.def.damage)
	hook = met
	attach_left = ATTACH
	_draw_line(ctx, anchor)


func process(ctx: ChBattleContext, delta: float) -> void:
	# The reel belongs to the fight's clock, so it runs once per tick while the line is attached.
	if attach_left <= 0.0:
		return
	# The hooked body can go inside the window (a wrecked rig, a body freed for any other reason):
	# reading its position would be an access to freed, so the reel and the rope both end with it.
	# shortcut: the attach ends rather than re-hooks; a harpoon that wanted to retarget mid-reel
	# would need a raycast here, which the brief's rule does not ask for.
	if not is_instance_valid(hook):
		attach_left = 0.0
		_end_line()
		return
	attach_left = maxf(0.0, attach_left - delta)
	var anchor := part.anchor_world()
	# The impulse goes at the body's own centre so Box2D reads a push rather than a twist: an
	# impulse off the centre line spins the hull, which is not the reel the rule asks for.
	var haul: Vector2 = anchor - hook.global_position
	if haul.length() > 0.0:
		hook.apply_force(haul.normalized() * PULL, hook.global_position)
		var own: ChChariotRuntime = ctx.own(part)
		# The equal and opposite push, so the gap closes from both sides rather than the hooked hull
		# flying alone. The chassis carries the build, so that is where the push goes.
		# shortcut: the chassis alone gets it; a build whose mass sits in its parts would want them too.
		if own != null and is_instance_valid(own.chassis):
			own.chassis.apply_force(own.chassis.global_position.direction_to(hook.global_position)
				* PULL, own.chassis.global_position)
		_draw_line(ctx, anchor)
	if attach_left <= 0.0:
		# The rope goes with the attach window, so nothing keeps drawing a line that hooked nothing.
		_end_line()


func _draw_line(ctx: ChBattleContext, from: Vector2) -> void:
	# The rope the brief asks for while attached: two points, the firing part's anchor and the body
	# the line is hooked to. It hangs under the world node, whose transform is the arena's own, so
	# the points written here are already the local ones.
	if line == null:
		line = Line2D.new()
		ctx.world.add_child(line)
		# A Line2D is one pixel wide by default, which is what a rope at this arena's scale reads as.
		# shortcut: the default colour; a HUD that wants the rope in its own hue sets a palette here.
		line.width = 1.0
	# The points are replaced every tick rather than added: a Line2D starts with none, and the far
	# end follows the hull the line is hooked to, which Box2D keeps moving.
	line.points = PackedVector2Array([from, hook.global_position])


func _end_line() -> void:
	# The attach window ended, so the rope and the hook both go: the part fires again on its own
	# cooldown and a fresh fire re-hooks whatever the line meets then.
	if line != null and is_instance_valid(line):
		line.queue_free()
	line = null
	hook = null
