class_name ChFightStats extends RefCounted

# Bound to one battle: samples every fight tick (ChBattle.stepped) and the bus's PART_FIRED / HIT
# events, then hands back one per-fight dictionary (see tools/balance/README.md for every field).
# It only reads: the fight plays out exactly as it would with nobody listening.

var _battle: ChBattle = null
var _bus: ChEventBus = null
var _starved_ticks: Array[int] = [0, 0]
var _flipped_ticks: Array[int] = [0, 0]
var _rams := 0
var _touching := false
var _parts: Dictionary = {}  # ChPartRuntime -> {firings, hits, damage, waiting_ticks, broke_at}


func bind(battle: ChBattle) -> void:
	_battle = battle
	battle.stepped.connect(_on_step)


func _on_step(ctx: ChBattleContext) -> void:
	if _bus == null:
		# The bus is made inside start(), with no frame between it and the first tick.
		# shortcut: events of tick 1 are missed. Parts start on a full cooldown, so only a part with a
		# cooldown under one tick could fire there; a seam before the first tick fixes it if one does.
		_bus = ctx.bus
		_bus.subscribe(self, ChEvent.PART_FIRED, _on_fired)
		_bus.subscribe(self, ChEvent.HIT, _on_hit)
	for side in 2:
		var chariot: ChChariotRuntime = ctx.chariots[side]
		if chariot.energy.queue_size() > 0:
			_starved_ticks[side] += 1
		# Hull past 90 degrees either way: on its side or upside down.
		if absf(wrapf(chariot.chassis.global_rotation, -PI, PI)) > PI / 2.0:
			_flipped_ticks[side] += 1
		for part in chariot.parts:
			var stats := _part(part)
			if chariot.energy.is_queued(part):
				stats.waiting_ticks += 1
			if part.broken and stats.broke_at < 0.0:
				stats.broke_at = ctx.time
	# A ram is the moment the hulls start touching, so a long shove counts once.
	var touching := _battle.hull_box(ctx.chariots[0]).grow(1.0).intersects(_battle.hull_box(ctx.chariots[1]))
	if touching and not _touching:
		_rams += 1
	_touching = touching


func _part(part: ChPartRuntime) -> Dictionary:
	if not _parts.has(part):
		_parts[part] = {"firings": 0, "hits": 0, "damage": 0, "waiting_ticks": 0, "broke_at": -1.0}
	return _parts[part]


func _on_fired(event: ChEvent) -> void:
	if event.source is ChPartRuntime:
		_part(event.source).firings += 1


func _on_hit(event: ChEvent) -> void:
	# Only hits on the other chariot count: a part that wears its own hull (Ring of Fire) has
	# dealt nothing to the enemy.
	if event.source is ChPartRuntime and event.data.get("target_side", -1) != event.source.side:
		var stats := _part(event.source)
		stats.hits += 1
		stats.damage += int(event.data.get("hp_damage", 0))


func fight(seed: int, result: StringName) -> Dictionary:
	var ctx: ChBattleContext = _battle.ctx if _battle != null else null
	if result == &"aborted" or ctx == null:
		return {"seed": seed, "result": String(result), "fight_seconds": 0.0,
			"sides": [_zero_side(), _zero_side()]}
	if _bus != null:
		# Done listening: the bus keeps no callbacks into an object the caller may drop.
		_bus.unsubscribe_all(self)
	var seconds := ctx.time
	var sides: Array = []
	for side in 2:
		var me: ChChariotRuntime = ctx.chariots[side]
		var other: ChChariotRuntime = ctx.chariots[1 - side]
		var dealt := other.body_def.hp - other.hp
		var parts := {}
		var part_sum := 0
		for part in me.parts:
			if part.def == null:
				continue
			var stats := _part(part)
			var spent := float(stats.firings * part.def.energy_cost)
			parts["%s@%s" % [part.def.id, part.path]] = {
				"part": String(part.def.id), "path": Array(part.path),
				"firings": stats.firings, "hits": stats.hits,
				"misses": maxi(0, stats.firings - stats.hits),
				"damage_dealt": stats.damage, "energy_spent": spent,
				"damage_per_energy": stats.damage / spent if spent > 0.0 else 0.0,
				"seconds_waiting": stats.waiting_ticks * ChBattle.TICK,
				"broke_at_seconds": stats.broke_at}
			part_sum += stats.damage
		sides.append({"hp_left": me.hp, "damage_dealt": dealt, "unattributed_damage": dealt - part_sum,
			"dps_dealt": dealt / seconds if seconds > 0.0 else 0.0,
			"energy_spent": me.energy.spent,
			"energy_starved_seconds": _starved_ticks[side] * ChBattle.TICK,
			"flipped_seconds": _flipped_ticks[side] * ChBattle.TICK,
			"rams": _rams, "parts": parts})
	return {"seed": seed, "result": String(result), "fight_seconds": seconds, "sides": sides}


static func _zero_side() -> Dictionary:
	return {"hp_left": 0, "damage_dealt": 0, "unattributed_damage": 0, "dps_dealt": 0.0,
		"energy_spent": 0.0, "energy_starved_seconds": 0.0, "flipped_seconds": 0.0, "rams": 0,
		"parts": {}}
