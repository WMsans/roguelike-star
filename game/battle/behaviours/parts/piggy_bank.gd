extends ChBehaviour

# The Piggy Bank (U64): a win banks +1 sell value, permanently, on this copy of the part.
const SELL_VALUE := 1

func run_event(_run: ChRun, state: Dictionary, type: StringName, _data: Dictionary) -> void:
	if type == &"won":
		state[&"sell_bonus"] = int(state.get(&"sell_bonus", 0)) + SELL_VALUE
