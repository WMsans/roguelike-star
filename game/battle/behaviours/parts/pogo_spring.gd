extends ChBehaviour

# The Pogo Spring (U75): the press jumps, and the next landing deals 30 to every enemy part whose box
# is underneath the hull. Only the jump's own landing pays: a landing the spring did not fire for is
# not its jump, so the part is armed by fire() and disarmed by the landing that follows.

const LAUNCH := 700.0  # impulse up
const DAMAGE := 30
const BELOW := 8.0  # cells under the hull's box that count as underneath

var _jumping := false  # fired, waiting for the landing that pays


func setup(ctx: ChBattleContext) -> void:
	ctx.bus.subscribe(self, ChEvent.LANDED, func(event: ChEvent): _landed(ctx, event))


func fire(ctx: ChBattleContext) -> void:
	ctx.push(ctx.own(part), Vector2(0.0, -LAUNCH))
	_jumping = true


func _landed(ctx: ChBattleContext, event: ChEvent) -> void:
	if not _jumping or event.side != part.side:
		return
	_jumping = false
	var own := ctx.own(part)
	if own == null:
		return
	var hull := own.status_box()
	for foe in _enemy_parts(ctx):
		if not _underneath(foe.status_box(), hull):
			continue
		ctx.deal_hit(part, foe.body, DAMAGE)


# The box starts at or under the hull's bottom edge, no more than BELOW further down, and overlaps
# the hull across it.
func _underneath(box: Rect2, hull: Rect2) -> bool:
	if box.position.y < hull.end.y or box.position.y > hull.end.y + BELOW:
		return false
	return box.position.x < hull.end.x and box.end.x > hull.position.x
