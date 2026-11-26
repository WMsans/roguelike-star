extends ChTest

func test_entries_order_and_zero_skip() -> void:
	var st := ChStatuses.new()
	st.stacks[&"shock"] = 2
	st.stacks[&"flame"] = 3
	st.stacks[&"block"] = 0
	assert_eq(ChStatusBadge.entries(st), [[&"flame", 3], [&"shock", 2]])
	_complete()
