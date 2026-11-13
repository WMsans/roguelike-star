class_name ChShopPhase extends RefCounted

# The shop phase between fights (spec §Shop phase). Stage 1 is the reward credit and has no screen,
# stages 2..4 each show three option cards, and stage 5 is done. Rules only: the shop screen (Task 12)
# draws the cards, the gold readout and the beats, so there is no fight counter, stage label or
# capacity readout here.
# Every draw comes off run.rng, so a run seed replays the same shop.

# A theme is a tag a part carries, and it is in play only when enough distinct items match it, which is
# what keeps Defence, Ice, Attack and the rest out until there are parts to fill them. `body` has no
# tag because bodies carry none: the theme is the fact that they are bodies.
const THEMES := {
	&"weapon": [&"weapon"],
	&"fire": [&"fire"],
	&"tricky": [&"tricky"],
	&"passive": [&"passive"],
	&"triggered": [&"triggered"],
	&"body": [],
}
const MIN_MATCHING := 3  # the spec's threshold for a theme appearing at all
const RESOURCE_GOLD := 4  # the extra gold card
const RESOURCE_HP := 100  # the revive health card, added to max HP for the rest of the run

var run: ChRun = null
var catalog: ChCatalog = null
var credited := 0  # stage 1: what opening the shop paid for the fight that just ended
var stage := 2
var options: Array[Dictionary] = []  # {kind: &"shop"|&"pack"|&"resource", theme, resource}
var picked: Dictionary = {}  # the card this stage committed to; empty until it does
var items: Array[Dictionary] = []  # {id, is_body, rarity, price, taken}
var rerolled := false
var auto_sold: Array[StringName] = []  # parts a body swap left with nowhere to go, sold at once; every
# swap in the stage appends to it and next() clears it, so the screen reads the whole stage's beats
var _last_themes: Array[StringName] = []  # the previous stage's two cards, which this one excludes


func _init(p_run: ChRun, p_catalog: ChCatalog) -> void:
	# The caller hands the shop the run's own catalog: ChCatalog.load_default() builds a new one per
	# call, and a second one would price and HP-read a different table than the run holds.
	run = p_run
	catalog = p_catalog
	credited = run.reward(run.fight_index)
	run.gold += credited
	_roll_options()


func done() -> bool:
	return stage > 4


func available_themes() -> Array[StringName]:
	# Data-driven: a theme is in play when MIN_MATCHING distinct defs match it, so a theme comes back
	# on its own once enough parts exist.
	var out: Array[StringName] = []
	for theme in THEMES:
		if _pool(theme).size() >= MIN_MATCHING:
			out.append(theme)
	return out


func pick(index: int) -> bool:
	# Committing to a card is the stage's one choice: after this, the stage shows what it offers.
	if not picked.is_empty() or index < 0 or index >= options.size():
		return false
	var option: Dictionary = options[index]
	match option["kind"]:
		&"shop":
			picked = option
			_roll_items(option)
		&"pack":
			# The 3 gold buys the pack when it is opened, whether or not anything is taken from it,
			# so skipping the pack with Next spends it and gains nothing.
			if run.gold < ChPrices.PACK:
				return false
			run.gold -= ChPrices.PACK
			picked = option
			_roll_items(option)
		&"resource":
			if option["resource"] == &"hp":
				run.hp_bonus += RESOURCE_HP
			else:
				run.gold += RESOURCE_GOLD
			picked = option
	return true


func buy(item_index: int) -> bool:
	# The shop's action: pay the price, take the card. A part needs a free slot; a body needs none, and
	# the swap it triggers can push parts off the hull (see _mount_body).
	var item := _offer(item_index)
	if item.is_empty() or picked.get(&"kind") != &"shop" or item[&"taken"]:
		return false
	var price: int = item[&"price"]
	# Gold exactly equal to the price is the allowed edge and lands on 0; one short is refused, so gold
	# never goes negative.
	if run.gold < price:
		return false
	if not item[&"is_body"] and run.inventory.free_slots() < 1:
		return false
	run.gold -= price
	item[&"taken"] = true
	if item[&"is_body"]:
		_mount_body(item[&"id"])
	else:
		run.inventory.add(item[&"id"])
	return true


func take(item_index: int) -> bool:
	# The pack's action: one card, free. After Next the stage is no longer picked, so this refuses and
	# a skipped pack has gained nothing.
	var item := _offer(item_index)
	if item.is_empty() or picked.get(&"kind") != &"pack" or item[&"taken"]:
		return false
	for offered in items:
		if offered[&"taken"]:
			return false  # a pack grants one card, and any taken card says it already did
	if not item[&"is_body"] and run.inventory.free_slots() < 1:
		return false
	item[&"taken"] = true
	if item[&"is_body"]:
		_mount_body(item[&"id"])
	else:
		run.inventory.add(item[&"id"])
	return true


func reroll() -> bool:
	# One reroll per shop stage, for 3 gold. A pack has none.
	if picked.get(&"kind") != &"shop" or rerolled or run.gold < ChPrices.REROLL:
		return false
	run.gold -= ChPrices.REROLL
	rerolled = true
	_roll_items(picked)
	return true


func sell(inventory_index: int) -> int:
	# Selling works at any stage and in either view; the value is the carried part's rarity through the
	# price table, which is floor(price / 2).
	var ids: Array[StringName] = run.inventory.part_ids
	if inventory_index < 0 or inventory_index >= ids.size():
		return 0
	var def: ChPartDef = catalog.part(ids[inventory_index])
	if def == null:
		# No def means no rarity, so no price: the part stays carried rather than vanishing for 0.
		return 0
	run.inventory.remove_at(inventory_index)
	var value := ChPrices.sell_value(def.rarity)
	run.gold += value
	return value


func next() -> void:
	# Next leaves the stage whether or not anything was picked, and the new stage offers new cards.
	stage += 1
	_last_themes.clear()
	# Only the two theme cards are excluded from the next stage; the resource card has no theme.
	for i in mini(2, options.size()):
		_last_themes.append(options[i][&"theme"])
	picked = {}
	items.clear()
	auto_sold.clear()
	rerolled = false
	options.clear()
	if not done():
		_roll_options()


func _roll_options() -> void:
	# Cards 1 and 2 are themes the previous stage did not offer, never the same theme twice; card 3 is a
	# resource. Which of the two theme cards is a shop and which a pack is the draw's call.
	var pool := available_themes()
	if pool.size() < 2:
		# shortcut: with two themes or fewer in play there is no way to show two different ones. The
		# slice has six; a catalog that thin is the catalog test's problem, not a rule to write here.
		return
	var fresh: Array[StringName] = []
	for theme in pool:
		if not _last_themes.has(theme):
			fresh.append(theme)
	if fresh.size() < 2:
		# shortcut: reachable only once every theme in play has been offered; repeating one beats
		# showing a card with no theme behind it.
		fresh = pool
	var deck: Array[StringName] = fresh.duplicate()
	for i in 2:
		var theme: StringName = deck.pop_at(run.rng.randi_range(0, deck.size() - 1))
		var kind: StringName = &"shop" if run.rng.randf() < 0.5 else &"pack"
		options.append({&"kind": kind, &"theme": theme, &"resource": &""})
	options.append({
		&"kind": &"resource",
		&"theme": &"",
		&"resource": &"hp" if run.rng.randf() < 0.5 else &"gold",
	})


func _roll_items(option: Dictionary) -> void:
	# Three cards: a rarity from the 60/30/10 weights, then one of the theme's defs at that rarity.
	items.clear()
	var pool := _pool(option[&"theme"])
	for i in 3:
		var rarity: StringName = ChPrices.roll_rarity(run.rng)
		var at_rarity: Array = []
		for candidate in pool:
			if candidate.rarity == rarity:
				at_rarity.append(candidate)
		if at_rarity.is_empty():
			# The theme has nothing at that rarity (no passive rare, one body per rarity), so any item
			# in the theme will do rather than leaving a hole in the row.
			at_rarity = pool
		var def = at_rarity[run.rng.randi_range(0, at_rarity.size() - 1)]
		items.append({
			&"id": def.id,
			&"is_body": def is ChBodyDef,
			&"rarity": def.rarity,
			&"price": ChPrices.price(def.rarity),
			&"taken": false,
		})


func _pool(theme: StringName) -> Array:
	# The defs a theme offers, read off the catalog the run holds.
	if theme == &"body":
		var bodies: Array = []
		for id in catalog.bodies:
			bodies.append(catalog.bodies[id])
		return bodies
	var out: Array = []
	for id in catalog.parts:
		var part: ChPartDef = catalog.parts[id]
		for tag in THEMES[theme]:
			if part.tags.has(tag):
				out.append(part)
				break
	return out


func _offer(item_index: int) -> Dictionary:
	# The card at that index; an empty Dictionary says there is no such card.
	if item_index < 0 or item_index >= items.size():
		return {}
	return items[item_index]


func _mount_body(id: StringName) -> void:
	# A bought body goes in at once. swap_body reseats what fits and hands back the subtrees that found
	# no slot, already detached, so every part of the old build is in exactly one pile afterwards:
	# what it detached lands in the inventory until it is full, and the rest is sold on the spot.
	# auto_sold is not cleared here: a stage can buy two bodies, and the screen reads one list holding
	# both swaps.
	for branch in run.layout.swap_body(catalog.body(id), catalog):
		for part_id in run.layout.subtree_part_ids(branch):
			if run.inventory.add(part_id):
				continue
			var def: ChPartDef = catalog.part(part_id)
			# A part with no def cannot be priced, so it is the one thing this swap can lose; the
			# catalog keeps every mountable id, so it does not happen in a run.
			if def != null:
				run.gold += ChPrices.sell_value(def.rarity)
			auto_sold.append(part_id)
