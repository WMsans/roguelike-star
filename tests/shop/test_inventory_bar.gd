extends ChTest

# Task 11: the inventory bar. The bottom 172 px strip of the 1280x720 screen: five slot rects on the
# left, a SELL zone on the right, and one ChPartCard per carried part in its own slot. Layout and hit
# tests read the bar's own rects; the click and the drop are driven through a real card's own seam
# (press/move/release, plus the motion the bar's _input reads), because that is the only way the
# wiring in _make_card/_on_card_drag_started/_on_card_dropped is exercised at all.
# CONTRACT: every test_* ends with _complete() because the runner counts that as the completion marker.
# The bar is placed away from the origin so a hit test that assumed global == bar-local would fail.

const AT := Vector2(24, 40)


func _inventory(ids: Array) -> ChInventory:
	var inventory := ChInventory.new()
	inventory.capacity = ChInventory.CAPACITY
	for id in ids:
		assert_true(inventory.add(id), "%s fits" % [id])
	return inventory


func _bar(ids: Array) -> ChInventoryBar:
	var bar := ChInventoryBar.new()
	# Added before it is set up: the bar anchors itself to the bottom of the screen on _ready, so its
	# rect is the real strip, and it is then moved away from the screen's origin.
	_parent().add_child(bar)
	bar.position = AT
	bar.setup(_inventory(ids), ChCatalog.load_default())
	return bar


func _global(bar: ChInventoryBar, local: Vector2) -> Vector2:
	# A point of the bar's own rect, in screen space: what a drag's release point is.
	return bar.get_global_transform_with_canvas() * local


# The card's own centre in screen space: the point a press or a release lands on.
func _centre_of(card: ChPartCard) -> Vector2:
	return card.get_global_transform_with_canvas() * (card.size * 0.5)


# A global-position mouse motion, which is what _input sees in the real game.
func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	# global_position is a virtual method on InputEvent: it only reads back what was set.
	event.set_global_position(at)
	return event


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


func _under_tooltip(label: Label) -> bool:
	var node := label.get_parent()
	while node != null:
		if node is ChPartTooltip:
			return true
		node = node.get_parent()
	return false


func test_cards_match_inventory() -> void:
	var bar := _bar([&"wheel", &"wheel", &"cutter_rocket"])
	assert_near(bar.size.y, ChInventoryBar.HEIGHT, 0.5, "the bar is the bottom strip")
	assert_eq(bar._cards.size(), 3, "three carried parts are three cards")
	assert_eq(bar._cards[0].part_id, &"wheel", "the first card is the first carried part")
	assert_eq(bar._cards[1].part_id, &"wheel", "a duplicate part is its own card")
	assert_eq(bar._cards[2].part_id, &"cutter_rocket", "and the order is the inventory's")
	assert_eq(bar._cards[2].price, -1, "the bar shows no price")
	assert_true(not bar._cards[2].show_count, "nor a count")
	assert_eq(bar._slots.size(), ChInventory.CAPACITY, "all five slots are drawn")
	for rect in bar._slots:
		assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "an empty slot has a rect")
	assert_true(bar._sell.size.x > 0.0, "and the sell zone has one")
	var labels: Array[Label] = []
	_collect_labels(bar, labels)
	var chrome: Array[Label] = []
	for label in labels:
		if not _under_tooltip(label):
			chrome.append(label)
	assert_eq(chrome.size(), 1, "the bar adds no capacity counter: only the sell label")
	assert_eq(bar.sell_label.text, "SELL", "which reads SELL at rest")
	_complete()


func test_slot_and_sell_hit() -> void:
	var bar := _bar([&"wheel"])
	for index in ChInventory.CAPACITY:
		var centre := _global(bar, bar._slots[index].get_center())
		assert_eq(bar.slot_index_at(centre), index, "slot %d hit-tests to its index" % index)
	var sell_centre := _global(bar, bar._sell.get_center())
	assert_true(bar.over_sell(sell_centre), "the sell rect's centre is over SELL")
	assert_eq(bar.slot_index_at(sell_centre), -1, "which is no slot")
	assert_true(not bar.over_sell(_global(bar, bar._slots[0].get_center())),
		"a slot is not SELL")
	assert_eq(bar.slot_index_at(_global(bar, Vector2(-40, -40))), -1, "off the bar is no slot")
	assert_eq(bar.sell_label.text, "SELL", "the label rests on SELL")
	_complete()


func test_card_click_announces_the_current_index() -> void:
	# A press and a release under the 6 px threshold are a click, and the index it names is read off
	# _cards when the click fires, not cached when the card was built.
	var bar := _bar([&"wheel", &"strut", &"cutter_rocket"])
	var clicks: Array = []
	bar.card_clicked.connect(func(index: int) -> void: clicks.append(index))
	var p := _centre_of(bar._cards[0])
	bar._cards[0].press(p)
	bar._cards[0].move(p + Vector2(3, 0))
	bar._cards[0].release(p + Vector2(3, 0))
	assert_eq(clicks, [0], "a card pressed and let go in place is a click on its index")
	# The inventory reorders: the same node is now the third part, and the click must say so.
	assert_true(bar.inventory.move(0, 2), "the wheel moves to the last slot")
	bar.refresh()
	assert_eq(bar._cards[2].part_id, &"wheel", "the wheel's own card is the third now")
	var q := _centre_of(bar._cards[2])
	bar._cards[2].press(q)
	bar._cards[2].move(q + Vector2(2, 0))
	bar._cards[2].release(q + Vector2(2, 0))
	assert_eq(clicks, [0, 2], "and the click reads the index it holds now, not the built one")
	_complete()


func test_card_drag_over_sell_labels_and_drops() -> void:
	# The whole drag path through a real card: drag_started rims the zones and starts the bar reading
	# the pointer, the motions price the hover, and the drop announces the part and where it landed
	# before putting the bar back to rest. Every step is the shipped connection, not a private call.
	var bar := _bar([&"wheel", &"strut"])
	var drops: Array = []
	bar.card_dropped.connect(func(index: int, at: Vector2) -> void: drops.append([index, at]))
	assert_true(bar.inventory.move(0, 1), "the wheel moves behind the strut")
	bar.refresh()
	var card := bar._cards[1]
	assert_eq(card.part_id, &"wheel", "the wheel is the card at index 1")
	assert_eq(bar.sell_label.text, "SELL", "the label rests on SELL before the drag")
	var p := _centre_of(card)
	card.press(p)
	card.move(p + Vector2(0, 10))
	assert_true(card.dragging, "10 px past the grab is a drag")
	assert_true(bar._drag_card == card, "the bar followed its own card's drag")
	assert_true(bar._drag_def == card.def, "and rims the accepting zones with the part it carries")
	# Over a slot the label rests; over SELL it prices the part. The motion over SELL comes last, so the
	# label is showing "+$N" at the release and only the drop can put it back.
	var sell_at := _global(bar, bar._sell.get_center())
	bar._input(_motion(_global(bar, bar._slots[0].get_center())))
	assert_eq(bar.sell_label.text, "SELL", "over a slot it reads SELL")
	bar._input(_motion(sell_at))
	assert_eq(bar.sell_label.text, "+$%d" % ChPrices.sell_value(card.def.rarity),
		"over SELL the label reads the part's sell value")
	card.release(sell_at)
	assert_eq(drops.size(), 1, "the release announced one drop")
	if not drops.is_empty():
		assert_eq(drops[0][0], 1, "with the index the inventory holds at that moment")
		assert_eq(drops[0][1], sell_at, "and the global point it was let go at")
	assert_eq(bar.sell_label.text, "SELL", "the drop clears the label back to SELL")
	assert_true(bar._drag_def == null, "and clears the zones' ACCENT rims")
	assert_true(bar._drag_card == null, "the bar stops following the pointer")
	_complete()


func test_hover_shows_the_part_tooltip() -> void:
	# Finding 3: a carried part's name, cost and bullets were unreadable after the strip became the
	# bar. The card's own hover signal is what the bar listens to in the shipped game.
	var bar := _bar([&"wheel"])
	var card := bar._cards[0]
	card.mouse_entered.emit()
	assert_true(bar.tooltip.visible, "hovering a carried card shows its part")
	assert_eq(bar.tooltip.def.id, &"wheel", "with that card's own part")
	card.mouse_exited.emit()
	assert_true(not bar.tooltip.visible, "leaving the card hides it")
	# A drag in hand hides it: the pointer is carrying something, not naming it.
	card.mouse_entered.emit()
	var p := _centre_of(card)
	card.press(p)
	card.move(p + Vector2(0, 10))
	assert_true(not bar.tooltip.visible, "and picking the card up hides it")
	_complete()


func test_refresh_keeps_nodes() -> void:
	var bar := _bar([&"wheel", &"strut", &"cutter_rocket"])
	var before := bar._cards.duplicate()
	assert_eq(before.size(), 3, "three cards to start")
	assert_true(bar.inventory.move(0, 2), "the wheel moves to the last slot")
	bar.refresh()
	assert_eq(bar._cards.size(), 3, "a reorder rebuilds no card")
	assert_true(bar._cards[0] == before[1], "the strut's node is first now")
	assert_true(bar._cards[1] == before[2], "the rocket's node is second")
	assert_true(bar._cards[2] == before[0], "the wheel's own node moved to the last slot")
	assert_eq(bar._cards[2].part_id, &"wheel", "and it is still the wheel")
	assert_near(bar._cards[2].position.x,
		bar._slots[2].get_center().x - bar._cards[2].size.x * 0.5, 0.5,
		"the reused card is repositioned onto its new slot")
	bar.refresh()
	assert_true(bar._cards[0] == before[1], "a second refresh changes nothing")
	assert_eq(bar._cards.size(), 3, "and still frees nothing")
	_complete()
