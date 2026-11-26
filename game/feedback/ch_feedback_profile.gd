class_name ChFeedbackProfile extends Resource

# One feedback kind as data: what a beat does to the screen. The `.tres` files under
# game/feedback/profiles/ are the tuning surface; the manager reads them and nothing else.
# The two kick fields are beat amplitudes, not impulses: `scale_kick` is how far the scale moves
# from 1.0 (0.10 = ten percent), and `rotation_kick_deg` is that tilt in degrees — a magnitude, so
# the manager picks the sign per play.

@export var scale_kick: float = 0.0
@export var rotation_kick_deg: float = 0.0
# May contain `%d`, which later tasks fill with the overrides' `amount`.
@export var text: String = ""
@export var text_color: Color = Color.WHITE
@export var particle_count: int = 0
@export var particle_color: Color = Color.WHITE
# Cells per second.
@export var particle_speed: float = 30.0
@export var shake: float = 0.0
