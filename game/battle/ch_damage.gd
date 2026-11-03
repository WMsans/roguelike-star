class_name ChDamage extends RefCounted

# The damage rules (spec §5.7), as static functions over plain values: no state, no world, so
# deal_hit (Task 10), the part behaviours (Tasks 12–14) and the battle loop (Task 15) can call
# them from anywhere.
# A hit on a part is the user's decision: chariot HP loses the FULL damage and the part hit also
# loses integrity, so parts wear down and can break but never shield HP. Multipliers such as the
# Mace's ×3 apply to the HP damage only, never to the part's wear.
# Rounding is Godot's round(), which rounds half away from zero.
# shortcut: HP is clamped at 0 here and never goes negative; nothing revives at 0, so a caller
# that wants an overkill amount has to read hp_damage rather than the HP delta.


# hp_damage is the damage dealt, not the HP actually lost: on a finishing hit HP clamps to 0 while
# hp_damage still reports the full amount, which is what the HIT event payload wants.
static func hit_part(target_hp: int, part_integrity: int, damage: int, multiplier: float = 1.0,
	wear_ratio: float = 0.5) -> Dictionary:
	var hp_damage := int(round(damage * multiplier))
	var wear := int(round(damage * wear_ratio))
	return {
		"hp": maxi(0, target_hp - hp_damage),
		"integrity": maxi(0, part_integrity - wear),
		"hp_damage": hp_damage,
	}


static func hit_body(target_hp, damage, multiplier := 1.0) -> int:
	# Untyped on purpose: chariot HP is a float once burning runs (burn_tick returns float), so a
	# hit has to accept it and hand back an int.
	return maxi(0, target_hp - int(round(damage * multiplier)))


# Burning is chariot-wide: a burning chariot loses dps * delta once per tick while ANY of its
# parts burns, not once per burning part, so three burning parts burn no harder than one.
static func burn_tick(hp: int, burning_parts: int, delta: float, dps := 5.0) -> float:
	if burning_parts == 0:
		# A chariot with nothing burning is unharmed, whatever the tick length.
		return hp
	return maxf(0.0, hp - dps * delta)


# The Mace's Shatter (spec §5.4): ×3 damage against a frozen part, ×1 against anything else.
static func shatter_multiplier(target_frozen: bool) -> float:
	return 3.0 if target_frozen else 1.0
