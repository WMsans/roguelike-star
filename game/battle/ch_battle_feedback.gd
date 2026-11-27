class_name ChBattleFeedback extends RefCounted

# Task 8: the fight's events, played as feedback. One listener on the battle's bus turns each event
# into Feedback.play beats: the part that acted wobbles, a hit pops its number on the part (or the
# hull) it landed on and nudges the struck side's HP bar. Nothing here writes fight state — the
# beats move Visual nodes, ChJuice and the pop-up layer only — and nothing here keeps a value the
# fight reads. A source or target whose visual has left the world is skipped in silence: a beat is
# decoration, not an error.

var _ctx: ChBattleContext
var _hud: ChBattleHud


func _init(ctx: ChBattleContext, hud: ChBattleHud) -> void:
	_ctx = ctx
	_hud = hud
	# nudge kicks the bar it lands on, and a bar is the HUD's node, so the Juice goes on here: play()
	# never attaches one of its own (ChFeedbackManager's contract).
	ChJuice.attach(hud.player_bar)
	ChJuice.attach(hud.enemy_bar)


func subscribe() -> void:
	# One listener key (self) for every type, so unsubscribe_all(self) drops the lot.
	for type in [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.STATUS_GAINED, ChEvent.STATUS_LOST,
			ChEvent.PART_BROKEN, ChEvent.ENERGY_GAINED, ChEvent.HAZARD_HIT, ChEvent.HP_LOST,
			ChEvent.INTEGRITY_LOST]:
		_ctx.bus.subscribe(self, type, on_event)


func on_event(event: ChEvent) -> void:
	if event.type == ChEvent.HAZARD_HIT:
		_hazard(event)
		return
	if event.type == ChEvent.HP_LOST:
		_hp_lost(event)
		return
	if event.type == ChEvent.INTEGRITY_LOST:
		_integrity_lost(event)
		return
	var holder := event.source
	if holder is ChChariotRuntime:
		# A status on the body names the chariot, not a part, so its beat belongs on the hull's visual.
		_body_status(event, holder)
		return
	var source := holder as ChPartRuntime
	if source == null:
		return
	match event.type:
		ChEvent.PART_FIRED:
			_play(&"fired", source.visual)
		ChEvent.HIT:
			_hit(event, source)
		ChEvent.STATUS_GAINED:
			if ChEvent.caught_fire(event):
				_play(&"caught_fire", source.visual)
				_fx(&"ignite", source.visual)
			elif ChEvent.first_stack(event, ChStatuses.FREEZE):
				_play(&"frozen", source.visual)
				_fx(&"frost", source.visual)
		ChEvent.STATUS_LOST:
			if ChEvent.thawed(event):
				_play(&"thawed", source.visual)
				# A Shatter breaks the ice; a freeze that ran out just melts, with no burst.
				if event.data.get("shatter", false):
					_fx(&"shatter", source.visual)
		ChEvent.PART_BROKEN:
			_fx(&"fire_blast", source.visual)
			# The part's own def colour, so a broken wheel's burst matches its art.
			_play(&"broken", source.visual, {"color": source.def.color} if source.def != null else {})
		ChEvent.ENERGY_GAINED:
			# The Ember Battery sends what landed after the cap; 3 (its GAIN) is the fallback.
			_play(&"energy", source.visual, {"amount": int(event.data.get("amount", 3))})


func _hit(event: ChEvent, source: ChPartRuntime) -> void:
	# The attacker's part takes the landed beat; the struck side takes the number and the bar nudge.
	_play(&"landed", source.visual)
	var target_part: ChPartRuntime = event.data.get("target_part")
	# Ruling: the event's `side` is the attacker's, so the struck side is the target part's own side,
	# and the other chariot's when the hull itself was hit (target_part is null there).
	var struck_side := 1 - source.side
	var target: Node2D = null
	if target_part != null:
		struck_side = target_part.side
		target = target_part.visual
	else:
		var other := _ctx.enemy_of(source)
		if other != null:
			target = other.chassis_visual
	if is_instance_valid(target):
		Feedback.play(&"struck", target, {"amount": int(event.data.get("hp_damage", 0))})
	var bar: ProgressBar = _hud.enemy_bar if struck_side == 1 else _hud.player_bar
	if is_instance_valid(bar):
		Feedback.play(&"nudge", bar)


func _hazard(event: ChEvent) -> void:
	# A blast has no source part: the struck chariot takes the same number and bar nudge as a HIT.
	var struck: ChChariotRuntime = _ctx.chariots[event.data.target_side]
	if is_instance_valid(struck.chassis_visual):
		Feedback.play(&"struck", struck.chassis_visual, {"amount": int(event.data.hp_damage)})
	var bar: ProgressBar = _hud.enemy_bar if event.data.target_side == 1 else _hud.player_bar
	if is_instance_valid(bar):
		Feedback.play(&"nudge", bar)


func _hp_lost(event: ChEvent) -> void:
	# The status second's damage has no HIT or HAZARD_HIT to carry its number, so this is the beat
	# that shows it; a hit or a blast already showed its own.
	if event.data.get("cause") != &"status":
		return
	var side: int = event.side
	if side < 0 or side >= _ctx.chariots.size():
		return
	var struck: ChChariotRuntime = _ctx.chariots[side]
	_play(&"struck", struck.chassis_visual, {"amount": int(event.data.get("amount", 0))})


func _integrity_lost(event: ChEvent) -> void:
	# A part's status damage: the same number on the part that wore.
	var part := event.source as ChPartRuntime
	if part != null:
		_play(&"struck", part.visual, {"amount": int(event.data.get("amount", 0))})


func _body_status(event: ChEvent, body: ChChariotRuntime) -> void:
	# The caught-fire, frozen and thawed beats on the hull, the same three a part's status plays.
	var visual: Node2D = body.chassis_visual
	match event.type:
		ChEvent.STATUS_GAINED:
			if ChEvent.caught_fire(event):
				_play(&"caught_fire", visual)
				_fx(&"ignite", visual)
			elif ChEvent.first_stack(event, ChStatuses.FREEZE):
				_play(&"frozen", visual)
				_fx(&"frost", visual)
		ChEvent.STATUS_LOST:
			if ChEvent.thawed(event):
				_play(&"thawed", visual)
				if event.data.get("shatter", false):
					_fx(&"shatter", visual)


func _play(kind: StringName, target: Node2D, overrides := {}) -> void:
	# A beat on a body's "Visual" child; a body that left the world has none, and the beat is dropped
	# rather than played on a freed node.
	# shortcut: no beat for a skipped target; a fight that wants a missing visual reported wants an
	# event or a warning here.
	if not is_instance_valid(target):
		return
	Feedback.play(kind, target, overrides)


func _fx(fx: StringName, target: Node2D) -> void:
	# A status burst plays in the world at the body, which is cell space. Same rule as _play: a body
	# that left the world has nowhere to play it.
	if is_instance_valid(target):
		ChFx.spawn(_ctx.world, fx, target.global_position)
