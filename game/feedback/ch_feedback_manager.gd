class_name ChFeedbackManager extends Node

# The one entry point for a feedback beat: Feedback.play(&"struck", node, {amount = 12}).
# Profiles are data (game/feedback/profiles/<kind>.tres); play() kicks the target's juice, pops
# its text, bursts its particles and shakes the battle's camera. Screen shake is the one beat the
# manager cannot get from the target: the camera belongs to the fight, so ChBattle binds its own
# noise emitter here while a fight runs.
# Nothing here writes fight state: feedback reads the fight, it never changes it.

const KINDS := [&"fired", &"landed", &"struck", &"caught_fire", &"frozen", &"thawed",
	&"broken", &"energy", &"activate", &"hover", &"placed", &"nudge", &"tooltip"]
const PROFILE_DIR := "res://game/feedback/profiles/"
# A one-shot UI burst lives about as long as a battle one.
const UI_PARTICLE_LIFE := 0.5

# Seeded by tests so a randomised rotation sign is reproducible.
var rng := RandomNumberGenerator.new()

# The fight's world and the node whose targets are in it (the battle, not the world: bodies are
# children of ChBattle). Bound by ChBattle while a fight runs, so a beat aimed at a battle node
# bursts world particles at its cell position instead of using screen-space CPU particles.
var _world: PixelWorld
var _scope: Node

# The battle's shake emitter, bound by ChBattle while a fight runs. The live pcam reads the noise it
# emits; the manager only starts it, so a beat can shake a scene that has no emitter (a menu) harmlessly.
var _shake: PhantomCameraNoiseEmitter2D

# shortcut: kinds are cached for the life of the autoload; a .tres edited while the game runs
# needs a restart. Fine while these are tuning values.
var _profiles: Dictionary[StringName, ChFeedbackProfile] = {}

# The one screen-space pop-up layer; one-shot CPU particle bursts hang under it too.
var popups: ChPopups


func _ready() -> void:
	popups = ChPopups.new()
	add_child(popups)


func profile(kind: StringName) -> ChFeedbackProfile:
	if _profiles.has(kind):
		return _profiles[kind]
	var found: ChFeedbackProfile = null
	if KINDS.has(kind):
		found = load(PROFILE_DIR + "%s.tres" % kind) as ChFeedbackProfile
	else:
		push_warning("ChFeedbackManager: unknown feedback kind %s" % kind)
	_profiles[kind] = found
	return found


func play(kind: StringName, target, overrides := {}) -> void:
	# `target` is deliberately untyped: GDScript rejects a freed reference at a parameter typed
	# CanvasItem before this body runs (verified on 4.7.2), and a beat fired at a node that died
	# this frame must be skipped, not raise. Callers pass a CanvasItem.
	if not is_instance_valid(target):
		return
	var beat := profile(kind)
	if beat == null:
		return
	_pop_text(beat, target, overrides)
	_burst(beat, target, overrides)
	# Kicking a target that has no Juice is a no-op: the Juice child belongs to whoever owns
	# the node (buttons, battle visuals, the garage), never to feedback itself.
	var juice := ChJuice.of(target)
	if juice != null:
		var rotation_kick := deg_to_rad(beat.rotation_kick_deg)
		if rng.randf() < 0.5:
			rotation_kick = -rotation_kick
		juice.kick(beat.scale_kick, rotation_kick)
	_shake_camera(beat)


func _pop_text(beat: ChFeedbackProfile, target, overrides: Dictionary) -> void:
	# `overrides.text` wins over the profile's text; a `%d` in the result is the beat's amount.
	var text: String = overrides.get("text", beat.text)
	if text == "":
		return
	if text.contains("%d"):
		text = text % int(overrides.get("amount", 0))
	if not target is CanvasItem or popups == null:
		return
	popups.pop(text, beat.text_color, target.get_global_transform_with_canvas().origin)


func bind_shake(emitter: PhantomCameraNoiseEmitter2D) -> void:
	_shake = emitter


func unbind_shake() -> void:
	_shake = null


func _shake_camera(beat: ChFeedbackProfile) -> void:
	# The profile's shake is its strength: 12 cells of amplitude at 1.0, held for 0.08 s plus a
	# quarter second per unit, so a broken hull jolts hard and a fired weapon barely stirs the shot.
	if beat.shake <= 0.0 or _shake == null or not is_instance_valid(_shake):
		return
	var noise := _shake.noise
	if noise == null:
		return
	var amplitude := 12.0 * beat.shake
	# Overlapping beats: a weaker shake must not cut a stronger one short, so while the emitter is
	# running only a louder amplitude takes over.
	if _shake.is_emitting() and amplitude <= noise.amplitude:
		return
	noise.amplitude = amplitude
	_shake.duration = 0.08 + 0.25 * beat.shake
	_shake.emit()


func bind_world(world: PixelWorld, scope: Node) -> void:
	_world = world
	_scope = scope


func unbind_world() -> void:
	_world = null
	_scope = null


func _in_world_scope(target: CanvasItem) -> bool:
	# A battle-world target hangs under the scope with no CanvasLayer in between. ChBattle also owns
	# the HUD's CanvasLayer, so being a descendant is not enough: a bar's pixels are screen
	# coordinates, not cells, and it takes the screen-space path below.
	if _world == null or not is_instance_valid(_world) \
			or _scope == null or not is_instance_valid(_scope):
		return false
	if not _scope.is_ancestor_of(target):
		return false
	var node := target.get_parent()
	while node != null and node != _scope:
		if node is CanvasLayer:
			return false
		node = node.get_parent()
	return true


func _burst(beat: ChFeedbackProfile, target, overrides: Dictionary) -> void:
	if beat.particle_count <= 0 or not target is CanvasItem:
		return
	var color: Color = overrides.get("color", beat.particle_color)
	# Battle space is cell space, so the body's global position is the world point.
	if _in_world_scope(target):
		ChFeedbackParticles.burst_world(_world, target.global_position, beat, color)
		return
	if popups == null:
		return
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	# All particles at once, so `finished` lands one lifetime after the burst, not two.
	burst.explosiveness = 1.0
	burst.lifetime = UI_PARTICLE_LIFE
	burst.amount = mini(beat.particle_count, ChFeedbackParticles.CAP)
	burst.color = color
	# Read as a burst, not a 1 px static square: spray out, move, fall, draw bigger than a pixel.
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 90.0
	burst.gravity = Vector2(0, 200)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 2.0
	burst.position = target.get_global_transform_with_canvas().origin
	popups.add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


func attach_button(button: BaseButton) -> void:
	ChJuice.attach(button)
	# Idempotent: attach_button runs once per button per owner, but a repeated call must not
	# stack a second Juice or a second connection.
	var activate := play.bind(&"activate", button)
	if not button.pressed.is_connected(activate):
		button.pressed.connect(activate)
	var hover := play.bind(&"hover", button)
	if not button.mouse_entered.is_connected(hover):
		button.mouse_entered.connect(hover)
