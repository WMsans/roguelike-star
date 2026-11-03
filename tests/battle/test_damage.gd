extends ChTest

# Task 7: the damage rules (spec §5.7). Pure logic, so no make_world here.
# The part-hit rule is the user's decision: a hit on a part lowers chariot HP by the FULL damage
# and the part hit also loses integrity, so parts wear down and break but never shield HP.
# shortcut: damage/multiplier/decay numbers are literals per test; the tuning lives in the part
# defs and the behaviours (Tasks 12–14), not here.


func test_hit_part_full_hp_and_wear() -> void:
	var result: Dictionary = ChDamage.hit_part(500, 100, 20)
	assert_eq(result.hp, 480, "chariot HP takes the full unmultiplied damage")
	assert_eq(result.integrity, 90, "the hit part loses integrity at the 0.5 wear ratio")
	assert_eq(result.hp_damage, 20, "the hit reports the HP damage it dealt")
	_complete()


func test_multiplier_hp_only() -> void:
	# The Mace's x3 covers HP only: the part still wears at its own rate.
	var result: Dictionary = ChDamage.hit_part(500, 100, 20, 3.0)
	assert_eq(result.hp, 440, "20 damage at x3 is 60 off HP")
	assert_eq(result.integrity, 90, "the multiplier does not apply to wear")
	assert_eq(result.hp_damage, 60, "the multiplied HP damage is what the hit reports")
	# hit_body is the same HP rule with no part involved.
	assert_eq(ChDamage.hit_body(500, 20, 3.0), 440, "the same x3 rule off a part")
	_complete()


func test_clamps_zero() -> void:
	# A hit bigger than what is left breaks the part and the chariot without going negative.
	var result: Dictionary = ChDamage.hit_part(10, 5, 20)
	assert_eq(result.hp, 0, "10 HP cannot go under 0")
	assert_eq(result.integrity, 0, "5 integrity cannot go under 0")
	assert_eq(result.hp_damage, 20, "the damage dealt is still the full 20")
	assert_eq(ChDamage.hit_body(10, 100), 0, "chariot HP clamps the same way")
	_complete()


func test_burn_once_not_per_part() -> void:
	# Burning is a chariot-wide DoT: it ticks once while any part burns, so 3 burning parts burn
	# no harder than 1.
	assert_near(ChDamage.burn_tick(100, 3, 1.0), 95.0, 0.001, "3 burning parts still cost one 5/s tick")
	assert_near(ChDamage.burn_tick(100, 1, 1.0), 95.0, 0.001, "one burning part costs the same tick")
	assert_near(ChDamage.burn_tick(100, 0, 1.0), 100.0, 0.001, "nothing burning does nothing")
	assert_near(ChDamage.burn_tick(100, 3, 0.5), 97.5, 0.001, "the burn scales with the tick length")
	assert_near(ChDamage.burn_tick(2, 3, 1.0), 0.0, 0.001, "2 HP cannot burn under 0")
	_complete()


func test_shatter() -> void:
	# The Mace's Shatter: x3 against a frozen part, x1 against anything else.
	assert_near(ChDamage.shatter_multiplier(true), 3.0, 0.001, "a frozen part shatters at x3")
	assert_near(ChDamage.shatter_multiplier(false), 1.0, 0.001, "unfrozen takes the hit normally")
	_complete()
