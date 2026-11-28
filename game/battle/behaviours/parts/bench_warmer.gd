extends ChBehaviour

# The Bench Warmer (R30): +1 inventory slot, and the carried passives fight from the bench. The
# bench itself is ChRun.player_layout's walk; this behaviour only owns the slot.
const SLOT := 1

func run_stat(_run: ChRun, _state: Dictionary, stat: StringName, value: int) -> int:
	if stat == ChRun.STAT_INVENTORY_CAPACITY:
		return value + SLOT
	return value
