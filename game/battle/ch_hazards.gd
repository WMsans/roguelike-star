class_name ChHazards extends RefCounted

# Material blasts (TNT, gunpowder) hurt and push the chariots near them. The engine queues every
# blast; the fight drains the queue each tick and hands it here. A script blast (Rocket, Firebolt)
# has material &"" and is ignored: those already deal their damage through deal_hit.

const BLAST_DAMAGE := {&"tnt": 150, &"gunpowder": 6}  # HP at the centre, linear to 0 at the radius
const BLAST_WEAR := 0.5  # share of the HP damage each part inside the radius loses as integrity
const BLAST_IMPULSE := 60.0  # per unit of power at the centre, same falloff


static func apply(ctx: ChBattleContext, blasts: Array) -> void:
	for blast in blasts:
		var radius: int = blast.radius
		var base: int = BLAST_DAMAGE.get(blast.material, 0)
		if blast.material == &"" or radius <= 0 or base <= 0:
			continue
		var centre := Vector2(blast.position)
		for chariot in ctx.chariots:
			if chariot == null or chariot.chassis == null or not is_instance_valid(chariot.chassis) \
					or chariot.is_dead():
				continue
			var box := ChBattle.hull_box(chariot)
			var d := centre.distance_to(centre.clamp(box.position, box.end))
			if d > radius:
				continue
			var falloff := 1.0 - d / radius
			var damage := roundi(base * falloff)
			chariot.hp = maxi(0, chariot.hp - damage)
			var wear := roundi(damage * BLAST_WEAR)
			for part in chariot.parts:
				if part.broken or part.anchor_world().distance_to(centre) > radius:
					continue
				part.integrity = maxi(0, part.integrity - wear)
				if part.integrity <= 0:
					chariot.break_part(part, ctx)
			var dir := (chariot.chassis.global_position - centre).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			chariot.chassis.apply_impulse(dir * blast.power * BLAST_IMPULSE * falloff)
			var event := ChEvent.new()
			event.type = ChEvent.HAZARD_HIT
			event.side = chariot.side
			event.position = centre
			event.data = {"target_side": chariot.side, "hp_damage": damage,
				"material": blast.material, "hp_after": chariot.hp}
			ctx.bus.emit(event)
