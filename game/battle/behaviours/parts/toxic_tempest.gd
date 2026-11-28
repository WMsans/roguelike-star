extends ChBehaviour

# The Toxic Tempest (R23): every gas within 40 cells of the part is blown onto the enemy hull, one
# cell at a time, for up to a second. A gas already at the hull's centre has nowhere left to go.
const RANGE := 40  # cells around the part a gas can start in
const WINDOW := 1.0  # seconds the tempest keeps blowing
const SPEED := 64  # cells one blow can move a gas, the engine's cap

var _target := Vector2i.ZERO  # the enemy hull's centre
var _until := -1.0  # ctx.time the blowing stops
var _gas := {}  # material name -> true: the world's gas-class materials

func fire(ctx: ChBattleContext) -> void:
	var enemy := ctx.enemy_of(part)
	if enemy == null or ctx.world == null:
		return
	_target = Vector2i(ChBattle.hull_box(enemy).get_center())
	_until = ctx.time + WINDOW
	_gas.clear()
	for material in ctx.world.material_set.materials:
		if material.material_class == PixelMaterial.CLASS_GAS:
			_gas[material.name] = true

func process(ctx: ChBattleContext, _delta: float) -> void:
	if ctx.time >= _until or ctx.world == null or _gas.is_empty():
		return
	var centre := Vector2i(roundi(part.anchor_world().x), roundi(part.anchor_world().y))
	for dy in range(-RANGE, RANGE + 1):
		for dx in range(-RANGE, RANGE + 1):
			if dx * dx + dy * dy > RANGE * RANGE:
				continue
			var cell := centre + Vector2i(dx, dy)
			if not _gas.has(ctx.world.get_material_at(cell)):
				continue
			var step := _target - cell
			if step == Vector2i.ZERO:
				continue
			ctx.blow(Rect2i(cell, Vector2i.ONE),
				Vector2i(clampi(step.x, -SPEED, SPEED), clampi(step.y, -SPEED, SPEED)))
