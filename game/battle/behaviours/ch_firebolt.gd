extends ChBehaviour

# The Firebolt Launcher (spec §5.4): a lobbed bolt that breaks into a pool of fire wherever it
# lands. The lob is 60 degrees up from facing at 110 cells per second under a gravity of 120, so
# ChProjectile carries the arc; this only aims it and reads the impact back.
# The launcher is the slice's charge-limited part: five shots, and at zero it stops asking for
# energy, which is the rule ChBattleContext left to the behaviour ("a limited part at 0 charges is
# still ready and still asks for energy").

const SPEED := 110.0  # cells per second out of the barrel
const LOFT := 60.0  # degrees the shot leaves the barrel above facing
const GRAVITY := 120.0  # cells per second squared the bolt falls under
const BLAST_RADIUS := 8
const BLAST_POWER := 300.0
const FIRE_RADIUS := 4

func fire(ctx: ChBattleContext) -> void:
	# Out of charges there is nothing to fire. process parks the countdown below, so the loop should
	# never have asked this part; the guard stays as the part's own answer, not the fix.
	if part.charges_left == 0:
		return
	if ctx.world == null:
		return
	var dir := part.facing()
	# The loft tilts up whichever way the part points, so a mirrored mount still lobs skyward.
	var up := deg_to_rad(-LOFT) if dir.x >= 0.0 else deg_to_rad(LOFT)
	var bolt := ChProjectile.new()
	ctx.world.add_child(bolt)
	bolt.global_position = part.anchor_world()
	bolt.setup(ctx, part, dir.rotated(up) * SPEED, GRAVITY, func(shot: Dictionary): _impact(ctx, shot))

func process(ctx: ChBattleContext, delta: float) -> void:
	# At zero charges the launcher stops requesting. ChBattleContext asks the parts whose countdown
	# reached 0, so the part's answer is to stop being ready: it parks its countdown at a value that
	# can never count down, so no request is made for it, the pool pays nothing, and no PART_FIRED
	# announces a shot that never happened. The fire that spent the last charge already reset the
	# countdown to def.cooldown in this same tick, so this parks that reset rather than fighting it.
	# shortcut: parked here rather than as a charges_left > 0 test at the request site, which is the
	# rule ChBattleContext's own comment left to the behaviour; a part that gains charges (a refill,
	# Task 14) would need its countdown handed back here.
	if part.charges_left == 0:
		part.cooldown_left = INF

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	# The bolt lands: it breaks, and the pool of fire it leaves is what sets the next parts alight.
	var at: Vector2i = shot["position"]
	ctx.world.explode(at, BLAST_RADIUS, BLAST_POWER)
	# The fire goes in after the blast, so the blast cannot blow the fresh fire away.
	ctx.world.fill_circle(at, FIRE_RADIUS, &"fire")
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		# A hull or part in the way of the landing pays through the fight's one entry point.
		ctx.deal_hit(part, met, part.def.damage)
