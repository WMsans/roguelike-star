class_name ChDamage extends RefCounted

# The damage rules (spec §5.7), as static functions over plain values: no state, no world, so
# deal_hit (Task 10), the part behaviours (Tasks 12–14) and the battle loop (Task 15) can call
# them from anywhere.
# A hit on a part is the user's decision: chariot HP loses the full damage past the holder's Block
# and the part hit also loses integrity, so parts wear down and can break; only Block shields HP.
# Multipliers such as the Mace's ×3 apply to the HP damage only, never to the part's wear.
# Rounding is Godot's round(), which rounds half away from zero.
# shortcut: HP is clamped at 0 here and never goes negative; nothing revives at 0, so a caller
# that wants an overkill amount has to read hp_damage rather than the HP delta.


# hp_damage is the damage dealt, not the HP actually lost: on a finishing hit HP clamps to 0 while
# hp_damage still reports the full amount, which is what the HIT event payload wants.
# block_mult multiplies what Block spends on the share of the hit it soaks (U23's Etching Ray is 2),
# so the pool runs out that many times faster while the HP behind it is untouched.
static func hit_part(target_hp: int, part_integrity: int, damage: int, multiplier: float = 1.0,
	wear_ratio: float = 0.5, block: int = 0, block_mult: float = 1.0) -> Dictionary:
	# Block absorbs first; wear scales with the share of the hit that got past it.
	var effective := int(round(damage * multiplier))
	var absorbed := mini(block, effective)
	var spent := mini(block, int(round(absorbed * block_mult)))
	var hp_damage := effective - absorbed
	var wear := int(round(damage * wear_ratio * hp_damage / effective)) if effective > 0 \
		else int(round(damage * wear_ratio))
	return {
		"hp": maxi(0, target_hp - hp_damage),
		"integrity": maxi(0, part_integrity - wear),
		"hp_damage": hp_damage,
		"block": block - spent,
	}


static func hit_body(target_hp, damage, multiplier := 1.0, block := 0,
	block_mult := 1.0) -> Dictionary:
	var effective := int(round(damage * multiplier))
	var absorbed := mini(block, effective)
	var spent := mini(block, int(round(absorbed * block_mult)))
	var hp_damage := effective - absorbed
	return {"hp": maxi(0, target_hp - hp_damage), "hp_damage": hp_damage,
		"block": block - spent}


# The Mace's Shatter (spec §5.4): ×3 damage against a frozen part, ×1 against anything else.
static func shatter_multiplier(target_frozen: bool) -> float:
	return 3.0 if target_frozen else 1.0
