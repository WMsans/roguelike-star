class_name ChHazards extends RefCounted

# Blasts: their sizes, who owns them, and what they do to the chariots near them. The engine queues
# every blast; the fight drains the queue each tick and hands it to apply. A script blast (Rocket,
# Firebolt, or ctx.explode's own world.explode) has material &"" and is skipped there: those deal
# their damage through deal_hit. An instance, because ownership (charges and recent discs) is state.

# HP at the centre, linear to 0 at the radius. One 6x6 TNT crate goes off as about 3 blasts on
# consecutive ticks, so a chariot over it pays about 900 HP in all.
const SIZES := {
	&"small": {radius = 5, dig = 2, damage = 6, power = 150.0},
	&"medium": {radius = 8, dig = 4, damage = 60, power = 250.0},
	&"large": {radius = 12, dig = 6, damage = 300, power = 400.0},
}
const MATERIAL_SIZE := {&"gunpowder": &"small", &"flammable_gas": &"medium", &"tnt": &"large"}
const BLAST_WEAR := 0.5  # share of the HP damage each part inside the radius loses as integrity
const BLAST_IMPULSE := 60.0  # per unit of power at the centre, same falloff
const CHARGE_MARGIN := 4  # cells around an owned charge that still count as it
const CHAIN_WINDOW := 0.5  # seconds an owned blast's disc hands its owner to the blasts it sets off
const EXPLOSIVES: Array[StringName] = [&"gunpowder", &"tnt", &"flammable_gas"]

var _charges: Array = []  # {rect, side}, in record order
var _discs: Array = []  # {centre, radius, side, time}, in record order


func own_charge(rect: Rect2i, side: int) -> void:
	_charges.append({"rect": rect, "side": side})


func prune_charges(world: PixelWorld) -> void:
	# A charge with nothing explosive left near it has gone off or been eaten: it owns nothing more.
	_charges = _charges.filter(func(charge: Dictionary) -> bool:
		var counts: Dictionary = world.count_materials(charge.rect.grow(CHARGE_MARGIN))
		return EXPLOSIVES.any(func(m: StringName) -> bool: return counts.get(m, 0) > 0))


func explode(ctx: ChBattleContext, source: ChPartRuntime, at: Vector2i, size: StringName, damage: int,
		dig := -1) -> void:
	# A part-made blast: dig the world, announce it, own it, then hurt the other side through deal_hit.
	var s: Dictionary = SIZES[size]
	var digs: int = dig if dig >= 0 else s.dig
	if ctx.world != null:
		ctx.world.explode(at, s.radius, s.power, digs)
	_emit(ctx, source.side, at, size, s.radius, digs, &"", source)
	_record(ctx, Vector2(at), s.radius, source.side)
	for chariot in ctx.chariots:
		if chariot == null or chariot.side == source.side:
			continue
		var falloff := _push(chariot, Vector2(at), s.radius, s.power)
		var dealt := roundi(damage * falloff)
		if dealt > 0:
			ctx.deal_hit(source, chariot.chassis, dealt)


func apply(ctx: ChBattleContext, blasts: Array) -> void:
	_discs = _discs.filter(func(disc: Dictionary) -> bool: return ctx.time - disc.time <= CHAIN_WINDOW)
	for blast in blasts:
		var size: StringName = MATERIAL_SIZE.get(blast.material, &"")
		if size == &"":
			continue
		var radius: int = blast.radius
		var centre := Vector2(blast.position)
		var owner := _owner(ctx, centre)
		if owner >= 0:
			_record(ctx, centre, radius, owner)
		_emit(ctx, owner, blast.position, size, radius, blast.dig, blast.material, null)
		if radius <= 0:
			continue
		var base: int = SIZES[size].damage
		for chariot in ctx.chariots:
			var falloff := _push(chariot, centre, radius, blast.power)
			var damage := roundi(base * falloff)
			if damage <= 0:  # outside, or the rim of a weak blast rounds to 0: no HP, wear or event
				continue
			# The hull's HP goes through the body's Block, as deal_hit's hull hit does.
			var block: int = chariot.statuses.count(ChStatuses.BLOCK)
			var result := ChDamage.hit_body(chariot.hp, damage, 1.0, block)
			chariot.hp = result.hp
			chariot.statuses.stacks[ChStatuses.BLOCK] = result.block
			ctx._block_used(chariot, block)
			# The body's Block shields the hull, not the parts, so they wear by the blast's damage.
			var wear := roundi(damage * BLAST_WEAR)
			for part in chariot.parts:
				if part.broken or part.anchor_world().distance_to(centre) > radius:
					continue
				part.integrity = maxi(0, part.integrity - wear)
				if part.integrity <= 0:
					chariot.break_part(part, ctx)
			var event := ChEvent.new()
			event.type = ChEvent.HAZARD_HIT
			event.side = chariot.side
			event.position = centre
			event.data = {"target_side": chariot.side, "hp_damage": result.hp_damage,
				"material": blast.material, "hp_after": chariot.hp}
			ctx.bus.emit(event)


static func _push(chariot: ChChariotRuntime, centre: Vector2, radius: int, power: float) -> float:
	# Pushes a living chariot whose hull is within the radius away from the centre and answers the
	# falloff (1 at the hull, 0 at the radius). Anything else is left alone and answers 0.
	if chariot == null or chariot.chassis == null or not is_instance_valid(chariot.chassis) \
			or chariot.is_dead() or radius <= 0:
		return 0.0
	var box := ChBattle.hull_box(chariot)
	var d := centre.distance_to(centre.clamp(box.position, box.end))
	if d > radius:
		return 0.0
	var falloff := 1.0 - d / radius
	var dir := (chariot.chassis.global_position - centre).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	chariot.chassis.apply_impulse(dir * power * BLAST_IMPULSE * falloff)
	return falloff


func _owner(ctx: ChBattleContext, centre: Vector2) -> int:
	# First charge that holds it, else the earliest recent owned disc that holds it, else nobody.
	for charge in _charges:
		if Rect2(charge.rect.grow(CHARGE_MARGIN)).has_point(centre):
			return charge.side
	for disc in _discs:
		if ctx.time - disc.time <= CHAIN_WINDOW and disc.centre.distance_to(centre) <= disc.radius:
			return disc.side
	return -1


func _record(ctx: ChBattleContext, centre: Vector2, radius: int, side: int) -> void:
	_discs.append({"centre": centre, "radius": radius, "side": side, "time": ctx.time})


static func _emit(ctx: ChBattleContext, owner: int, at: Vector2i, size: StringName, radius: int, dig: int,
		material: StringName, source: ChPartRuntime) -> void:
	var event := ChEvent.new()
	event.type = ChEvent.EXPLOSION
	event.side = owner
	event.source = source
	event.position = Vector2(at)
	event.data = {"size": size, "radius": radius, "dig": dig, "owner": owner, "material": material,
		"source": source}
	ctx.bus.emit(event)
