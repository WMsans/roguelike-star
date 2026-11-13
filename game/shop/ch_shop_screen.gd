class_name ChShopScreen extends Control

# Task 12: the run's shop screen, the middle of a run. It covers the 1280x720 viewport: gold at the top
# right, the garage/shop toggle on the centre-left, one middle area that shows either the stage content
# or the embedded ChGarage, the Next (or Fight) button under the stage, and the inventory bar along the
# bottom. The screen owns the routing the cards and the bar report to: it decides what a drop means and
# calls the phase's rules. The phase owns every price, roll and stage; the garage owns the pit.
# A toggle never mutates the phase: it swaps which child of middle is visible, so a picked stage survives
# a look at the build.

signal fight_requested

const GARAGE := "res://game/garage/garage.tscn"
const SCREEN := Vector2(1280, 720)  # the viewport the brief pins; the stage row centres on it
const ROW_CENTRE_Y := 300.0  # the option and item rows
const ROW_GAP := 20.0
const OPTION_W := 190.0
const OPTION_H := 104.0
const BODY_H := 170.0  # room for a name, a price and a hull at the pit's zoom
const BUTTON_TOP := 470.0  # Next sits under the stage content
const BUTTON_H := 44.0
const GOLD_POP_TIME := 0.6  # how long "+N" holds before the readout comes back

var run: ChRun = null
var catalog: ChCatalog = null
var phase: ChShopPhase = null
var gold_label: Label = null
var toggle: Button = null
var middle: Control = null
var stage_view: Control = null
var next_button: Button = null
var bar: ChInventoryBar = null
var garage: ChGarage = null

var _option_cards: Array[ChCard] = []  # the three faces, in phase.options order (for a refusal)
# The shelf, in row order: each entry is {&"card": ChCard, &"item_index": int}. Taken items leave the
# row but phase.items is never renumbered, so the survivor keeps its own index and refusal shake.
var _shelf: Array[Dictionary] = []
var _reroll_button: Button = null
# The auto_sold ledger is per stage and next() clears it, so the screen remembers how far it has read.
var _auto_sold_seen := 0


func _init() -> void:
	# The one theme, set here so every child (the bar, the garage, the buttons) inherits it. The screen
	# anchors to the viewport, which is what makes the garage's own 20..-180 pit line up with the bar.
	theme = ChUi.theme()
	anchor_right = 1.0
	anchor_bottom = 1.0
	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.anchor_left = 1.0
	gold_label.anchor_right = 1.0
	gold_label.offset_left = -200.0
	gold_label.offset_right = -16.0
	gold_label.offset_top = 12.0
	gold_label.offset_bottom = 48.0
	add_child(gold_label)
	toggle = Button.new()
	toggle.name = "Toggle"
	toggle.text = "Garage"  # the shop is what the screen opens on
	toggle.anchor_top = 0.5
	toggle.anchor_bottom = 0.5
	toggle.offset_left = 16.0
	toggle.offset_right = 126.0
	toggle.offset_top = -22.0
	toggle.offset_bottom = 22.0
	toggle.pressed.connect(_on_toggle)
	Feedback.attach_button(toggle)
	add_child(toggle)
	middle = Control.new()
	middle.name = "Middle"
	middle.anchor_right = 1.0
	middle.anchor_bottom = 1.0
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	stage_view = Control.new()
	stage_view.name = "Stage"
	stage_view.anchor_right = 1.0
	stage_view.anchor_bottom = 1.0
	stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(stage_view)
	# Inside the stage view, so the toggle that hides the shop hides Next with it.
	next_button = Button.new()
	next_button.text = "Next →"
	next_button.anchor_left = 0.5
	next_button.anchor_right = 0.5
	next_button.offset_left = -70.0
	next_button.offset_right = 70.0
	next_button.offset_top = BUTTON_TOP
	next_button.offset_bottom = BUTTON_TOP + BUTTON_H
	next_button.pressed.connect(_on_next)
	Feedback.attach_button(next_button)
	stage_view.add_child(next_button)
	# The bar is a later sibling than middle, so it draws over the garage's bottom seam.
	bar = ChInventoryBar.new()
	bar.name = "Bar"
	add_child(bar)
	bar.card_clicked.connect(_on_bar_clicked)
	bar.card_dropped.connect(_on_bar_dropped)


func setup(run_in: ChRun, catalog_in: ChCatalog) -> void:
	run = run_in
	catalog = catalog_in
	phase = ChShopPhase.new(run, catalog)
	bar.setup(run.inventory, catalog)
	var scene: PackedScene = ResourceLoader.load(GARAGE)
	garage = scene.instantiate() as ChGarage
	# The garage's order is setup then add_child: _enter_tree builds the pit, which setup cannot.
	garage.setup(run.inventory, run.layout, catalog)
	middle.add_child(garage)
	garage.piece_dropped.connect(_on_piece_dropped)
	# Any mount, lift or flip changes the inventory, and the bar is the one place that is drawn.
	garage.changed.connect(bar.refresh)
	garage.hide()
	_render_stage()
	_refresh_gold()
	# Stage 1 has no screen of its own: opening the shop is what credits the fight that just ended.
	_pop_gold(phase.credited)


func _on_toggle() -> void:
	# The one thing the toggle is allowed to do. The phase, the cards and the garage's build all stay.
	if stage_view == null or garage == null:
		return
	stage_view.visible = not stage_view.visible
	garage.visible = not stage_view.visible
	toggle.text = "Shop" if garage.visible else "Garage"


func _on_option_clicked(index: int) -> void:
	# Committing a stage: a refusal shakes the card it was asked from, and a success shows what the
	# stage committed to (a shop's shelf, a pack's row, or nothing for a resource).
	if phase == null:
		return
	if not phase.pick(index):
		if index >= 0 and index < _option_cards.size():
			_option_cards[index].refuse()
		return
	_refresh_gold()
	_render_stage()


func _on_item_clicked(index: int) -> void:
	_try_item(index)


func _on_item_dropped(index: int, at: Vector2) -> void:
	# A drag only means a buy or a take when it is let go on the bar; anywhere else glides home.
	if bar == null or bar.slot_index_at(at) < 0:
		return
	_try_item(index)


func _try_item(index: int) -> bool:
	# One action for a click and a drop: shop items are bought, pack items are taken.
	if phase == null or index < 0 or index >= phase.items.size():
		return false
	var item: Dictionary = phase.items[index]
	var kind: StringName = phase.picked.get(&"kind", &"")
	var ok := false
	if kind == &"shop":
		ok = phase.buy(index)
	elif kind == &"pack":
		ok = phase.take(index)
	if not ok:
		var card := _card_for(index)
		if card != null:
			card.refuse()
		return false
	bar.refresh()
	# The beat lands on the card that now carries the part, not on the shelf card that is leaving.
	var carried := _bar_card(item[&"id"])
	if carried != null:
		Feedback.play(&"placed", carried)
	_refresh_gold()
	_pop_auto_sold()
	# A taken card is no longer on offer, so it leaves the row. The cards that stay keep their phase
	# index (items are never renumbered), which is why a later click still buys the item it names.
	# A pack grants one card, so its take spends the whole stage: every pack card leaves the row.
	if kind == &"pack":
		_clear_shelf()
	else:
		_drop_taken(index)
	return true


func _clear_shelf() -> void:
	for entry in _shelf:
		var card: Control = entry[&"card"]
		stage_view.remove_child(card)
		card.queue_free()
	_shelf.clear()


func _drop_taken(item_index: int) -> void:
	for at in range(_shelf.size() - 1, -1, -1):
		if _shelf[at][&"item_index"] != item_index:
			continue
		var card: Control = _shelf[at][&"card"]
		stage_view.remove_child(card)
		card.queue_free()
		_shelf.remove_at(at)
	var row: Array[Control] = []
	for entry in _shelf:
		row.append(entry[&"card"])
	_place_row(row, ROW_CENTRE_Y)


func _card_for(item_index: int) -> ChCard:
	for entry in _shelf:
		if entry[&"item_index"] == item_index:
			return entry[&"card"]
	return null


func _on_reroll() -> void:
	# A refused reroll (no shop, already rerolled, too poor) needs no card shake: the button's own
	# activate beat is the answer.
	if phase == null or not phase.reroll():
		return
	_refresh_gold()
	_render_stage()


func _on_bar_clicked(index: int) -> void:
	# A click on a carried card is a hold only while the garage is the view: in the shop it means nothing.
	if garage == null or not garage.visible or run == null:
		return
	var ids: Array[StringName] = run.inventory.part_ids
	if index >= 0 and index < ids.size():
		garage.hold(ids[index])


func _on_bar_dropped(index: int, at: Vector2) -> void:
	# The bar's drop routing, in the one order that keeps a part: SELL first (it owns the right end),
	# then a slot, then the garage's free markers while the garage is showing.
	if phase == null or bar == null:
		return
	if bar.over_sell(at):
		var value := phase.sell(index)
		bar.refresh()
		if value > 0:
			_pop_gold(value)
		return
	var slot := bar.slot_index_at(at)
	if slot >= 0:
		if slot != index:
			run.inventory.move(index, slot)
		bar.refresh()
		return
	if garage != null and garage.visible:
		# slot_at answers [path, body cells], the same entry _free_slots builds.
		var free_slot: Array = garage.slot_at(at)
		if not free_slot.is_empty():
			# The garage's changed signal refreshes the bar; a refusal leaves the card gliding home.
			garage.mount_from_inventory(index, free_slot[0])


func _on_piece_dropped(path, at: Vector2) -> void:
	# A mounted piece let go over the bar's slots is lifted home. SELL never takes pit pieces (spec
	# call 9), and the garage handles its own refusal shake.
	if bar == null or bar.slot_index_at(at) < 0 or garage == null:
		return
	garage.lift(path)


func _on_next() -> void:
	# Past stage 4 the run asks for the next fight instead of rolling a stage nobody can use.
	if phase == null:
		return
	if phase.done():
		fight_requested.emit()
		return
	_auto_sold_seen = 0
	phase.next()
	_render_stage()
	_refresh_gold()


func _render_stage() -> void:
	# Every card in the stage view is rebuilt from the phase: the options before a pick, then what the
	# pick committed to. The next button is the one permanent child and reads Fight once the stage is over.
	_clear_stage()
	if phase == null:
		return
	if phase.done():
		next_button.text = "Fight"
		return
	next_button.text = "Next →"
	if phase.picked.is_empty():
		_render_options()
		return
	var kind: StringName = phase.picked.get(&"kind", &"")
	if kind == &"shop":
		_render_items(true)
	elif kind == &"pack":
		_render_items(false)


func _render_options() -> void:
	var row: Array[Control] = []
	for index in phase.options.size():
		var card := OptionCard.new()
		card.card_text = _option_text(phase.options[index])
		card.custom_minimum_size = Vector2(OPTION_W, OPTION_H)
		card.size = card.custom_minimum_size
		card.clicked.connect(_on_option_clicked.bind(index))
		_option_cards.append(card)
		row.append(card)
	_place_row(row, ROW_CENTRE_Y)
	for card in row:
		stage_view.add_child(card)


func _render_items(show_price: bool) -> void:
	var row: Array[Control] = []
	for index in phase.items.size():
		if phase.items[index][&"taken"]:
			continue
		var card := _make_item_card(index, show_price)
		if card == null:
			continue
		_shelf.append({&"card": card, &"item_index": index})
		row.append(card)
	_place_row(row, ROW_CENTRE_Y)
	for card in row:
		stage_view.add_child(card)
	if show_price:
		_add_reroll()


func _make_item_card(index: int, show_price: bool) -> ChCard:
	var item: Dictionary = phase.items[index]
	if item[&"is_body"]:
		var body_def: ChBodyDef = catalog.body(item[&"id"])
		if body_def == null:
			return null
		var body_card := BodyItemCard.new()
		body_card.body_def = body_def
		body_card.price = int(item[&"price"]) if show_price else -1
		body_card.custom_minimum_size = Vector2(
			maxf(OPTION_W, body_def.size.x * ChGarage.ZOOM + 16.0), BODY_H)
		body_card.size = body_card.custom_minimum_size
		body_card.clicked.connect(_on_item_clicked.bind(index))
		body_card.dropped.connect(func(at: Vector2) -> void: _on_item_dropped(index, at))
		return body_card
	var def: ChPartDef = catalog.part(item[&"id"])
	if def == null:
		return null
	var card: ChPartCard
	if show_price:
		card = ChPartCard.new(def, _on_item_clicked.bind(index))
		card.price = int(item[&"price"])
	else:
		# A pack is paid for when it opens, so its cards carry no price row at all.
		card = PackItemCard.new(def, _on_item_clicked.bind(index))
	card.show_count = false
	card.size = card.custom_minimum_size
	card.dropped.connect(func(at: Vector2) -> void: _on_item_dropped(index, at))
	return card


func _add_reroll() -> void:
	_reroll_button = Button.new()
	_reroll_button.text = "Reroll $%d" % ChPrices.REROLL
	_reroll_button.anchor_left = 0.5
	_reroll_button.anchor_right = 0.5
	_reroll_button.offset_left = -230.0
	_reroll_button.offset_right = -90.0
	_reroll_button.offset_top = BUTTON_TOP
	_reroll_button.offset_bottom = BUTTON_TOP + BUTTON_H
	_reroll_button.pressed.connect(_on_reroll)
	Feedback.attach_button(_reroll_button)
	stage_view.add_child(_reroll_button)


func _place_row(cards: Array[Control], centre_y: float) -> void:
	# One row centred on the screen: each card keeps its own width (a body is wider than a part) and
	# the row never runs off either side at three cards.
	if cards.is_empty():
		return
	var total := 0.0
	for card in cards:
		if card.size.x <= 0.0 or card.size.y <= 0.0:
			card.size = card.custom_minimum_size
		total += card.size.x
	total += ROW_GAP * (cards.size() - 1)
	var x := (SCREEN.x - total) * 0.5
	for card in cards:
		card.position = Vector2(x, centre_y - card.size.y * 0.5)
		x += card.size.x + ROW_GAP


func _clear_stage() -> void:
	_option_cards.clear()
	_shelf.clear()
	_reroll_button = null
	for child in stage_view.get_children():
		if child == next_button:
			continue
		stage_view.remove_child(child)
		child.queue_free()


func _option_text(option: Dictionary) -> String:
	# The card's own words: "Fire shop", "Weapon pack", or the resource's payout.
	var kind: StringName = option[&"kind"]
	if kind == &"resource":
		if option[&"resource"] == &"gold":
			return "+%d gold" % ChShopPhase.RESOURCE_GOLD
		return "+%d max HP" % ChShopPhase.RESOURCE_HP
	var theme_name := String(option[&"theme"]).capitalize()
	return theme_name + (" shop" if kind == &"shop" else " pack")


func _bar_card(id: StringName) -> ChPartCard:
	# The bar's card for a part just bought or taken, which is the node the placed beat kicks.
	for card in bar._cards:
		if card.part_id == id:
			return card
	return null


func _refresh_gold() -> void:
	if gold_label != null and run != null:
		gold_label.text = "Gold %d" % run.gold


func _pop_gold(n: int) -> void:
	_pop_gold_text("+%d" % n, {"amount": n})


func _pop_auto_sold() -> void:
	# A body swap can sell the parts that found no slot. The stage's ledger is read from where the last
	# buy left it, so one pop per part and never the same part twice.
	if phase == null:
		return
	var sold: Array[StringName] = phase.auto_sold
	for i in range(_auto_sold_seen, sold.size()):
		var def: ChPartDef = catalog.part(sold[i])
		var value := 0
		if def != null:
			value = ChPrices.sell_value(def.rarity)
		_pop_gold_text("+$%d" % value, {"text": "+$%d", "amount": value})
	_auto_sold_seen = sold.size()


func _pop_gold_text(text: String, overrides: Dictionary) -> void:
	# The readout holds the beat's text for a moment and comes back to "Gold N". A screen outside the
	# tree has no timer to wait on, so it restores at once and a headless caller reads a stable label.
	gold_label.text = text
	Feedback.play(&"energy", gold_label, overrides)
	if not is_inside_tree():
		_refresh_gold()
		return
	get_tree().create_timer(GOLD_POP_TIME).timeout.connect(_refresh_gold)


# One option face before a pick: the theme and the kind, or the resource's payout, drawn on the flat
# slab ChCard paints. The text is painted rather than a Label, so the minimal HUD stays two labels.
class OptionCard extends ChCard:
	var card_text := ""

	func _init() -> void:
		super()

	func _paint_face() -> void:
		var rim := ChUi.ACCENT if hovered else Color(0, 0, 0, 0)
		draw_style_box(ChUi.flat(ChUi.BUTTON, rim), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var line_h := font.get_height(ChUi.FONT_SIZE)
		var baseline := (size.y - line_h) * 0.5 + font.get_ascent(ChUi.FONT_SIZE)
		draw_string(font, Vector2(8.0, baseline), card_text, HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 16.0, ChUi.FONT_SIZE, ChUi.TEXT)


# A body on the shelf: its name, its price and the hull at the pit's zoom. The hull is drawn the way
# ChPitPiece.show_hull draws it (texture, else outline polygon, else colour box) so a body reads the same
# in the shop as it does mounted.
class BodyItemCard extends ChCard:
	var body_def: ChBodyDef = null
	var price := -1

	func _init() -> void:
		super()

	func _paint_face() -> void:
		super()
		if body_def == null:
			return
		var font := get_theme_default_font()
		var inner := size.x - 16.0
		draw_string(font, Vector2(8.0, 24.0), body_def.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, inner, 16, ChUi.TEXT)
		if price >= 0:
			draw_string(font, Vector2(8.0, 42.0), "$%d" % price,
				HORIZONTAL_ALIGNMENT_LEFT, inner, 14, ChUi.TEXT)
		var centre := Vector2(size.x * 0.5, 56.0 + (size.y - 56.0) * 0.5)
		var hull := Vector2(maxi(1, body_def.size.x), maxi(1, body_def.size.y)) * ChGarage.ZOOM
		if body_def.texture != null:
			draw_texture_rect(body_def.texture, Rect2(centre - hull * 0.5, hull), false)
		elif body_def.outline.size() >= 3:
			var shape := PackedVector2Array()
			for point in body_def.outline:
				shape.append(centre + point * ChGarage.ZOOM)
			draw_colored_polygon(shape, body_def.color)
			draw_polyline(shape + PackedVector2Array([shape[0]]),
				body_def.color.darkened(0.3), 1.0)
		else:
			draw_rect(Rect2(centre - hull * 0.5, hull), body_def.color)


# A part in a pack: the part at the pit's zoom and its name, with no price row because the pack was
# already paid for when it opened.
class PackItemCard extends ChPartCard:
	func _init(def_in: ChPartDef, on_click: Callable) -> void:
		super(def_in, on_click)

	func _paint_face() -> void:
		if def == null:
			return
		var rim := ChUi.ACCENT if hovered else Color(0, 0, 0, 0)
		draw_style_box(ChUi.flat(ChUi.BUTTON, rim), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var inner := size.x - ChPartCard.PAD * 2.0
		var at := ChPartCard.PAD
		for line in _wrap(font, def.display_name, inner):
			at += ChPartCard.LINE
			draw_string(font, Vector2(ChPartCard.PAD, at), line,
				HORIZONTAL_ALIGNMENT_LEFT, inner, ChPartCard.FONT, ChUi.TEXT)
		var top := at + 8.0
		draw_rect(Rect2(Vector2(4.0, top - 6.0),
			Vector2(size.x - 8.0, size.y - top + 2.0)), ChUi.PANEL)
		ChPartCard.paint(self, Vector2(size.x * 0.5, (top + size.y) * 0.5), def,
			ChPartCard.ZOOM)
