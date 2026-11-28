class_name ChBattleContext extends RefCounted

# The one object a part's behaviour can touch: the world, the bus, the chariots by side and the
# catalog. The fight's two entry points live here too, so a behaviour never reaches a chariot, a
# part or ChDamage by itself:
# - deal_hit is the single damage entry point. It builds the hit dict, asks every same-side passive
#   whose def's proximity_range covers the source to change it, then the source's own behaviour,
#   then applies ChDamage (after the target's Block), emits HIT, and breaks the target part if its
#   integrity reached 0.
# - tick runs one frame: hazards -> battery leaks -> the status clock (one _status_second per whole STATUS_SECOND)
#   -> per chariot: cooldowns -> energy.tick (regen, then the drive) -> on a press, the volley
#   (ready triggered parts paid by volley_priority, then dearest energy_cost, then mount order; each
#   paid part fires, resets its cooldown, spends a charge, emits PART_FIRED; a part the pool refuses
#   emits PART_SKIPPED unless blood_pay lets it pay the shortfall in HP instead)
#   -> the held button's continuous step (every part that can run, paid energy_per_second * delta
#   dearest first, ticks one a second of running) -> behaviour.process -> drive. Before any of that,
#   the fight's own checks run on its clock: a new hull contact at RAM_SPEED emits RAMMED, and a
#   chariot touching down after LANDED_AFTER seconds in the air emits LANDED. The drive cost is
#   paid inside energy.tick, before the volley and the hold, so drive() only ever runs for a drive
#   that was paid, which is the global "driving is paid first" rule and why drive() comes last.

const STATUS_SECOND := 1.0  # seconds between status seconds
const ACID_EATS: Array[StringName] = [&"sand", &"dirt", &"wood", &"coal", &"gunpowder", &"tnt", &"battery", &"steel"]  # what Acid dissolves

const STEAM_PUFF := 4  # steam particles when Flame and Wet cancel
const RAM_SPEED := 20.0  # cells/s toward the other hull that a touching contact needs to count as a ram
const LANDED_AFTER := 0.2  # seconds airborne before touching down again counts as a landing
const BLOOD_PER_ENERGY := 10  # HP a refused part's shortfall costs per energy when blood_pay is on (R28)

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
# Fuses a part lit (Dynamite Toss): {part, at, left, size, damage, dig}. The list belongs to the fight
# rather than the part, so a thrower broken mid-fuse still explodes (Review Focus 3).
var fuses: Array = []
var status_clock: float = 0.0  # time since the last status second
var _status_seconds := 0  # status seconds run so far; Oil drips on the even ones
var _battle_started: bool = false  # BATTLE_STARTED emitted once by the first tick
# The ctx.time value force_fire last forced each part at: the fight's marker, so "once per tick" holds
# across every part that forces (R15: two gearboxes in range of one weapon force it once).
var _forced_at := {}  # part -> ctx.time
var _modifiers: Array = []  # behaviours whose own script declares modify_stat or modify_gain, in side/mount order
# The hulls' boxes are touching, so this contact has already been counted: a contact ends when they
# stop overlapping, and the next overlap is a new one whether or not anybody moved in between.
var _ram_contact: bool = false
# Seconds each side has been airborne, and whether it was on the last tick: an airborne -> grounded
# transition that lasted LANDED_AFTER or more is a landing.
var _airborne_for: Array[float] = []
var _was_airborne: Array[bool] = []

# Stat names ChBattleContext.stat asks about: a behaviour's modify_stat is handed one of these.
const STAT_ENERGY_COST := &"energy_cost"
const STAT_ENERGY_PER_SECOND := &"energy_per_second"
const STAT_COOLDOWN := &"cooldown"
const STAT_TICK_RATE := &"tick_rate"
const STAT_RANGE := &"range"
const STAT_FLAME_DAMAGE := &"flame_damage"
const STAT_ACID_DAMAGE := &"acid_damage"
const STAT_SHOCK_DAMAGE := &"shock_damage"
const STAT_DECAY_FREEZE := &"decay_freeze"
const STAT_DECAY_FLAME := &"decay_flame"
const STAT_SHOCK_HOPS := &"shock_hops"  # how many times a Shock gain jumps on (R07)
const STAT_ACID_TO_HP := &"acid_to_hp"  # 1 pays Acid on a part to its chariot's HP too (R10)
const STAT_BLAST_SIZE := &"blast_size"  # steps a blast's size up: small -> medium -> large (R22)
const STAT_OWN_BLAST_TAKEN := &"own_blast_taken"  # share of a blast the side itself laid that lands (R22)
const STAT_ENV_BLAST_TAKEN := &"env_blast_taken"  # share of an unowned terrain blast that lands (R22)
const STAT_VOLLEY_PRIORITY := &"volley_priority"  # the volley's first sort key, descending (U60)
const STAT_BLOOD_PAY := &"blood_pay"  # 1 lets a refused part pay its shortfall in HP (R28)

# The decay stat name for a status; STAT_DECAY_FREEZE is one of these. The rest are built rather than
# spelled out, because the decaying statuses are ChStatuses.DECAYS and grow with it.
static func decay_stat(status: StringName) -> StringName:
	return StringName("decay_" + status)

# Folds `base` through the modify_stat of every unbroken part on both chariots, side order then
# mount order. setup_all read once which behaviours declare a hook; only those are asked.
func stat(target: Object, stat: StringName, base: float) -> float:
	var value := base
	for behaviour in _modifiers:
		var part: ChPartRuntime = behaviour.part
		if part == null or part.broken:
			continue
		value = behaviour.modify_stat(self, target, stat, value)
	return value

# Calls every part's setup and caches the behaviours whose own script declares a hook: the one place
# behaviours subscribe (Mimic and the bench hook in later tasks), and the hooks' list.
func setup_all() -> void:
	_modifiers.clear()
	if bus != null:
		bus.near = Callable(self, "near")
	for chariot in chariots:
		if chariot == null:
			continue
		for part in chariot.parts:
			var behaviour := part.behaviour
			if behaviour == null:
				continue
			if _declares_modifier(behaviour):
				_modifiers.append(behaviour)
			behaviour.setup(self)
	# Side order, then mount order: a parent before its children, siblings in slot order.
	_modifiers.sort_custom(func(a, b) -> bool:
		var pa: ChPartRuntime = a.part
		var pb: ChPartRuntime = b.part
		if pa.side != pb.side:
			return pa.side < pb.side
		return _path_before(pa.path, pb.path))

# Lexicographic slot-path order, which is the order the layout was placed in.
func _path_before(a: Array[int], b: Array[int]) -> bool:
	var n := mini(a.size(), b.size())
	for i in range(n):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()

# True when the behaviour's own script declares one of the hooks the context folds.
func _declares_modifier(behaviour: Object) -> bool:
	var script: Script = behaviour.get_script()
	if script == null:
		return false
	for method in script.get_script_method_list():
		if method["name"] == "modify_stat" or method["name"] == "modify_gain":
			return true
	return false

# Proximity range of a part, through the stat hook.
func range_of(part: ChPartRuntime) -> float:
	if part == null or part.def == null:
		return 0.0
	return stat(part, STAT_RANGE, part.def.proximity_range)

# True when a and b are on the same side, unbroken, and either within range_of(a) or linked by a
# live behaviour's links(a, b).
func near(a: Object, b: Object) -> bool:
	if a == null or b == null or a == b:
		return false
	var sa: Variant = a.get("side")
	var sb: Variant = b.get("side")
	if sa == null or sb == null or sa != sb:
		return false
	if a is ChPartRuntime and a.broken:
		return false
	if b is ChPartRuntime and b.broken:
		return false
	var ra := range_of(a) if a is ChPartRuntime else 0.0
	if a.anchor_world().distance_to(b.anchor_world()) <= ra:
		return true
	var side := int(sa)
	var chariot := chariots[side] if side >= 0 and side < chariots.size() else null
	if chariot != null:
		for p in chariot.parts:
			if p.broken or p.behaviour == null:
				continue
			if p.behaviour.has_method("links") and p.behaviour.links(self, a, b):
				return true
	return false

# Pays a triggered passive's modified cost, or answers false. Spec Stage 3.
func pay_trigger(part: ChPartRuntime, cost: int) -> bool:
	var price := stat(part, STAT_ENERGY_COST, cost)
	var chariot := chariots[part.side] if part.side >= 0 and part.side < chariots.size() else null
	if chariot == null:
		return false
	return chariot.energy.try_pay(price)

func _emit(type: StringName, holder: Object, data: Dictionary) -> void:
	var event := ChEvent.new()
	event.type = type
	event.side = holder.side
	event.source = holder
	event.position = holder.anchor_world()
	event.data = data
	bus.emit(event)


# The one HP-loss path: every hit, blast and status that costs a chariot HP comes through here, so a
# listener (and the pop-up layer) sees one event per loss. Answers the HP actually lost, which is
# less than `amount` on a finishing blow.
func lose_hp(chariot: ChChariotRuntime, amount: int, cause: StringName, source: Object = null) -> int:
	if chariot == null or amount <= 0:
		return 0
	var before := chariot.hp
	# A blow that would end a living chariot asks the would-die hook first. A chariot already at 0 is
	# not asked again: it is dead, not about to die, so a later hit cannot revive it.
	if before > 0 and before - amount <= 0 and _prevent_death(chariot):
		chariot.hp = 1
	else:
		chariot.hp = maxi(0, chariot.hp - amount)
	var lost := before - chariot.hp
	if lost > 0:
		# The one event whose source is not the holder: the attacker where there is one, null for a
		# blast or a status, with the event's side naming the chariot that paid.
		var event := ChEvent.new()
		event.type = ChEvent.HP_LOST
		event.side = chariot.side
		event.source = source
		event.position = chariot.anchor_world()
		event.data = {"amount": lost, "before": before, "after": chariot.hp, "cause": cause}
		bus.emit(event)
	return lost


# The would-die walk: every unbroken part of the losing chariot in mount order, until one answers
# true. A part with no behaviour is never asked, the same rule deal_hit's hooks follow.
func _prevent_death(chariot: ChChariotRuntime) -> bool:
	for part in chariot.parts:
		if part == null or part.broken or part.def == null:
			continue
		var behaviour = part.behaviour
		if behaviour != null and behaviour.prevent_death(self, chariot):
			return true
	return false


func heal(chariot: ChChariotRuntime, amount: int) -> int:
	# Answers what landed, capped at the body's max HP.
	if chariot == null or amount <= 0:
		return 0
	var before := chariot.hp
	chariot.hp = mini(chariot.max_hp, chariot.hp + amount)
	var healed := chariot.hp - before
	if healed > 0:
		_emit(ChEvent.HEALED, chariot, {"amount": healed})
	return healed


func gain_energy(chariot: ChChariotRuntime, amount: float) -> float:
	# Answers what the pool took, capped at its cap.
	if chariot == null or chariot.energy == null or amount <= 0.0:
		return 0.0
	var before := chariot.energy.value
	chariot.energy.value = minf(chariot.energy.value + amount, chariot.energy.cap)
	var gained := chariot.energy.value - before
	if gained > 0.0:
		_emit(ChEvent.ENERGY_GAINED, chariot, {"amount": gained})
	return gained


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

func give_status(target: Object, status: StringName, amount: int, hops := 1, from: Object = null,
		cause: StringName = &"part") -> int:
	# Put stacks on a part or a chariot body; answers the stacks added. Shock then jumps half to what touches.
	if target == null or amount <= 0 or (target is ChPartRuntime and target.broken):
		return 0
	amount = _gain_amount(target, status, amount, cause)
	if amount <= 0:
		return 0
	var before: int = target.statuses.count(status)
	var had: Dictionary = target.statuses.stacks.duplicate()
	var result: Dictionary = target.statuses.gain(status, amount)
	var added: int = result["added"]
	var puff := false
	for pair in result["cancelled"]:
		_emit(ChEvent.STATUS_CANCELLED, target, {"status": status, "against": pair[0], "amount": pair[1]})
		puff = puff or (status == ChStatuses.FLAME and pair[0] == ChStatuses.WET) \
			or (status == ChStatuses.WET and pair[0] == ChStatuses.FLAME)
	if result["doubled"] > 0:
		_emit(ChEvent.STATUS_DOUBLED, target, {"status": status, "amount": result["doubled"]})
	if added > 0:
		_emit(ChEvent.STATUS_GAINED, target, {"status": status, "amount": added, "before": before,
			"cause": cause, "from": from})
	for s in ChStatuses.ALL:
		if had[s] > 0 and target.statuses.count(s) == 0:
			_emit(ChEvent.STATUS_LOST, target, {"status": s})
	if puff and world != null:
		world.spawn_particles(&"steam", target.anchor_world(), Vector2.ZERO, STEAM_PUFF, 0.0)
	var half := added / 2
	if status == ChStatuses.SHOCK and half > 0:
		# The jump budget is a stat (R07's Storm Core gives an enemy holder 99), and the halving above
		# is what ends it: a jump of less than one stack is no jump.
		var jumps := roundi(stat(target, STAT_SHOCK_HOPS, hops))
		if jumps > 0 or (jumps == 0 and target.statuses.count(ChStatuses.WET) > 0):
			for other in touching(target):
				if other == from:
					continue
				_emit(ChEvent.SHOCK_JUMPED, other, {"from": target, "amount": half})
				give_status(other, ChStatuses.SHOCK, half, jumps - 1, target, &"jump")
	return added

# The gain hook, folded the way stat folds modify_stat: every unbroken part on both chariots, in
# side/mount order. A result of 0 or less adds nothing, so a part can refuse a status outright.
func _gain_amount(target: Object, status: StringName, amount: int, cause: StringName) -> int:
	var value := amount
	for behaviour in _modifiers:
		var part: ChPartRuntime = behaviour.part
		if part == null or part.broken:
			continue
		value = behaviour.modify_gain(self, target, status, value, cause)
	return value

func explode(source: ChPartRuntime, at: Vector2i, size: StringName, damage: int, dig := -1) -> void:
	# A part-made blast of a ChHazards size: digs, emits EXPLOSION, and hits the other side only.
	hazards.explode(self, source, at, size, damage, dig)

func own_charge(rect: Rect2i, side: int) -> void:
	# Explosive cells a part spawned: a blast that starts in them is that side's.
	hazards.own_charge(rect, side)


const SPARK_CELLS := 6  # spark cells throw_sparks writes about its point


# The sim helpers a part's behaviour calls: spawn writes material cells, throw_sparks throws a spark,
# dig removes a disc of terrain, push shoves a chassis and blow is the wind. Each is one place so a
# part never reaches PixelWorld, ChSparks or a chassis by itself.

# The world's gas-class material names, read once per call: air or a gas is the only cell a spawn may
# overwrite. A solid, a liquid, concrete and a part's stamped body pixels are all left alone.
func _gas_names() -> Dictionary:
	var gas := {}
	if world != null:
		for m in world.material_set.materials:
			if m.material_class == PixelMaterial.CLASS_GAS:
				gas[m.name] = true
	return gas

# The ring at `r` about `centre`, corners once, clockwise from the top-left. Ring 0 is the centre, so
# walking r = 0, 1, 2 ... is a spiral outward.
static func _ring(centre: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if r <= 0:
		out.append(centre)
		return out
	for i in range(-r, r):
		out.append(centre + Vector2i(i, -r))
		out.append(centre + Vector2i(r, i))
		out.append(centre + Vector2i(-i, r))
		out.append(centre + Vector2i(-r, -i))
	return out

# The smallest rect holding every cell, in whole cells.
static func _rect_of(cells: Array[Vector2i]) -> Rect2i:
	var lo := cells[0]
	var hi := cells[0]
	for cell in cells:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)

# Write `cells` of `material` into the air (or gas) nearest `at`, ring by ring, and answer how many
# landed. The part's own stat hook scales the count (spawn_<material>), so a neighbour can raise it.
# Gunpowder and TNT are owned by the part's side, and a battery block is recorded so it sparks.
func spawn(source: ChPartRuntime, material: StringName, at: Vector2, cells: int) -> int:
	if source == null or world == null or cells <= 0:
		return 0
	var want := roundi(stat(source, StringName("spawn_" + material), cells))
	if want <= 0:
		return 0
	var gas := _gas_names()
	var centre := Vector2i(roundi(at.x), roundi(at.y))
	var written: Array[Vector2i] = []
	var limit := maxi(world.arena.size.x, world.arena.size.y)
	var r := 0
	while written.size() < want and r <= limit:
		for cell in _ring(centre, r):
			if written.size() >= want:
				break
			var m := world.get_material_at(cell)
			if m == &"" or m == material or not (m == &"air" or gas.has(m)):
				continue
			world.set_cell(cell, material)
			written.append(cell)
		r += 1
	if not written.is_empty():
		var rect := _rect_of(written)
		if material == &"gunpowder" or material == &"tnt":
			own_charge(rect, source.side)
		elif material == &"battery":
			sparks.add_battery(self, rect)
	_emit(ChEvent.CELLS_SPAWNED, source,
		{"material": material, "count": written.size(), "at": at})
	return written.size()

# The spark a part throws at a point: SPARK_CELLS spark cells about `at`, then the discharge that
# floods out from them. Answers the holders shocked, as ChSparks.discharge does.
func throw_sparks(source: ChPartRuntime, at: Vector2, hops := 1, first_only := false) -> Array:
	if world == null:
		return []
	var gas := _gas_names()
	var centre := Vector2i(roundi(at.x), roundi(at.y))
	var seeds: Array[Vector2i] = []
	var limit := maxi(world.arena.size.x, world.arena.size.y)
	var r := 0
	while seeds.size() < SPARK_CELLS and r <= limit:
		for cell in _ring(centre, r):
			if seeds.size() >= SPARK_CELLS:
				break
			var m := world.get_material_at(cell)
			if m == &"" or m == &"spark" or not (m == &"air" or gas.has(m)):
				continue
			world.set_cell(cell, &"spark")
			seeds.append(cell)
		r += 1
	return ChSparks.discharge(self, seeds, true, hops, first_only)

# Remove the cells of `hardness` or softer in the disc at `at`, never concrete, and answer how many
# went. The count is the disc rect's non-air before and after the blast, so a cell the blast only lit
# or threw is not counted as dug.
func dig(at: Vector2i, radius: int, hardness: int) -> int:
	if world == null or radius <= 0:
		return 0
	var rect := Rect2i(at - Vector2i(radius, radius), Vector2i(radius * 2 + 1, radius * 2 + 1))
	var before := _non_air(rect)
	world.explode(at, radius, 0.0, hardness)
	var removed := before - _non_air(rect)
	if removed > 0:
		var event := ChEvent.new()
		event.type = ChEvent.CELLS_DUG
		event.position = Vector2(at)
		event.data = {"count": removed}
		bus.emit(event)
	return removed

# The non-air cells of a rect. count_materials also reports &"burning" for the cells that carry the
# flag, which is the same cell counted twice, so that key is left out.
func _non_air(rect: Rect2i) -> int:
	var counts := world.count_materials(rect)
	var total := 0
	for key in counts:
		if key != &"burning":
			total += int(counts[key])
	return total

# Shove a chariot's chassis. A chassis that has left the tree is skipped, as every other caller does.
func push(chariot: ChChariotRuntime, impulse: Vector2) -> void:
	if chariot == null or chariot.chassis == null or not is_instance_valid(chariot.chassis):
		return
	chariot.chassis.apply_impulse(impulse)

# Wind: move the gas cells of `rect` by `velocity`, and answer how many moved. Grid cells only —
# fire still in flight is a particle, not a cell, and stays where it is.
# ponytail: a particle push in ChFx's pool, for when a wind part has to shove a flame jet.
func blow(rect: Rect2i, velocity: Vector2i) -> int:
	if world == null:
		return 0
	return world.blow(rect, velocity)

func _block_used(holder: Object, had: int, attacker: Object = null) -> void:
	# Block only ever runs out by being used: a hit or Acid. Either way the holder loses it, and a hit
	# names the attacker so a listener can answer it.
	if had > 0 and holder.statuses.count(ChStatuses.BLOCK) == 0:
		var data := {"status": ChStatuses.BLOCK}
		if attacker != null:
			data["attacker"] = attacker
		_emit(ChEvent.STATUS_LOST, holder, data)

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
		"target_chariot": target_chariot,
		"damage": damage,
		"multiplier": multiplier,
		"block_mult": 1.0,  # what Block spends on the share it soaks; U23's Etching Ray is 2
		"bonus": source.bonus_damage,  # part's bonus damage, modifiers may raise it
		# Which holder soaks the hit: the part struck, or the body when the hull was hit. An incoming
		# hook may name another holder, which is how the Citadel spends the body's Block first.
		"block_holder": null,
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
			# near is the single proximity helper: range through the stat hook, or a links() behaviour.
			if near(other, source):
				_ask_behaviour(other, hit)
	# The source's own behaviour gets the last word on its own hit: a weapon reads the target off
	# the dict rather than measuring, which is how the Mace's Shatter reads a frozen part.
	_ask_behaviour(source, hit)
	# The side being hit gets its turn next, in mount order, before any of the hit is paid: a hook can
	# redirect the part struck or name the holder whose Block soaks it.
	_ask_incoming(target_chariot, hit)
	target_part = hit["target_part"]
	# The modifiers had their turn, so ChDamage applies what they left. A part hit wears the part
	# as well as the chariot, and the multiplier never reaches the wear: that rule is ChDamage's,
	# pinned by its own tests, so nothing here restates it.
	# The Block that soaks the hit is the holder's: the part struck, the body for a hull hit, or what
	# an incoming hook named.
	var holder: Object = hit["block_holder"]
	if holder == null:
		holder = target_part if target_part != null else target_chariot
	var block: int = holder.statuses.count(ChStatuses.BLOCK)
	var result: Dictionary
	# The applied damage is (damage + bonus) * multiplier: bonus folds in before the multiplier.
	var applied: int = hit["damage"] + hit["bonus"]
	if target_part == null:
		result = ChDamage.hit_body(target_chariot.hp, applied, hit["multiplier"], block,
			hit["block_mult"])
	else:
		result = ChDamage.hit_part(target_chariot.hp, target_part.integrity,
			applied, hit["multiplier"], 0.5, block, hit["block_mult"])
		target_part.integrity = result["integrity"]
	# Block pays before HP does: the hole in the pool is written first, so a would-die save that adds
	# Block during lose_hp is not wiped by the pre-hit reading.
	holder.statuses.stacks[ChStatuses.BLOCK] = result["block"]
	var damage_out: int = lose_hp(target_chariot, target_chariot.hp - result["hp"], &"hit", source)
	var soaked: int = block - result["block"]
	if soaked > 0:
		# Block took part of the hit: the holder says so, and the attacker is named on both events.
		_emit(ChEvent.BLOCK_ABSORBED, holder, {"amount": soaked, "attacker": source})
	_block_used(holder, block, source if soaked > 0 else null)
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
	if source.fire_cells_per_hit > 0:
		# The hit has landed, so a part it just broke still pays out where it stood.
		var at := target_part.anchor_world() if target_part != null \
				else ChBattle.hull_box(target_chariot).get_center()
		spawn(source, &"fire", at, source.fire_cells_per_hit)


func _player_fire(source: ChPartRuntime) -> bool:
	# The hits the fire handicap reaches: the player's own, from a part the part data tags as fire — the
	# same tags the shop's themes roll on (Task 4), so "fire-tagged" is the shipped def's own word for it.
	return source.side == 0 and source.def != null and source.def.tags.has("fire")


func _ask_behaviour(part: ChPartRuntime, hit: Dictionary) -> void:
	var behaviour = part.behaviour
	if behaviour != null:
		behaviour.modify_hit(self, hit)

func _ask_incoming(chariot: ChChariotRuntime, hit: Dictionary) -> void:
	# Every unbroken part of the side being hit, in mount order, so a redirect named by an earlier
	# part is seen by the later ones and no hit ever asks a broken part.
	for part in chariot.parts:
		if part == null or part.broken or part.def == null:
			continue
		var behaviour = part.behaviour
		if behaviour != null:
			behaviour.modify_incoming(self, hit)

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


func _emit_skipped(part: ChPartRuntime, cost: int) -> void:
	# PART_SKIPPED announces a ready part the volley's pool refused: the spec's "a part is skipped in
	# a volley" trigger. The source names the part and the payload carries what it would have cost.
	var event := ChEvent.new()
	event.type = ChEvent.PART_SKIPPED
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	event.data = {"cost": cost}
	bus.emit(event)


func force_fire(part: ChPartRuntime, by: ChPartRuntime, once := false) -> void:
	# A forced fire (the spec's "makes another part fire"): the part fires without a press, so it pays
	# nothing and its cooldown and tick timer stay where they were. It still counts as firing for every
	# trigger, so it emits PART_FIRED like any other firing, with the part that forced it in the payload.
	# "once" is for a rule that says a weapon is forced at most once per tick (R15): the marker is the
	# context's, so it holds even when two parts force the same weapon in the same tick.
	if part == null or part.broken or part.is_frozen() or part.behaviour == null or part.def == null:
		return
	if once:
		if _forced_at.get(part) == time:
			return
		_forced_at[part] = time
	var behaviour = part.behaviour
	if part.def.is_continuous():
		# The continuous step's own rule: a tick that lands is a firing, a tick that finds nothing is not.
		if not behaviour.continuous_tick(self):
			return
	else:
		behaviour.fire(self)
	var event := ChEvent.new()
	event.type = ChEvent.PART_FIRED
	event.side = part.side
	event.source = part
	event.position = part.anchor_world()
	event.data = {"forced": true, "by": by}
	bus.emit(event)


func volley_cost(chariot: ChChariotRuntime) -> int:
	# What a press would cost if every ready part could pay: the HUD's and the enemy's read.
	var total := 0
	for part in chariot.parts:
		if part.is_ready():
			total += part.cost
	return total


# Emits RAMMED when the two hulls start to overlap at ramming speed, once per contact. The boxes
# (and each one grown 1 cell, so a face landing flush still counts) are the hull boxes the rest of the
# fight measures; a contact ends when they stop overlapping, so the next touch is a new ram.
func _check_ram() -> void:
	if chariots.size() < 2:
		_ram_contact = false
		return
	var a: ChChariotRuntime = chariots[0]
	var b: ChChariotRuntime = chariots[1]
	if a == null or b == null or a.chassis == null or b.chassis == null \
			or not is_instance_valid(a.chassis) or not is_instance_valid(b.chassis):
		_ram_contact = false
		return
	if not a.status_box().grow(1.0).intersects(b.status_box().grow(1.0)):
		_ram_contact = false
		return
	if _ram_contact:
		return
	_ram_contact = true
	# Both sides can ram in one contact: each one's own speed toward the other decides.
	_try_ram(a, b)
	_try_ram(b, a)

func _try_ram(rammer: ChChariotRuntime, other: ChChariotRuntime) -> void:
	var toward := other.anchor_world() - rammer.anchor_world()
	if toward.length() <= 0.0:
		return
	if rammer.chassis.linear_velocity.dot(toward.normalized()) < RAM_SPEED:
		return
	var overlap: Rect2 = rammer.status_box().grow(1.0).intersection(other.status_box().grow(1.0))
	var at: Vector2 = overlap.get_center() if overlap.size.x > 0.0 and overlap.size.y > 0.0 \
			else (rammer.anchor_world() + other.anchor_world()) * 0.5
	var event := ChEvent.new()
	event.type = ChEvent.RAMMED
	event.side = rammer.side
	event.source = rammer
	event.position = at
	event.data = {"target_part": _nearest_part(other, at)}
	bus.emit(event)

# The other side's unbroken part nearest `at`, or null for the hull: the part a ram pays.
func _nearest_part(chariot: ChChariotRuntime, at: Vector2) -> ChPartRuntime:
	var best: ChPartRuntime = null
	var best_at := INF
	for part in chariot.parts:
		if part.broken or part.def == null:
			continue
		var near := part.anchor_world().distance_to(at)
		if near < best_at:
			best_at = near
			best = part
	return best

# Emits LANDED for each side that touched down after LANDED_AFTER or more seconds in the air.
func _check_landings(delta: float) -> void:
	while _airborne_for.size() < chariots.size():
		_airborne_for.append(0.0)
		_was_airborne.append(false)
	for at in chariots.size():
		var chariot: ChChariotRuntime = chariots[at]
		# A hull that has left the world is nobody's landing: the walk resets rather than emitting
		# for a chariot that was freed mid-fight.
		if chariot == null or chariot.chassis == null or not is_instance_valid(chariot.chassis):
			_airborne_for[at] = 0.0
			_was_airborne[at] = false
			continue
		if chariot.airborne():
			_was_airborne[at] = true
			_airborne_for[at] += delta
			continue
		if _was_airborne[at] and _airborne_for[at] >= LANDED_AFTER:
			var event := ChEvent.new()
			event.type = ChEvent.LANDED
			event.side = chariot.side
			event.source = chariot
			event.position = chariot.anchor_world()
			bus.emit(event)
		_was_airborne[at] = false
		_airborne_for[at] = 0.0


func tick(delta: float, drive_input: Array[float], press_input: Array = [], hold_input: Array = []) -> Array[int]:
	# One frame of the fight for every chariot, in the order this file's header states. Answers the
	# number of parts each side fired this frame, indexed by side. hold_input is the held button per
	# side, which only the continuous step reads: a side with no entry reads not held.
	if not _battle_started and bus != null:
		_battle_started = true
		var event := ChEvent.new()
		event.type = ChEvent.BATTLE_STARTED
		bus.emit(event)
	time += delta
	_check_ram()
	_check_landings(delta)
	_tick_fuses(delta)
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
		var held: bool = bool(hold_input[at]) if at < hold_input.size() else false
		fired.append(_tick_chariot(chariot, delta, direction, pressed, held))
	return fired

func _tick_fuses(delta: float) -> void:
	# One tick of every lit fuse: the ones still burning stay, the ones that ran out explode where they
	# landed. A mine has no clock of its own: it waits in the same list for an enemy part to come near,
	# so it outlives the part that laid it. The entry carries the blast, so the context needs no
	# knowledge of the part behind it.
	if fuses.is_empty():
		return
	var live: Array = []
	for fuse in fuses:
		if fuse.has("mine"):
			if _mine_set_off(fuse):
				_explode_fuse(fuse)
			else:
				live.append(fuse)
			continue
		var left: float = float(fuse["left"]) - delta
		if left > 0.0:
			fuse["left"] = left
			live.append(fuse)
			continue
		_explode_fuse(fuse)
	fuses = live

func _explode_fuse(fuse: Dictionary) -> void:
	# The blast every fuse entry carries, and the marker a mine leaves in the world: both go together,
	# so a spent mine takes its sprite with it.
	var node: Node = fuse.get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	var source: ChPartRuntime = fuse["part"]
	if source != null:
		explode(source, fuse["at"], fuse["size"], int(fuse["damage"]), int(fuse["dig"]))

func _mine_set_off(fuse: Dictionary) -> bool:
	# True once an enemy part's box comes within `mine` cells of the mine. The layer's side is the
	# mine's own, read off the part, so a layer broken in the meantime still knows whose it is.
	var source: ChPartRuntime = fuse["part"]
	if source == null:
		return false
	var at: Vector2 = fuse["at"]
	var reach := float(fuse["mine"])
	for chariot in chariots:
		if chariot == null or chariot.side == source.side:
			continue
		for part in chariot.parts:
			if part.broken:
				continue
			var box := part.status_box()
			if at.distance_to(at.clamp(box.position, box.end)) <= reach:
				return true
	return false

func _tick_chariot(chariot: ChChariotRuntime, delta: float, direction: float, pressed: bool,
		held: bool) -> int:
	# One frame of one side: cooldowns, the pool's tick, the volley if pressed, the continuous step
	# the held button drives, process, then the drive. A broken part is skipped for the whole pass: it
	# is off the bus and out of the joints, so this pass must not fire it or re-process it. One flag,
	# part.broken, closes both, and the dead joint is never read here at all, which is what Review
	# Focus 3 asks for.
	chariot.settle_mass()
	# Per-tick refresh of the fields the volley, the continuous step and the AI read: they come
	# from the stat hook so a modify_stat behaviour can change cost, rate or cooldown mid-fight.
	for part in chariot.parts:
		if part.broken or part.def == null:
			continue
		part.cost = roundi(stat(part, STAT_ENERGY_COST, part.def.energy_cost))
		part.rate = stat(part, STAT_ENERGY_PER_SECOND, part.def.energy_per_second)
		part.cooldown = stat(part, STAT_COOLDOWN, part.def.cooldown)
	for part in chariot.parts:
		if part.broken:
			continue
		# A cooldown only counts down here; whether the part fires is the press's call.
		part.tick_cooldown(delta, stat(part, STAT_TICK_RATE, part.tick_rate()))
	# The drive's price is this chariot's unbroken wheels (ChChariotRuntime.drive_cost), so a wheel
	# that broke this tick stops costing at once.
	chariot.energy.drive_cost = chariot.drive_cost()
	var result: Dictionary = chariot.energy.tick(delta, direction != 0.0, _regen_mult(chariot))
	chariot.driving = result["drove"]
	var fired_count := 0
	if pressed:
		# The volley: ready triggered parts, the highest volley_priority first (U60's relay), then
		# dearest first so the big weapons get the energy before the small ones can eat it. A part that
		# does not fit is skipped and a cheaper one after it can still pay; the skipped part stays ready
		# and nothing is remembered to the next press.
		var volley: Array[ChPartRuntime] = []
		var priority: Dictionary = {}
		for part in chariot.parts:
			if part.is_ready():
				volley.append(part)
				priority[part] = stat(part, STAT_VOLLEY_PRIORITY, 0.0)
		# sort_custom is not stable, so ties break on mount order (index in chariot.parts) here.
		var order: Dictionary = {}
		for at in chariot.parts.size():
			order[chariot.parts[at]] = at
		volley.sort_custom(func(a: ChPartRuntime, b: ChPartRuntime) -> bool:
			if priority[a] != priority[b]:
				return priority[a] > priority[b]
			if a.cost != b.cost:
				return a.cost > b.cost
			return order[a] < order[b])
		for part in volley:
			# A fire earlier in this volley can break or freeze a part that was ready when the press
			# began, so readiness is read again before paying.
			if not part.is_ready():
				continue
			if not chariot.energy.try_pay(part.cost):
				if stat(part, STAT_BLOOD_PAY, 0.0) <= 0.0:
					_emit_skipped(part, part.cost)
					continue
				# R28: the part pays in blood. It spends the whole pool and buys the shortfall with HP,
				# then fires as any paid part does, with no PART_SKIPPED.
				var short := part.cost - chariot.energy.value
				chariot.energy.spent += chariot.energy.value
				chariot.energy.value = 0.0
				lose_hp(chariot, roundi(BLOOD_PER_ENERGY * short), &"blood", part)
			var behaviour = part.behaviour
			if behaviour != null:
				# U63 prices the 1 energy the volley paid off this; a forced fire leaves it false.
				part.paid = true
				behaviour.fire(self)
				part.paid = false
			# The cooldown and the charge belong to the loop, not to the behaviour, so a part cannot
			# fire twice on one payment: its countdown restarts here and is_ready is false again.
			part.cooldown_left = part.cooldown
			if part.charges_left > 0:
				# charges_left -1 is unlimited, so an unlimited part never enters this branch. A
				# limited part stops at 0, where is_ready turns false, rather than stepping into
				# the sentinel.
				part.charges_left -= 1
			_emit_fired(part)
			fired_count += 1
	_continuous(chariot, delta, held)
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


func _continuous(chariot: ChChariotRuntime, delta: float, held: bool) -> void:
	# The held button's step: every continuous part, dearest energy_per_second first so the big
	# weapons get their energy, ties broken by mount order (the volley's rule). Each one pays
	# energy_per_second * delta; a part that cannot pay, or a button that is up, is not running and
	# keeps its timer, so a release never becomes a free tick. A running part's timer counts down at
	# the status rate, and at 0 its behaviour gets the tick: a landed tick restarts the timer at one
	# second and a melee announces PART_FIRED; a miss clamps the timer at 0 to try again next frame.
	var order: Dictionary = {}
	var parts: Array[ChPartRuntime] = []
	for at in chariot.parts.size():
		var part: ChPartRuntime = chariot.parts[at]
		if part.def != null and part.def.is_continuous():
			order[part] = at
			parts.append(part)
	parts.sort_custom(func(a: ChPartRuntime, b: ChPartRuntime) -> bool:
		if a.rate != b.rate:
			return a.rate > b.rate
		return order[a] < order[b])
	for part in parts:
		if not held or not part.can_run() \
				or not chariot.energy.try_pay(part.rate * delta):
			# Not held, not runnable or not affordable: the part did not run, and its timer stays as it was.
			part.running = false
			continue
		if not part.running and part.def.mode == ChPartDef.MODE_BEAM:
			# A beam announces the moment it switches on, then hits each second without repeating.
			_emit_fired(part)
		part.running = true
		part.tick_left -= delta * stat(part, STAT_TICK_RATE, part.tick_rate())
		if part.tick_left > 0.0:
			continue
		var behaviour = part.behaviour
		var landed: bool = behaviour != null and behaviour.continuous_tick(self)
		if landed:
			part.tick_left = 1.0
			if part.def.mode == ChPartDef.MODE_MELEE:
				_emit_fired(part)
		else:
			# A missed tick retries next frame from 0 rather than counting down past it.
			part.tick_left = 0.0


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
				give_status(holder, status, gains[status] - (1 if status in held else 0), 1, null, &"cells")
		# The decay hook scales each status's loss; a holder that is not gaining it still decays it.
		var amounts := {}
		for status in ChStatuses.DECAYS:
			if holder.statuses.count(status) > 0:
				amounts[status] = roundi(stat(holder, decay_stat(status), 1.0))
		for status in holder.statuses.decay(gains.keys(), amounts):
			_emit(ChEvent.STATUS_LOST, holder, {"status": status})


func _status_damage(chariot: ChChariotRuntime, holder: Object) -> void:
	# Flame (scaled by the fire handicap on side 1), Acid past Block, and Shock: integrity on a
	# part, HP on the body, never both. Flame and Shock go straight past Block. Each of the three is
	# scaled by its own stat hook, so a part can raise or lower the damage a status does.
	var s: ChStatuses = holder.statuses
	var flame_mult := rules.fire_mult if holder.side == 1 else 1.0
	var block := s.count(ChStatuses.BLOCK)
	var flame := roundi(s.count(ChStatuses.FLAME) * flame_mult * stat(holder, STAT_FLAME_DAMAGE, 1.0))
	var acid := roundi(s.count(ChStatuses.ACID) * stat(holder, STAT_ACID_DAMAGE, 1.0))
	var shock := roundi(s.count(ChStatuses.SHOCK) * stat(holder, STAT_SHOCK_DAMAGE, 1.0))
	# The Acid the holder's Block let through is the Acid its integrity wears, and the amount R10
	# pays to the chariot's HP as well.
	var acid_damage := acid - s.absorb(acid)
	var damage := flame + acid_damage + shock
	_block_used(holder, block)
	if damage <= 0:
		return
	if holder is ChPartRuntime:
		var before: int = holder.integrity
		holder.integrity = maxi(0, holder.integrity - damage)
		if before > holder.integrity:
			_emit(ChEvent.INTEGRITY_LOST, holder, {"amount": before - holder.integrity, "cause": &"status"})
		if acid_damage > 0 and stat(holder, STAT_ACID_TO_HP, 0.0) >= 1.0:
			lose_hp(chariot, acid_damage, &"status")
		if holder.integrity <= 0:
			chariot.break_part(holder, self)
	else:
		lose_hp(chariot, damage, &"status")


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
