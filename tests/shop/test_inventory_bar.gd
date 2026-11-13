extends ChTest

# Task 11: the inventory bar. The bottom 172 px strip of the 1280x720 screen: five slot rects on the
# left, a SELL zone on the right, and one ChPartCard per carried part in its own slot. The tests drive
# the bar's interface (setup/refresh, the two hit tests and the sell label) rather than a mouse: the
# headless runner has no pointer, and every rule the bar owns is a plain function.
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


func _collect_labels(node: Node, into: Array[Label]) -> void:
	for child in node.get_children():
		if child is Label:
			into.append(child)
		_collect_labels(child, into)


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
	assert_eq(labels.size(), 1, "the bar adds no capacity counter: only the sell label")
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
	# A drag over SELL shows what the card is worth; the label rests on SELL otherwise.
	var wheel := ChCatalog.load_default().part(&"wheel")
	bar.highlight(wheel)
	bar._update_sell_label(sell_centre)
	assert_eq(bar.sell_label.text, "+$%d" % ChPrices.sell_value(wheel.rarity),
		"over SELL the label reads the sell value")
	bar._update_sell_label(_global(bar, bar._slots[0].get_center()))
	assert_eq(bar.sell_label.text, "SELL", "over a slot it reads SELL again")
	bar._update_sell_label(sell_centre)
	bar.clear_highlight()
	assert_eq(bar.sell_label.text, "SELL", "a cleared highlight rests on SELL")
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
