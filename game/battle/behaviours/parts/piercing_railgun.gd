extends ChBehaviour

# The Piercing Railgun (R19): one shot down the line from its nose. Every enemy part the line
# crosses takes an equal share of 500; a line that crosses no part pays the hull the whole 500.
const ON_LINE := 2.0  # cells about a part's anchor height that the line still crosses

func fire(ctx: ChBattleContext) -> void:
	var foe := ctx.enemy_of(part)
	if foe == null or foe.chassis == null:
		return
	var from := _nose(part.facing())
	var dir := part.facing()
	var across := Vector2(-dir.y, dir.x)
	var targets: Array[ChPartRuntime] = []
	for other in _enemy_parts(ctx):
		var to := other.anchor_world() - from
		# "at its anchor's height ±2 cells": the anchor has to sit near the line, and the box has to
		# reach past the nose, so a part behind the muzzle is not on it.
		if absf(to.dot(across)) > ON_LINE:
			continue
		var box := _part_box(other)
		var half := absf(dir.x) * box.size.x * 0.5 + absf(dir.y) * box.size.y * 0.5
		if to.dot(dir) + half < 0.0:
			continue
		targets.append(other)
	if targets.is_empty():
		ctx.deal_hit(part, foe.chassis, part.def.damage)
		return
	var share := floori(float(part.def.damage) / targets.size())
	for other in targets:
		ctx.deal_hit(part, other.body, share)
