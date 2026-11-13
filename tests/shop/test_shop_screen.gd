extends ChTest

# Task 12: the shop screen. The routing methods are the seam the card and bar signals call, so every
# test drives them rather than reaching into a private render step. A stage is forced by writing the
# phase's picked state and items, which keeps the test off the run's RNG.
# CONTRACT: every test_* ends with _complete() because the runner counts that as the completion marker.

func _screen(seed := 7) -> ChShopScreen:
	var catalog := ChCatalog.load_default()
	var run := ChRun.start(seed, catalog)
	var screen := ChShopScreen.new()
	# Added before setup: the screen and the bar anchor themselves to the viewport on _ready, so their
	# rects are final and the bar's slots are at their real screen points.
	_parent().add_child(screen)
	screen.setup(run, catalog)
	return screen


func _force_shop(screen: ChShopScreen, id := &"wheel", price := 2) -> void:
	# A shop stage with one real card, so the price and rarity in the assertions are the phase's own.
	screen.phase.picked = {&"kind": &"shop", &"theme": &"weapon", &"resource": &""}
	screen.phase.items.clear()
	screen.phase.items.append({
		&"id": id,
		&"is_body": false,
		&"rarity": &"common",
		&"price": price,
		&"taken": false,
	})
	screen._render_stage()


func _shelf_part_cards(screen: ChShopScreen) -> Array[ChCard]:
	# The item cards on the shelf, in the order the row lays them out.
	var cards: Array[ChCard] = []
	for child in screen.stage_view.get_children():
		if child is ChPartCard:
			cards.append(child)
	return cards


func _shelf_part_ids(screen: ChShopScreen) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in _shelf_part_cards(screen):
		ids.append((card as ChPartCard).def.id)
	return ids

func _stage_item_cards(screen: ChShopScreen) -> Array[ChCard]:
	# Every item-card face on the stage, whatever card class it is drawn with.
	var cards: Array[ChCard] = []
	for child in screen.stage_view.get_children():
		if child is ChCard:
			cards.append(child)
	return cards

func _force_pack(screen: ChShopScreen) -> void:
	# A pack stage with three real parts, so the take rule is the phase's own.
	screen.phase.picked = {&"kind": &"pack", &"theme": &"weapon", &"resource": &""}
	screen.phase.items.clear()
	for id in [&"wheel", &"strut", &"cutter_rocket"]:
		screen.phase.items.append({
			&"id": id,
			&"is_body": false,
			&"rarity": &"common",
			&"price": 0,
			&"taken": false,
		})
	screen._render_stage()


func _bar_global(screen: ChShopScreen, rect: Rect2) -> Vector2:
	return screen.bar.get_global_transform_with_canvas() * rect.get_center()


func _free_path(screen: ChShopScreen) -> Array[int]:
	var body: ChBodyDef = screen.catalog.body(screen.run.layout.body_id)
	for index in body.slots.size():
		if not screen.run.layout.slots.has(index):
			var path: Array[int] = [index]
			return path
	return []


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func _under_card(label: Label) -> bool:
	var node := label.get_parent()
	while node != null:
		if node is ChCard:
			return true
		node = node.get_parent()
	return false


func _under_tooltip(label: Label) -> bool:
	var node := label.get_parent()
	while node != null:
		if node is ChPartTooltip:
			return true
		node = node.get_parent()
	return false


func test_drag_buy() -> void:
	var screen := _screen()
	_force_shop(screen)
	var gold_before := screen.run.gold
	var price: int = screen.phase.items[0][&"price"]
	screen._on_item_dropped(0, _bar_global(screen, screen.bar._slots[0]))
	assert_eq(screen.run.gold, gold_before - price, "the drop on a slot pays the price")
	assert_true(screen.run.inventory.part_ids.has(&"wheel"), "and the part is carried")
	assert_true(screen.phase.items[0][&"taken"], "the item is taken")
	_complete()


func test_drop_item_elsewhere_does_nothing() -> void:
	var screen := _screen()
	_force_shop(screen)
	var gold_before := screen.run.gold
	var carried_before := screen.run.inventory.part_ids.size()
	screen._on_item_dropped(0, Vector2(40, 40))
	assert_eq(screen.run.gold, gold_before, "a drop off the bar buys nothing")
	assert_eq(screen.run.inventory.part_ids.size(), carried_before, "and adds no part")
	assert_true(not screen.phase.items[0][&"taken"], "the item is still on the shelf")
	_complete()


func test_bought_card_leaves_the_shelf() -> void:
	var screen := _screen()
	# Two real cards, so the survivor's phase index is not its shelf position after the reflow.
	screen.phase.picked = {&"kind": &"shop", &"theme": &"weapon", &"resource": &""}
	screen.phase.items.clear()
	for id in [&"wheel", &"strut"]:
		screen.phase.items.append({
			&"id": id,
			&"is_body": false,
			&"rarity": &"common",
			&"price": ChPrices.price(&"common"),
			&"taken": false,
		})
	screen._render_stage()
	var both: Array[StringName] = [&"wheel", &"strut"]
	assert_eq(_shelf_part_ids(screen), both, "both cards start on the shelf")
	var price: int = screen.phase.items[0][&"price"]
	var gold_before := screen.run.gold
	var bought: ChCard = _shelf_part_cards(screen)[0]

	screen._on_item_clicked(0)
	assert_true(screen.phase.items[0][&"taken"], "the first card is bought")
	assert_eq(screen.run.gold, gold_before - price, "and its price is paid")
	var survivor: Array[StringName] = [&"strut"]
	assert_eq(_shelf_part_ids(screen), survivor, "the bought card leaves the shelf")
	assert_true(not bought.is_inside_tree(), "and its face is gone from the stage")

	# A second press where that card was is not a second buy.
	var gold_after := screen.run.gold
	screen._on_item_clicked(0)
	assert_eq(screen.run.gold, gold_after, "a second press on the taken card spends nothing")
	assert_eq(screen.run.inventory.part_ids.count(&"wheel"), 1, "and adds no second wheel")

	# The surviving card is now first on the shelf but is still phase item 1, so it buys the strut.
	_shelf_part_cards(screen)[0].clicked.emit()
	assert_true(screen.phase.items[1][&"taken"], "the shifted card buys its own item")
	assert_true(screen.run.inventory.part_ids.has(&"strut"), "the strut is carried")
	assert_eq(screen.run.gold, gold_after - int(screen.phase.items[1][&"price"]),
		"and pays its own price")
	assert_true(_shelf_part_ids(screen).is_empty(), "the bought shelf is empty")
	_complete()


func test_pack_take_clears_the_shelf() -> void:
	var screen := _screen()
	_force_pack(screen)
	assert_eq(_stage_item_cards(screen).size(), 3, "the pack offers three cards")
	var carried_before := screen.run.inventory.part_ids.size()

	screen._on_item_clicked(0)
	assert_true(screen.phase.items[0][&"taken"], "the first card is taken")
	assert_eq(screen.run.inventory.part_ids.size(), carried_before + 1,
		"the pack grants one part")
	assert_true(_stage_item_cards(screen).is_empty(), "a spent pack leaves no card on the shelf")

	# Nothing is left on the shelf to click, and a further take spends nothing and adds nothing.
	var gold_after := screen.run.gold
	var carried_after := screen.run.inventory.part_ids.size()
	screen._on_item_clicked(1)
	screen._on_item_clicked(2)
	assert_eq(screen.run.gold, gold_after, "a further take spends nothing")
	assert_eq(screen.run.inventory.part_ids.size(), carried_after, "and adds no part")
	_complete()


func test_bar_to_sell() -> void:
	var screen := _screen()
	assert_true(screen.run.inventory.add(&"wheel"), "the wheel fits")
	screen.bar.refresh()
	var gold_before := screen.run.gold
	var carried_before := screen.run.inventory.part_ids.size()
	var value := ChPrices.sell_value(screen.catalog.part(&"wheel").rarity)
	screen._on_bar_dropped(0, _bar_global(screen, screen.bar._sell))
	assert_eq(screen.run.gold, gold_before + value, "SELL pays the part's sell value")
	assert_eq(screen.run.inventory.part_ids.size(), carried_before - 1,
		"and the inventory shrinks")
	_complete()


func test_bar_reorder() -> void:
	var screen := _screen()
	for id in [&"wheel", &"strut", &"cutter_rocket"]:
		assert_true(screen.run.inventory.add(id), "%s fits" % [id])
	screen.bar.refresh()
	screen._on_bar_dropped(0, _bar_global(screen, screen.bar._slots[2]))
	var expected: Array[StringName] = [&"strut", &"cutter_rocket", &"wheel"]
	assert_eq(screen.run.inventory.part_ids, expected,
		"dropping the first card on slot 2 moves it behind the other two")
	_complete()


func test_bar_to_pit_mounts() -> void:
	var screen := _screen()
	assert_true(screen.run.inventory.add(&"strut"), "the strut fits")
	screen.bar.refresh()
	screen._on_toggle()
	assert_true(screen.garage.visible, "the garage is shown")
	var path := _free_path(screen)
	assert_true(not path.is_empty(), "the starting build leaves a free slot")
	var at: Vector2 = screen.garage.get_global_transform_with_canvas() \
		* screen.garage.screen_of(path)
	screen._on_bar_dropped(0, at)
	assert_true(screen.run.layout.get_node(path) != null, "the part is mounted in the free slot")
	assert_eq(screen.run.inventory.part_ids.size(), 0, "and left the inventory")
	_complete()


func test_toggle_keeps_stage() -> void:
	var screen := _screen()
	screen._on_option_clicked(0)
	assert_true(not screen.phase.picked.is_empty(), "the option committed the stage")
	var stage := screen.phase.stage
	var items: Array[Dictionary] = screen.phase.items.duplicate(true)
	screen._on_toggle()
	screen._on_toggle()
	assert_eq(screen.phase.stage, stage, "the toggle leaves the stage alone")
	assert_eq(screen.phase.items, items, "and the items exactly as they were")
	assert_true(screen.stage_view.visible, "the shop is showing again")
	assert_true(not screen.garage.visible, "and the garage hidden")
	_complete()


func test_next_to_fight() -> void:
	var screen := _screen()
	var fights: Array = []
	screen.fight_requested.connect(func() -> void: fights.append(true))
	screen._on_next()
	screen._on_next()
	screen._on_next()
	assert_eq(screen.next_button.text, "Fight", "after stage four the button reads Fight")
	assert_eq(fights.size(), 0, "and nothing has asked for a fight yet")
	screen._on_next()
	assert_eq(fights.size(), 1, "the fourth press asks for the fight")
	_complete()


func test_shelf_drag_highlights_the_bar_without_a_price() -> void:
	# Finding 2: a shelf card's drag was wired to nothing, so the accepting zones never rimmed. A shop
	# item is bought, never sold back, so SELL must stay unrimmed and its label unpriced.
	var screen := _screen()
	_force_shop(screen)
	var card: ChCard = _shelf_part_cards(screen)[0]
	var p := card.get_global_transform_with_canvas() * (card.size * 0.5)
	card.press(p)
	card.move(p + Vector2(0, 10))
	assert_true(card.dragging, "10 px past the grab is a drag")
	assert_true(screen.bar._highlighted, "the bar's accepting zones are rimmed")
	assert_eq(screen.bar.sell_label.text, "SELL", "and SELL offers no price for a shop item")
	card.release(p + Vector2(0, 10))
	assert_true(not screen.bar._highlighted, "the release clears the rims")
	_complete()


func test_shelf_hover_shows_the_part_tooltip() -> void:
	# Finding 3: a part on offer had no readable name, cost or bullets after the strip became the bar.
	var screen := _screen()
	_force_shop(screen)
	var card: ChCard = _shelf_part_cards(screen)[0]
	card.mouse_entered.emit()
	assert_true(screen.tooltip.visible, "hovering a shelf card shows its part")
	assert_eq(screen.tooltip.def.id, &"wheel", "with the card's own part")
	card.mouse_exited.emit()
	assert_true(not screen.tooltip.visible, "and leaving it hides the tooltip")
	_complete()


func test_minimal_hud() -> void:
	var screen := _screen()
	var labels: Array[Label] = []
	_collect_labels(screen, labels)
	var kept: Array[Label] = []
	for label in labels:
		if _under_card(label) or _under_tooltip(label):
			continue
		kept.append(label)
	assert_eq(kept.size(), 2, "the chrome has exactly two labels")
	assert_true(kept.has(screen.gold_label), "the gold readout is one")
	assert_true(kept.has(screen.bar.sell_label), "and the bar's sell label the other")
	_complete()
