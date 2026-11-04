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
	# Out of charges there is nothing to fire. ChBattleContext asked for this part's energy first,
	# so process drops that entry below.
	if part.charges_left == 0:
		return
	# shortcut: an affordable request at 0 charges is still paid by the pool and fires nothing,
	# because the loop pays before it asks; a pool that cannot pay it leaves the entry queued.
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
	# At zero charges the launcher stops requesting: the loop asks a ready part every tick, so the
	# part's answer is to cancel its own entry the moment the pool has ticked.
	# shortcut: this cancels once per tick rather than gating the request itself, since ChBattleContext
	# owns the request call and gives a behaviour no hook before it.
	if part.charges_left == 0:
		var chariot: ChChariotRuntime = ctx.own(part)
		if chariot != null:
			chariot.energy.cancel(part)

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
