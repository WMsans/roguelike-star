extends ChBehaviour

# The Safe (U66): +1 inventory slot out of battle, and 3 gold when this copy is sold.
const SLOT := 1
const GOLD := 3

func run_stat(_run: ChRun, _state: Dictionary, stat: StringName, value: int) -> int:
	if stat == ChRun.STAT_INVENTORY_CAPACITY:
		return value + SLOT
	return value

func run_event(run: ChRun, _state: Dictionary, type: StringName, _data: Dictionary) -> void:
	# A sale's own part is announced separately, so this is the only place the Safe hears about itself.
	if type == &"sold_self":
		run.gold += GOLD
