extends ChBehaviour

# The Mine Layer (U46): drops a mine 4 cells behind the hull. The mine is a record in the fight's own
# fuse list, so it outlives this part, and the record is still the layer's: the blast it sets off is
# owned by the layer's side. A 3x3 sprite marks where it waits; the fight's fuse tick frees it.
const BEHIND := 4.0  # cells behind the hull's back edge
const MINE_RANGE := 10.0  # cells: an enemy part's box this close sets it off
const MINE_SIZE := &"medium"
const MINE_DAMAGE := 60
const MINE_DIG := 4
const MARK := 3  # cells across the placeholder sprite

func fire(ctx: ChBattleContext) -> void:
	var own := ctx.own(part)
	if own == null or ctx.world == null:
		return
	# Behind is the hull's own back edge plus BEHIND, along the way the part faces, so a mirrored
	# side drops its mine on its own back too.
	var hull := _hull_box(own)
	var at := hull.get_center() - part.facing() * (0.5 * hull.size.x + BEHIND)
	var mark := Sprite2D.new()
	mark.texture = ChTextures.box(MARK, MARK, part.def.color)
	mark.z_index = ChFx.Z
	mark.position = at
	ctx.world.add_child(mark)
	ctx.fuses.append({
		"part": part,
		"at": Vector2(at),
		"left": INF,  # a mine has no clock; _tick_fuses reads its `mine` range instead
		"size": MINE_SIZE,
		"damage": MINE_DAMAGE,
		"dig": MINE_DIG,
		"mine": MINE_RANGE,
		"node": mark,
	})
