extends ChBehaviour

# The Cutter Rocket (spec §5.4): a straight shot along facing() whose blast digs the ground it
# meets and whose hit on a hull pays through deal_hit. Ignition is the rocket's own listener:
# whenever anything catches fire, the rocket's countdown halves, so its next shot charges faster.
# The numbers live here, not on ChPartDef: the def carries cost, cooldown and damage only.

const SPEED := 160.0  # cells per second along facing()
const BLAST_RADIUS := 6
const BLAST_POWER := 300.0

func setup(ctx: ChBattleContext) -> void:
	# Ignition hears every caught fire, on either side, so the subscription carries no range.
	# The behaviour is the listener break_part unsubscribes, which is ChBehaviour's contract.
	ctx.bus.subscribe(self, ChEvent.CAUGHT_FIRE, func(caught: ChEvent): _ignite())

func fire(ctx: ChBattleContext) -> void:
	# The shot leaves the part's own anchor pointing where the part points, with no fall: a
	# straight line. ChProjectile owns the flight, the segment test and the self-free.
	if ctx.world == null:
		return
	var bolt := ChProjectile.new()
	# The bolt hangs under the world node, whose transform is the arena's own, so the bolt's global
	# position is the cell space world.raycast reads.
	ctx.world.add_child(bolt)
	bolt.global_position = part.anchor_world()
	bolt.setup(ctx, part, part.facing() * SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))
	# The look: a launch flash at the mount and the rocket sprite riding the bolt.
	ChFx.spawn(ctx.world, &"muzzle", part.anchor_world(), part.facing())
	bolt.trail = ChFx.spawn(bolt, &"rocket", Vector2.ZERO, part.facing())

func _ignite() -> void:
	# Ignition: the countdown left before the next shot is halved, so a caught fire buys speed
	# rather than another charge. A part already ready has 0 left, and half of 0 is still ready.
	# shortcut: repeated catches keep halving whatever is left, which is what the rule reads.
	part.cooldown_left *= 0.5

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	# The raycast dict the projectile hands back: "position" is the cell the segment met, and
	# "collider" answers a body when the met thing was one.
	var at: Vector2i = shot["position"]
	# The blast goes off whatever was met, so a miss still digs.
	ctx.world.explode(at, BLAST_RADIUS, BLAST_POWER)
	ChFx.spawn(ctx.world, &"blast", Vector2(at))
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		# A body hit is a fight hit, so it pays through the fight's one damage entry point.
		# A hull hit answers no part, which is ChDamage's chassis split, not something here repeats.
		# shortcut: the blast itself deals no area damage in the slice; only the direct hit pays.
		ctx.deal_hit(part, met, part.def.damage)
