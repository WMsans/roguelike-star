class_name ChBehaviour extends RefCounted

# The base a part's behaviour script extends (Tasks 12-14 file one per part): `part` plus four
# hooks, all no-ops here, so a behaviour overrides only the ones it needs. A part with no behaviour
# (ChPartDef.behaviour left null until Tasks 12-14 set it) is never asked any of them.
# A behaviour is also the listener its subscriptions are keyed on: ChBattleContext calls setup so
# the behaviour subscribes itself, and ChChariotRuntime.break_part unsubscribes that same listener
# when the part it drives breaks.

var part: ChPartRuntime = null  # the part this behaviour drives

# Subscribe to ctx.bus here, with self as the listener. Tasks 12-14 do the subscribing: a passive
# that listens for a nearby event, a weapon that listens for a status, both go through here.
# shortcut: the base subscribes nothing, so a behaviour that needs no listener stays a no-op.
func setup(ctx: ChBattleContext) -> void:
	pass

# Called once ChBattleContext.tick has paid this part's energy cost. The loop resets the cooldown
# and spends a charge right after this, so a behaviour cannot skip either.
# shortcut: the base does nothing, and a part with no behaviour is never asked in the first place.
func fire(ctx: ChBattleContext) -> void:
	pass


# Called every tick, fired or not: a timed behaviour counts its own seconds against ctx.time or the
# delta, which is the same delta every part, cooldown and energy pool in the fight gets.
func process(ctx: ChBattleContext, delta: float) -> void:
	pass


# Passives alter an outgoing hit here, before ChBattleContext applies any of it: the hit is the
# same Dictionary the entry point built, so a mutation travels (a Freeze Charge adds hit["freeze"],
# a Mace doubles hit["multiplier"]). The keys are source, target_part, target_chariot, damage,
# multiplier and freeze.
func modify_hit(ctx: ChBattleContext, hit: Dictionary) -> void:
	# shortcut: no key is required, and a behaviour that changes nothing answers by doing nothing.
	pass
