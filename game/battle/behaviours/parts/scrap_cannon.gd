extends ChBehaviour

# The Scrap Cannon (U65): 30 damage a shot, and every part sold while it is owned adds 5 damage
# permanently. The bonus is kept in the instance's run state and reaches the hit through
# ChPartRuntime.bonus_damage, so the battle adds it to the row's 30 without rewriting the def.
const DAMAGE_PER_SOLD := 5
const SPEED := 200.0  # cells per second along facing()

func run_event(_run: ChRun, state: Dictionary, type: StringName, _data: Dictionary) -> void:
	# The sold part hears "sold_self" instead, so a sale that reaches here is another part's.
	if type == &"sold":
		state[&"damage_bonus"] = int(state.get(&"damage_bonus", 0)) + DAMAGE_PER_SOLD

func setup(_ctx: ChBattleContext) -> void:
	part.bonus_damage = int(part.state.get(&"damage_bonus", 0))

func fire(ctx: ChBattleContext) -> void:
	_shoot(ctx, SPEED, 0.0, func(shot: Dictionary): _impact(ctx, shot))

func _impact(ctx: ChBattleContext, shot: Dictionary) -> void:
	var met: Object = shot.get("collider")
	if met != null and is_instance_valid(met):
		# deal_hit adds part.bonus_damage before anything else reads the hit.
		ctx.deal_hit(part, met, part.def.damage)
