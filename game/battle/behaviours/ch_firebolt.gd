extends ChBehaviour

# The Firebolt Launcher (spec §5.4): a lobbed bolt that breaks into a pool of fire wherever it
# lands. The lob is 20 degrees up from facing at 150 cells per second under a gravity of 120, so
# ChProjectile carries the arc; this only aims it and reads the impact back.
# The launcher is the slice's charge-limited part: five shots. At zero ChPartRuntime.is_ready is
# false, so a press no longer fires or pays for it.

const SPEED := 150.0  # cells per second out of the barrel
const LOFT := 20.0  # degrees the shot leaves the barrel above facing
const GRAVITY := 120.0  # cells per second squared the bolt falls under
const BLAST_RADIUS := 8
const BLAST_POWER := 300.0
const FIRE_RADIUS := 4

func fire(ctx: ChBattleContext) -> void:
	# Out of charges there is nothing to fire. is_ready keeps a press from reaching this; the guard
	# stays as the part's own answer for any other caller.
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
	ChFx.spawn(ctx.world, &"muzzle", part.anchor_world(), dir.rotated(up))

func process(ctx: ChBattleContext, delta: float) -> void:
	# At zero charges the countdown is parked at a value that never counts down, so anything that
	# reads cooldown_left alone (not only is_ready) also sees a launcher that will not fire again.
	# The fire that spent the last charge already reset the countdown to def.cooldown in this same
	# tick, so this parks that reset rather than fighting it.
	# shortcut: a part that gains charges (a refill, Task 14) would need its countdown handed back here.
	if part.charges_left == 0:
		part.cooldown_left = INF

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	# The bolt lands: it breaks, and the pool of fire it leaves is what sets the next parts alight.
	var at: Vector2i = shot["position"]
	ctx.world.explode(at, BLAST_RADIUS, BLAST_POWER)
	# The fire goes in after the blast, so the blast cannot blow the fresh fire away.
	ctx.world.fill_circle(at, FIRE_RADIUS, &"fire")
	ChFx.spawn(ctx.world, &"fire_blast", Vector2(at))
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		# A hull or part in the way of the landing pays through the fight's one entry point.
		ctx.deal_hit(part, met, part.def.damage)
