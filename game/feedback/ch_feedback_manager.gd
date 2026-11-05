class_name ChFeedbackManager extends Node

# The one entry point for a feedback beat: Feedback.play(&"struck", node, {amount = 12}).
# Profiles are data (game/feedback/profiles/<kind>.tres); this task's play() only kicks the
# target's juice — text, particles and shake arrive in later tasks and belong here too.
# Nothing here writes fight state: feedback reads the fight, it never changes it.

const KINDS := [&"fired", &"landed", &"struck", &"caught_fire", &"frozen", &"thawed",
	&"broken", &"energy", &"activate", &"hover", &"placed", &"nudge"]
const PROFILE_DIR := "res://game/feedback/profiles/"

# Seeded by tests so a randomised rotation sign is reproducible.
var rng := RandomNumberGenerator.new()

# shortcut: kinds are cached for the life of the autoload; a .tres edited while the game runs
# needs a restart. Fine while these are tuning values.
var _profiles: Dictionary[StringName, ChFeedbackProfile] = {}


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
	# Kicking a target that has no Juice is a no-op: the Juice child belongs to whoever owns
	# the node (buttons, battle visuals, the garage), never to feedback itself.
	var juice := ChJuice.of(target)
	if juice == null:
		return
	var rotation_kick := deg_to_rad(beat.rotation_kick_deg)
	if rng.randf() < 0.5:
		rotation_kick = -rotation_kick
	juice.kick(beat.scale_kick, rotation_kick)


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
