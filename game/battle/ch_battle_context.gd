class_name ChBattleContext extends RefCounted

# The one object a part's behaviour can touch: the world, the bus, the chariots by side and the
# catalog. The fight's two entry points live here too, so a behaviour never reaches a chariot, a
# part or ChDamage by itself:
# - deal_hit is the single damage entry point. It builds the hit dict, asks every same-side passive
#   whose def's proximity_range covers the source to change it, then the source's own behaviour,
#   then applies ChDamage (after the target's Block), gives hit["freeze"] stacks of Freeze to the
#   target part, emits HIT, and breaks the target part if its integrity reached 0.
# - tick runs one frame: hazards -> battery leaks -> the status clock (one _status_second per whole STATUS_SECOND)
#   -> per chariot: cooldowns -> energy.tick (regen, then the drive) -> on a press, the volley
#   (ready triggered parts paid dearest energy_cost first; each paid part fires, resets its
#   cooldown, spends a charge, emits PART_FIRED) -> behaviour.process -> drive. The drive cost is
#   paid inside energy.tick, before the volley, so drive() only ever runs for a drive that was
#   paid, which is the global "driving is paid first" rule and why drive() comes last.

const STATUS_SECOND := 1.0  # seconds between status seconds
const ACID_EATS: Array[StringName] = [&"sand", &"dirt", &"wood", &"coal", &"gunpowder", &"tnt", &"battery", &"steel"]  # what Acid dissolves

const STEAM_PUFF := 4  # steam particles when Flame and Wet cancel

var world: PixelWorld = null
var bus: ChEventBus = null
var chariots: Array[ChChariotRuntime] = []  # index = side
var catalog: ChCatalog = null
var time: float = 0.0  # the fight's clock, which a timed behaviour counts against
# This fight's modifier (ChFightRules). The default is the do-nothing rule, so a context that was never
# given one — every test and caller that predates modifiers — fights exactly as it did without one.
var rules: ChFightRules = ChFightRules.new()
var hazards := ChHazards.new()  # blast ownership lives here, so it is per fight
var sparks := ChSparks.new()  # the fight's batteries
var status_clock: float = 0.0  # time since the last status second
var _status_seconds := 0  # status seconds run so far; Oil drips on the even ones

func touching(holder: Object) -> Array:
	# The holder's own chariot's body and unbroken parts whose box, grown by 1 cell, meets the holder's.
	var out: Array = []
	var chariot: ChChariotRuntime = holder if holder is ChChariotRuntime else own(holder)
	if chariot == null:
		return out
	var box: Rect2 = holder.status_box()
	var all: Array = [chariot]
	all.append_array(chariot.parts)
	for other in all:
		if other == holder or (other is ChPartRuntime and other.broken):
			continue
		if other.status_box().grow(1.0).intersects(box):
			out.append(other)
	return out

func _status_event(type: StringName, holder: Object, data: Dictionary) -> void:
	var event := ChEvent.new()
	event.type = type
	event.side = holder.side
	event.source = holder
	event.position = holder.anchor_world()
	event.data = data
	bus.emit(event)

func give_status(target: Object, status: StringName, amount: int, hops := 1, from: Object = null) -> int:
	# Put stacks on a part or a chariot body; answers the stacks added. Shock then jumps half to what touches.
	if target == null or amount <= 0 or (target is ChPartRuntime and target.broken):
		return 0
	var before: int = target.statuses.count(status)
	var had: Dictionary = target.statuses.stacks.duplicate()
	var result: Dictionary = target.statuses.gain(status, amount)
	var added: int = result["added"]
	var puff := false
	for pair in result["cancelled"]:
		_status_event(ChEvent.STATUS_CANCELLED, target, {"status": status, "against": pair[0], "amount": pair[1]})
		puff = puff or (status == ChStatuses.FLAME and pair[0] == ChStatuses.WET) \
			or (status == ChStatuses.WET and pair[0] == ChStatuses.FLAME)
	if result["doubled"] > 0:
		_status_event(ChEvent.STATUS_DOUBLED, target, {"status": status, "amount": result["doubled"]})
	if added > 0:
		_status_event(ChEvent.STATUS_GAINED, target, {"status": status, "amount": added, "before": before})
	for s in ChStatuses.ALL:
		if had[s] > 0 and target.statuses.count(s) == 0:
			_status_event(ChEvent.STATUS_LOST, target, {"status": s})
	if puff and world != null:
		world.spawn_particles(&"steam", target.anchor_world(), Vector2.ZERO, STEAM_PUFF, 0.0)
	var half := added / 2
	if status == ChStatuses.SHOCK and half > 0 \
			and (hops > 0 or (hops == 0 and target.statuses.count(ChStatuses.WET) > 0)):
		for other in touching(target):
			if other == from:
				continue
			_status_event(ChEvent.SHOCK_JUMPED, other, {"from": target, "amount": half})
			give_status(other, ChStatuses.SHOCK, half, hops - 1, target)
	return added

func explode(source: ChPartRuntime, at: Vector2i, size: StringName, damage: int, dig := -1) -> void:
	# A part-made blast of a ChHazards size: digs, emits EXPLOSION, and hits the other side only.
	hazards.explode(self, source, at, size, damage, dig)

func own_charge(rect: Rect2i, side: int) -> void:
	# Explosive cells a part spawned: a blast that starts in them is that side's.
	hazards.own_charge(rect, side)

func _block_used(holder: Object, had: int) -> void:
	# Block only ever runs out by being used: a hit or Acid. Either way the holder loses it.
	if had > 0 and holder.statuses.count(ChStatuses.BLOCK) == 0:
		_status_event(ChEvent.STATUS_LOST, holder, {"status": ChStatuses.BLOCK})

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
	# The fire handicap (spec's "Fire damage reduced") starts the multiplier rather than rewriting the
	# damage, so a passive that stacks on the hit — the Mace's Shatter — multiplies it like any other hit,
	# and only the player's fire counts: the enemy's own fire is not handicapped.
	var multiplier := rules.fire_mult if _player_fire(source) else 1.0
	var hit := {
		"source": source,
		"target_part": target_part,
		# The part a freeze lands on and a Shatter reads. Weapons mostly strike the hull, so a hull hit
		# puts it on the target's part nearest the attacker.
		# ponytail: nearest the source's anchor, not the impact point, which deal_hit is never given.
		"freeze_part": target_part if target_part != null else _nearest_part(target_chariot, source.anchor_world()),
		"target_chariot": target_chariot,
		"damage": damage,
		"multiplier": multiplier,
		"freeze": 0,  # stacks of Freeze given to freeze_part
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
	# The Block that soaks the hit is the holder's: the part struck, or the body for a hull hit.
	var holder: Object = target_part if target_part != null else target_chariot
	var block: int = holder.statuses.count(ChStatuses.BLOCK)
	var result: Dictionary
	if target_part == null:
		result = ChDamage.hit_body(target_chariot.hp, hit["damage"], hit["multiplier"], block)
	else:
		result = ChDamage.hit_part(target_chariot.hp, target_part.integrity,
			hit["damage"], hit["multiplier"], 0.5, block)
		target_part.integrity = result["integrity"]
	var damage_out: int = target_chariot.hp - result["hp"]
	target_chariot.hp = result["hp"]
	holder.statuses.stacks[ChStatuses.BLOCK] = result["block"]
	_block_used(holder, block)
	# A modifier that asked for a thaw wins over the freeze: the Mace's Shatter ends the freeze it read
	# "after the hit" (spec §5.6), so a Freeze Charge landing on the same shatter leaves the target at 0.
	var freeze_part: ChPartRuntime = hit["freeze_part"]
	if freeze_part != null and hit.get("thaw", false):
		# Only the Shatter asks for a thaw, so feedback can break the ice rather than let it melt.
		if freeze_part.statuses.clear(ChStatuses.FREEZE) > 0:
			_status_event(ChEvent.STATUS_LOST, freeze_part, {"status": ChStatuses.FREEZE, "shatter": true})
	elif freeze_part != null and hit["freeze"] > 0:
		give_status(freeze_part, ChStatuses.FREEZE, hit["freeze"])
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


func _player_fire(source: ChPartRuntime) -> bool:
	# The hits the fire handicap reaches: the player's own, from a part the part data tags as fire — the
	# same tags the shop's themes roll on (Task 4), so "fire-tagged" is the shipped def's own word for it.
	return source.side == 0 and source.def != null and source.def.tags.has("fire")


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
	if world != null:
		hazards.apply(self, world.take_blasts())
		sparks.tick(self)
	status_clock += delta
	while status_clock >= STATUS_SECOND:
		status_clock -= STATUS_SECOND
		_status_second()
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
	# One frame of one side: cooldowns, the pool's tick, the volley if pressed, process, then the
	# drive. A broken part is skipped for the whole pass: it is off the bus and out of the joints,
	# so this pass must not fire it or re-process it. One flag, part.broken, closes both, and the
	# dead joint is never read here at all, which is what Review Focus 3 asks for.
	chariot.settle_mass()
	for part in chariot.parts:
		if part.broken:
			continue
		# A cooldown only counts down here; whether the part fires is the press's call.
		part.tick_cooldown(delta)
	var result: Dictionary = chariot.energy.tick(delta, direction != 0.0, _regen_mult(chariot))
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
	if result["drove"]:
		# The drive was paid, so the motors run: ChChariotRuntime.drive sets a wheel's motor off when
		# the wheel is broken or frozen, which is §5.7's "a wheel's motor locks".
		chariot.drive(direction)
	else:
		# The drive was not paid, so the input is ignored: drive(0.0) takes the motors off, which is
		# the same condition ChChariotRuntime.drive makes for a broken or frozen wheel.
		chariot.drive(0.0)
	return fired_count


func _regen_mult(chariot: ChChariotRuntime) -> float:
	# The body's statuses set the pool's regen: Freeze stops it, Speedup doubles it, Slow halves it.
	var s := chariot.statuses
	if s.count(ChStatuses.FREEZE) > 0:
		return 0.0
	if s.count(ChStatuses.SPEEDUP) > 0:
		return 2.0
	return 0.5 if s.count(ChStatuses.SLOW) > 0 else 1.0


func _status_second() -> void:
	# One status second over a snapshot of every living chariot's body and unbroken parts, in two
	# passes. A: damage, then cell effects, for every holder. B: gain from the cells touched, then
	# decay, for every holder, so both sides gain from cells both sides just changed. A material's
	# status never decays while it is being gained, and a holder that already held it gains 1 less:
	# a 1-stack-a-second material (ice, smoke) holds its status at 1 on every frame instead of
	# gaining and decaying it inside the same second.
	_status_seconds += 1
	if world != null:
		hazards.prune_charges(world)
		sparks.second(self)
	var holders: Array = []  # [chariot, holder] pairs
	for chariot in chariots:
		if chariot == null or chariot.hp <= 0:
			continue
		holders.append([chariot, chariot])
		for part in chariot.parts:
			if not part.broken:
				holders.append([chariot, part])
	var shock_seeds: Array[Vector2i] = []  # every shocked holder's, for one discharge after pass A
	for pair in holders:
		var holder: Object = pair[1]
		# A part that broke earlier in this second, or in its own damage below, is out of it.
		if holder is ChPartRuntime and holder.broken:
			continue
		_status_damage(pair[0], holder)
		if holder is ChPartRuntime and holder.broken:
			continue
		if world != null:
			_status_cells(holder, shock_seeds)
	if not shock_seeds.is_empty():
		# A spark that lights explosives through water and steel but shocks nobody, so two shocked
		# chariots in one puddle can't feed each other forever. One flood for all: lighting is idempotent.
		ChSparks.discharge(self, shock_seeds, false)
	for pair in holders:
		var holder: Object = pair[1]
		if holder is ChPartRuntime and holder.broken:
			continue
		var gains := {}
		if world != null:
			var rect: Rect2i = holder.sample_rect()
			gains = ChStatuses.material_gains(world.count_materials(rect), rect.size.x * rect.size.y)
		var held: Array = ChStatuses.ALL.filter(func(st: StringName): return holder.statuses.count(st) > 0)
		for status in ChStatuses.ALL:
			if gains.has(status):
				give_status(holder, status, gains[status] - (1 if status in held else 0))
		for status in holder.statuses.decay(gains.keys()):
			_status_event(ChEvent.STATUS_LOST, holder, {"status": status})


func _status_damage(chariot: ChChariotRuntime, holder: Object) -> void:
	# Flame (scaled by the fire handicap on side 1), Acid past Block, and Shock: integrity on a
	# part, HP on the body, never both. Flame and Shock go straight past Block.
	var s: ChStatuses = holder.statuses
	var acid := s.count(ChStatuses.ACID)
	var flame_mult := rules.fire_mult if holder.side == 1 else 1.0
	var block := s.count(ChStatuses.BLOCK)
	var damage := roundi(s.count(ChStatuses.FLAME) * flame_mult) + acid - s.absorb(acid) \
		+ s.count(ChStatuses.SHOCK)
	_block_used(holder, block)
	if damage <= 0:
		return
	if holder is ChPartRuntime:
		holder.integrity = maxi(0, holder.integrity - damage)
		if holder.integrity <= 0:
			chariot.break_part(holder, self)
	else:
		chariot.hp = maxi(0, chariot.hp - damage)


func _status_cells(holder: Object, shock_seeds: Array[Vector2i]) -> void:
	# What a holder's statuses do to the cells it touches, once a status second. Shock only adds the
	# conductors and explosives it touches to shock_seeds; _status_second discharges them once.
	var s: ChStatuses = holder.statuses
	var rect: Rect2i = holder.sample_rect()
	if s.count(ChStatuses.SHOCK) > 0:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var m := world.get_material_at(Vector2i(x, y))
				if m in ChSparks.CONDUCTORS or m in ChSparks.EXPLOSIVES:
					shock_seeds.append(Vector2i(x, y))
	if s.count(ChStatuses.FLAME) > 0:
		# One fire particle; the sim's own fire rules do the igniting.
		world.spawn_particles(&"fire", holder.anchor_world(), Vector2.ZERO, 1, 0.0)
	if s.count(ChStatuses.FREEZE) > 0:
		_swap_cells(rect, [&"water"], &"ice", 4)
	if s.count(ChStatuses.ACID) > 0:
		_swap_cells(rect, ACID_EATS, &"air", 1)
	if s.count(ChStatuses.OIL) > 0 and _status_seconds % 2 == 0:
		# One drip into the first air cell of the row under the holder's box.
		var box: Rect2 = holder.status_box()
		var left := floori(box.position.x)
		_swap_cells(Rect2i(left, ceili(box.end.y), ceili(box.end.x) - left, 1), [&"air"], &"oil", 1)


func _swap_cells(rect: Rect2i, from: Array, to: StringName, most: int) -> void:
	# Up to `most` cells of `from` become `to`, row-major from the rect's top-left.
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if most <= 0:
				return
			var at := Vector2i(x, y)
			if world.get_material_at(at) in from:
				world.set_cell(at, to)
				most -= 1
