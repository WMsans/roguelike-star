extends ChTest

# ChStatuses: pure stack logic, no world needed.


func _with(stacks: Dictionary) -> ChStatuses:
	var s := ChStatuses.new()
	for k in stacks:
		s.stacks[k] = stacks[k]
	return s


func test_flame_cancels_wet_first() -> void:
	var s := _with({ChStatuses.WET: 3})
	var r: Dictionary = s.gain(ChStatuses.FLAME, 5)
	assert_eq(s.count(ChStatuses.FLAME), 2, "5 Flame spends 3 on Wet and keeps 2")
	assert_eq(s.count(ChStatuses.WET), 0, "Wet is cancelled")
	assert_eq(r.added, 2, "added is the remainder")
	assert_eq(r.cancelled, [[&"wet", 3]], "the cancel is reported")
	_complete()


func test_oil_doubles_flame() -> void:
	var s := _with({ChStatuses.OIL: 2})
	var r: Dictionary = s.gain(ChStatuses.FLAME, 5)
	assert_eq(s.count(ChStatuses.FLAME), 7, "Oil adds its stacks to the Flame gained")
	assert_eq(s.count(ChStatuses.OIL), 0, "Oil is used up")
	assert_eq(r.doubled, 2, "doubled reports the extra")
	assert_eq(r.added, 7, "added includes the extra")
	_complete()


func test_oil_blocks_wet() -> void:
	var s := _with({ChStatuses.OIL: 3})
	var r: Dictionary = s.gain(ChStatuses.WET, 4)
	assert_eq(s.count(ChStatuses.WET), 0, "oil keeps water off")
	assert_eq(s.count(ChStatuses.OIL), 3, "Oil is untouched")
	assert_eq(r.added, 0, "nothing added")
	_complete()


func test_wet_doubles_freeze() -> void:
	var s := _with({ChStatuses.WET: 3})
	var r: Dictionary = s.gain(ChStatuses.FREEZE, 2)
	assert_eq(s.count(ChStatuses.FREEZE), 4, "Wet doubles the Freeze gained")
	assert_eq(s.count(ChStatuses.WET), 1, "Wet pays for it")
	assert_eq(r.doubled, 2, "doubled reports the extra")
	_complete()


func test_freeze_cancels_flame() -> void:
	var s := _with({ChStatuses.FLAME: 4})
	s.gain(ChStatuses.FREEZE, 6)
	assert_eq(s.count(ChStatuses.FLAME), 0, "Flame is cancelled")
	assert_eq(s.count(ChStatuses.FREEZE), 2, "the rest becomes Freeze")
	_complete()


func test_flame_cancels_wet_then_freeze() -> void:
	var s := _with({ChStatuses.WET: 2, ChStatuses.FREEZE: 3})
	var r: Dictionary = s.gain(ChStatuses.FLAME, 4)
	assert_eq(s.count(ChStatuses.WET), 0, "Wet goes first")
	assert_eq(s.count(ChStatuses.FREEZE), 1, "Freeze takes the rest")
	assert_eq(s.count(ChStatuses.FLAME), 0, "nothing left to add")
	assert_eq(r.cancelled, [[&"wet", 2], [&"freeze", 2]], "cancels in list order")
	_complete()


func test_wet_cancels_flame_then_acid() -> void:
	var s := _with({ChStatuses.FLAME: 1, ChStatuses.ACID: 4})
	s.gain(ChStatuses.WET, 3)
	assert_eq(s.count(ChStatuses.FLAME), 0, "Flame goes first")
	assert_eq(s.count(ChStatuses.ACID), 2, "Acid takes the rest")
	assert_eq(s.count(ChStatuses.WET), 0, "nothing left to add")
	_complete()


func test_speedup_and_slow_cancel() -> void:
	var s := _with({ChStatuses.SPEEDUP: 2})
	s.gain(ChStatuses.SLOW, 5)
	assert_eq(s.count(ChStatuses.SPEEDUP), 0, "Speedup is cancelled")
	assert_eq(s.count(ChStatuses.SLOW), 3, "the rest is Slow")
	_complete()


func test_decay_skips_block_wet_oil() -> void:
	var s := _with({ChStatuses.FLAME: 1, ChStatuses.BLOCK: 5, ChStatuses.WET: 2, ChStatuses.OIL: 1, ChStatuses.SHOCK: 3})
	assert_eq(s.decay(), [&"flame"] as Array[StringName], "only Flame reached 0")
	assert_eq(s.count(ChStatuses.BLOCK), 5, "Block stays")
	assert_eq(s.count(ChStatuses.WET), 2, "Wet stays")
	assert_eq(s.count(ChStatuses.OIL), 1, "Oil stays")
	assert_eq(s.count(ChStatuses.SHOCK), 2, "Shock decays")
	_complete()


func test_absorb_partial_and_full() -> void:
	var s := _with({ChStatuses.BLOCK: 40})
	assert_eq(s.absorb(100), 40, "all 40 Block is used")
	assert_eq(s.count(ChStatuses.BLOCK), 0, "Block is gone")
	s = _with({ChStatuses.BLOCK: 150})
	assert_eq(s.absorb(100), 100, "Block covers the whole hit")
	assert_eq(s.count(ChStatuses.BLOCK), 50, "the rest of Block stays")
	_complete()


func test_material_gains() -> void:
	assert_eq(ChStatuses.material_gains({&"fire": 1}, 100), {&"flame": 2}, "fire gives 2 Flame")
	assert_eq(ChStatuses.material_gains({&"water": 60}, 100), {&"wet": 6}, "over half the area doubles")
	assert_eq(ChStatuses.material_gains({&"fire": 1, &"lava": 1}, 100), {&"flame": 8}, "same status adds up")
	assert_eq(ChStatuses.material_gains({&"sand": 50, &"burning": 0}, 100), {}, "unknown and empty give nothing")
	_complete()
