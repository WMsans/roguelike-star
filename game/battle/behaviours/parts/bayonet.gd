extends ChBehaviour

# The Bayonet (C10): when the weapon behind it fires, it pays its 1 energy and stabs for 20. Its own
# PART_FIRED is a weapon firing, so a second Bayonet in front of it chains; the bus's delivery cap is
# what bounds the chain.
const COST := 1

func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.PART_FIRED, func(event: ChEvent):
		if event.source != null and event.source == _back_part(ctx, "weapon"):
			_stab(ctx))

func _stab(ctx: ChBattleContext) -> void:
	if not ctx.pay_trigger(part, COST):
		return
	_hit_enemy_body(ctx, part.def.damage)
	# The loop's own emitter, so a Bayonet's shot reads exactly like any other part's.
	ctx._emit_fired(part)
