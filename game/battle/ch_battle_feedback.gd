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
	# One listener key (self) for all seven types, so unsubscribe_all(self) drops the lot.
	for type in [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.CAUGHT_FIRE, ChEvent.FROZEN,
			ChEvent.THAWED, ChEvent.PART_BROKEN, ChEvent.ENERGY_GAINED]:
		_ctx.bus.subscribe(self, type, on_event)


func on_event(event: ChEvent) -> void:
	var source := event.source as ChPartRuntime
	if source == null:
		return
	match event.type:
		ChEvent.PART_FIRED:
			_play(&"fired", source)
		ChEvent.HIT:
			_hit(event, source)
		ChEvent.CAUGHT_FIRE:
			_play(&"caught_fire", source)
		ChEvent.FROZEN:
			_play(&"frozen", source)
		ChEvent.THAWED:
			_play(&"thawed", source)
		ChEvent.PART_BROKEN:
			# The part's own def colour, so a broken wheel's burst matches its art.
			_play(&"broken", source, {"color": source.def.color} if source.def != null else {})
		ChEvent.ENERGY_GAINED:
			# The Ember Battery sends what landed after the cap; 3 (its GAIN) is the fallback.
			_play(&"energy", source, {"amount": int(event.data.get("amount", 3))})


func _hit(event: ChEvent, source: ChPartRuntime) -> void:
	# The attacker's part takes the landed beat; the struck side takes the number and the bar nudge.
	_play(&"landed", source)
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


func _play(kind: StringName, part: ChPartRuntime, overrides := {}) -> void:
	# A part beats on its body's "Visual" child; a part whose body left the world has none, and the
	# beat is dropped rather than played on a freed node.
	# shortcut: no beat for a skipped part; a fight that wants a missing visual reported wants an
	# event or a warning here.
	if not is_instance_valid(part.visual):
		return
	Feedback.play(kind, part.visual, overrides)
