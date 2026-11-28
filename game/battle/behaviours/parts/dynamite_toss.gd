extends ChBehaviour

# The Dynamite Toss (C27): a lit stick lobbed under LOB_GRAVITY. On landing it starts a 2 s fuse in
# the fight's own list, so the blast comes even if the Toss is broken before it goes off (Review
# Focus 3). The stick's damage is the def's 50, which the row carries.
const SPEED := 60.0  # cells per second along the lob's line
const FUSE_SECONDS := 2.0
const DIG := 2  # the ground the small blast chews

func fire(ctx: ChBattleContext) -> void:
	_lob(ctx, SPEED, func(shot: Dictionary): _landed(ctx, shot))

func _landed(ctx: ChBattleContext, shot: Dictionary) -> void:
	ctx.fuses.append({
		"part": part,
		"at": Vector2(shot.get("position", part.anchor_world())),
		"left": FUSE_SECONDS,
		"size": &"small",
		"damage": part.def.damage,
		"dig": DIG,
	})
