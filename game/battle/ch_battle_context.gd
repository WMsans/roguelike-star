class_name ChBattleContext extends RefCounted

# The one object a part's behaviour can touch: the world, the bus, the chariots by side and the
# catalog. The fight's two entry points live here too, so a behaviour never reaches a chariot, a
# part or ChDamage by itself:
# - deal_hit is the single damage entry point. It builds the hit dict, asks every same-side passive
#   whose def's proximity_range covers the source to change it, then the source's own behaviour,
#   then applies ChDamage, adds hit["freeze"] onto the target part, emits HIT, and breaks the target
#   part if its integrity reached 0.
# - tick runs one frame for every chariot: sample -> apply_sample -> cooldowns -> energy.tick
#   (regen, then the drive) -> on a press, the volley (ready triggered parts paid dearest energy_cost
#   first; each paid part fires, resets its cooldown, spends a charge, emits PART_FIRED) ->
#   behaviour.process -> burn damage -> drive. The drive cost is paid inside energy.tick, before the
#   volley, so drive() only ever runs for a drive that was paid, which is the global "driving is
#   paid first" rule and why drive() comes last.

var world: PixelWorld = null
var bus: ChEventBus = null
var chariots: Array[ChChariotRuntime] = []  # index = side
var catalog: ChCatalog = null
var time: float = 0.0  # the fight's clock, which a timed behaviour counts against

func own(part: ChPartRuntime) -> ChChariotRuntime:
	# index = side is this array's own contract, so a part knows its chariot by its own side.
	# shortcut: an out-of-range side answers null; a fight that lost a chariot is loud at the build.
	if part.side < 0 or part.side >= chariots.size():
		return null
	return chariots[part.side]

func enemy_of(part: ChPartRuntime) -> ChChariotRuntime:
	# The other side's chariot. The slice fights one player and one enemy, so "the one whose side
	# differs" is the whole answer.
	# shortcut: more than two sides would want a side index, which the arena never gives.
	for other in chariots:
		if other != null and other.side != part.side:
			return other
	return null

func part_of_body(body: Object) -> ChPartRuntime:
	for chariot in chariots:
		if chariot == null:
			continue
		for part in chariot.parts:
			# A part's body is the PixelRigidBody the builder mounted, so identity is the key.
			# A broken part is out of the fight, so its body reads as nobody's: break_part leaves the
			# joint gone but the body still on the ground, so this skip is what makes a later hit on
			# that wreck resolve null instead of wearing the part again.
			if part.broken:
				continue
			if part.body == body:
				return part
	return null

func chariot_of_body(body: Object) -> ChChariotRuntime:
	# The chariot that owns a body: the chassis or one of its parts. null when nothing owns it,
	# which is what a body that fell off a broken chariot resolves to, and what a hit on it drops.
	# shortcut: the same scan as part_of_body, once more per hit, for the same reason.
	for chariot in chariots:
		if chariot == null:
			continue
		# A chassis carries the whole chariot, so it resolves before the parts of that chariot do.
		if chariot.chassis == body:
			# The sentinel part_of_body answers for the same body, so a chassis hit wears no part.
			return chariot
		for part in chariot.parts:
			# The same identity key part_of_body reads, so the two scans cannot disagree about a body.
			# The same part.broken skip: a fallen wreck resolves through no chariot at all, which is
			# the condition deal_hit drops the hit on, so a wreck can never pay chariot HP again.
			if part.broken:
				continue
			if part.body == body:
				return chariot
	# A body nothing owns is out of the fight: a body that fell off a broken part is still a body,
	# but no part in the list holds it, so a later hit on it resolves null and deal_hit drops it.
	# shortcut: dropped rather than logged; a fight that wants to see a miss wants an event here.
	return null

func deal_hit(source: ChPartRuntime, target_body: Object, damage: int, extra := {}) -> void:
	# The single damage entry point: every weapon calls this rather than ChDamage itself, so the
	# passives near the source get their turn on the hit before any of it is applied.
	if source == null:
		# No source means no side, no behaviour to ask and nothing measured: the hit is dropped.
		# shortcut: dropped rather than logged; a fight that wants a miss on screen wants an event.
		return
	var target_part: ChPartRuntime = part_of_body(target_body)
	var target_chariot: ChChariotRuntime = chariot_of_body(target_body)
	if target_chariot == null:
		# A body no chariot owns is out of the fight, so there is no HP to pay. See above for why.
		return
	# The hit dict is the object every modifier is handed, so a mutation travels and the six keys
	# below are the shape a behaviour reads. damage stays the raw damage: a multiplier never rewrites
	# it, so a passive that reads a hit never has to undo another passive's work.
	var hit := {
		"source": source,
		"target_part": target_part,
		# The part a freeze lands on and a Shatter reads. Weapons mostly strike the hull, which carries
		# no meter, so a hull hit puts it on the target's part nearest the attacker.
		# ponytail: nearest the source's anchor, not the impact point, which deal_hit is never given.
		"freeze_part": target_part if target_part != null else _nearest_part(target_chariot, source.anchor_world()),
		"target_chariot": target_chariot,
		"damage": damage,
		"multiplier": 1.0,
		"freeze": 0.0,
	}
	# `extra` seeds those keys, which is how a caller carries an effect it has no behaviour for.
	# shortcut: extra never needs to name a key, so a caller that wants the defaults passes {}.
	for key in extra:
		hit[key] = extra[key]
	for other_chariot in chariots:
		if other_chariot == null or other_chariot.side != source.side:
			continue
		for other in other_chariot.parts:
			# The source's own behaviour is asked once below, whatever its range, so the source is
			# skipped here: a weapon whose def also carries a proximity_range would else be asked
			# twice for its own hit, doubling its own effect.
			if other == source or other.broken or other.def == null:
				# A broken passive is out of the fight, so its effect stops. break_part took the same
				# part out of the energy queue and off the bus: this is the third place a part could
				# still act from, and the same one flag (part.broken) closes all three.
				continue
			var reach: float = other.def.proximity_range
			# 0 means no proximity effect at all, per ChPartDef's own comment, so a weapon with a
			# reach of 0 is never asked, and cells here match cells in count_materials.
			if reach > 0.0 and other.anchor_world().distance_to(source.anchor_world()) <= reach:
				_ask_behaviour(other, hit)
	# The source's own behaviour gets the last word on its own hit: a weapon reads the target off
	# the dict rather than measuring, which is how the Mace's Shatter reads a frozen part.
	_ask_behaviour(source, hit)
	# The modifiers had their turn, so ChDamage applies what they left. A part hit wears the part
	# as well as the chariot, and the multiplier never reaches the wear: that rule is ChDamage's,
	# pinned by its own tests, so nothing here restates it.
	var damage_out := 0
	if target_part == null:
		# No part to wear, so HP takes the hit on its own. ChDamage's return is an int, which is
		# what hp is, so it feeds the field directly. The burn rule below is the only damage that
		# arrives as a float, and it does not go through here.
		var body_hp := ChDamage.hit_body(target_chariot.hp, hit["damage"], hit["multiplier"])
		damage_out = target_chariot.hp - body_hp
		target_chariot.hp = body_hp
	else:
		var part_result: Dictionary = ChDamage.hit_part(target_chariot.hp, target_part.integrity,
			hit["damage"], hit["multiplier"])
		damage_out = target_chariot.hp - part_result["hp"]
		target_chariot.hp = part_result["hp"]
		target_part.integrity = part_result["integrity"]
	# A passive's freeze reaches hit["freeze_part"], capped where ChPartRuntime caps its own
	# freeze build, so one full meter of freeze is one frozen part whatever the number of passives.
	# A modifier that asked for a thaw answers after that: the Mace's Shatter ends the freeze it read
	# "after the hit" (spec §5.6), so a Freeze Charge landing on the same shatter leaves the target at
	# 0 rather than the freeze it added.
	var freeze_part: ChPartRuntime = hit["freeze_part"]
	if freeze_part != null and hit.get("thaw", false):
		freeze_part.freeze = 0.0
		# The Shatter announced its own THAWED, so the hold goes too and the next sample stays quiet.
		freeze_part.frozen_held = false
	elif freeze_part != null and hit["freeze"] > 0.0:
		freeze_part.freeze = clampf(freeze_part.freeze + hit["freeze"], 0.0, 1.0)
	# HIT announces the hit after it landed, so a listener reads the HP already paid. The source is
	# the part that dealt it, which is what a proximity listener measures, and the payload carries
	# what was hit and how much HP went: hp_damage is the damage dealt, not the HP actually lost.
	var event := ChEvent.new()
	event.type = ChEvent.HIT
	event.side = source.side
	event.source = source
	event.position = source.anchor_world()
	event.data = {"target_part": target_part, "hp_damage": damage_out, "target_side": target_chariot.side}
	bus.emit(event)
	if target_part != null and target_part.integrity <= 0:
		target_chariot.break_part(target_part, self)

func _nearest_part(chariot: ChChariotRuntime, from: Vector2) -> ChPartRuntime:
	var best: ChPartRuntime = null
	for part in chariot.parts:
		if part.broken:
			continue
		if best == null or part.anchor_world().distance_to(from) < best.anchor_world().distance_to(from):
			best = part
	return best

func _ask_behaviour(part: ChPartRuntime, hit: Dictionary) -> void:
	var behaviour = part.behaviour
	if behaviour != null:
		behaviour.modify_hit(self, hit)

func _emit_fired(part: ChPartRuntime) -> void:
	# PART_FIRED announces that a part went off. The source names it, so the payload stays empty,
	# which is what ChPartRuntime._emit does for the three status events it owns.
	# shortcut: a HUD that wants the cost or the charges wants them in data here.
	var event := ChEvent.new()
	event.type = ChEvent.PART_FIRED
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	bus.emit(event)

func volley_cost(chariot: ChChariotRuntime) -> int:
	# What a press would cost if every ready part could pay: the HUD's and the enemy's read.
	var total := 0
	for part in chariot.parts:
		if part.is_ready():
			total += part.def.energy_cost
	return total

func tick(delta: float, drive_input: Array[float], press_input: Array = []) -> Array[int]:
	# One frame of the fight for every chariot, in the order this file's header states. Answers the
	# number of parts each side fired this frame, indexed by side.
	time += delta
	var fired: Array[int] = []
	for at in chariots.size():
		# Indexed by side, so a drive_input entry belongs to the chariot at the same index.
		# shortcut: a side with no entry reads 0.0 / not pressed, rather than raising.
		var chariot: ChChariotRuntime = chariots[at]
		if chariot == null:
			fired.append(0)
			continue
		var direction: float = drive_input[at] if at < drive_input.size() else 0.0
		var pressed: bool = bool(press_input[at]) if at < press_input.size() else false
		fired.append(_tick_chariot(chariot, delta, direction, pressed))
	return fired

func _tick_chariot(chariot: ChChariotRuntime, delta: float, direction: float, pressed: bool) -> int:
	# One frame of one side: sample, cooldowns, the pool's tick, the volley if pressed, process,
	# the burn, then the drive. A broken part is skipped for the whole pass: it is off the bus and
	# out of the joints, so this pass must not fire it, re-process it or count its burning as
	# damage. One flag, part.broken, closes all three, and the dead joint is never read here at
	# all, which is what Review Focus 3 asks for.
	chariot.settle_mass()
	for part in chariot.parts:
		if part.broken:
			continue
		if world != null:
			part.apply_sample(world.count_materials(part.sample_rect()), delta, bus)
		else:
			part.apply_sample({}, delta, bus)
		# A cooldown only counts down here; whether the part fires is the press's call.
		part.tick_cooldown(delta)
	var result: Dictionary = chariot.energy.tick(delta, direction != 0.0)
	var fired_count := 0
	if pressed:
		# The volley: ready triggered parts, dearest first so the big weapons get the energy before
		# the small ones can eat it. A part that does not fit is skipped and a cheaper one after it
		# can still pay; the skipped part stays ready and nothing is remembered to the next press.
		var volley: Array[ChPartRuntime] = []
		for part in chariot.parts:
			if part.is_ready():
				volley.append(part)
		# sort_custom is not stable, so ties break on mount order (index in chariot.parts) here.
		var order: Dictionary = {}
		for at in chariot.parts.size():
			order[chariot.parts[at]] = at
		volley.sort_custom(func(a: ChPartRuntime, b: ChPartRuntime) -> bool:
			if a.def.energy_cost != b.def.energy_cost:
				return a.def.energy_cost > b.def.energy_cost
			return order[a] < order[b])
		for part in volley:
			# A fire earlier in this volley can break or freeze a part that was ready when the press
			# began, so readiness is read again before paying.
			if not part.is_ready():
				continue
			if not chariot.energy.try_pay(part.def.energy_cost):
				continue
			var behaviour = part.behaviour
			if behaviour != null:
				behaviour.fire(self)
			# The cooldown and the charge belong to the loop, not to the behaviour, so a part cannot
			# fire twice on one payment: its countdown restarts here and is_ready is false again.
			part.cooldown_left = part.def.cooldown
			if part.charges_left > 0:
				# charges_left -1 is unlimited, so an unlimited part never enters this branch. A
				# limited part stops at 0, where is_ready turns false, rather than stepping into
				# the sentinel.
				part.charges_left -= 1
			_emit_fired(part)
			fired_count += 1
	for part in chariot.parts:
		if part.broken:
			continue
		var passive = part.behaviour
		if passive != null:
			passive.process(self, delta)
	var burning_count := 0
	for part in chariot.parts:
		# A broken part burns nothing: it is no longer in the fight, so a wreck sets no chariot on
		# fire. Nothing here asserts that rule; a fight that wants it asserts it there.
		if not part.broken and part.burning:
			burning_count += 1
	# Burning is chariot-wide: ChDamage.burn_tick applies one dps * delta tick for the chariot when
	# any part burns, so three burning parts burn no harder than one. Its return is a float and hp is
	# an int per the plan, so what a tick leaves behind waits in burn_damage_left until it adds up to
	var burned: float = ChDamage.burn_tick(chariot.hp, burning_count, delta)
	var owed: float = float(chariot.hp) - burned
	chariot.burn_damage_left += owed
	var points := int(chariot.burn_damage_left)
	chariot.burn_damage_left -= float(points)
	chariot.hp = maxi(0, chariot.hp - points)
	if result["drove"]:
		# The drive was paid, so the motors run: ChChariotRuntime.drive sets a wheel's motor off when
		# the wheel is broken or frozen, which is §5.7's "a wheel's motor locks".
		chariot.drive(direction)
	else:
		# The drive was not paid, so the input is ignored: drive(0.0) takes the motors off, which is
		# the same condition ChChariotRuntime.drive makes for a broken or frozen wheel.
		chariot.drive(0.0)
	return fired_count

