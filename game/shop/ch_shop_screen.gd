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
const STAGE_PAD := 24.0
const GOLD_POP_TIME := 0.6  # how long "+N" holds before the readout comes back

var run: ChRun = null
var catalog: ChCatalog = null
var phase: ChShopPhase = null
var gold_label: Label = null
var toggle: Button = null
var middle: Control = null
var stage_view: Control = null
var stage_panel: Control = null  # the wine panel and SHOP plaque behind the row; first child of stage_view
var stage_rect := Rect2()  # the row's span plus STAGE_PAD, in screen pixels
var next_button: Button = null
var bar: ChInventoryBar = null
var garage: ChGarage = null
var tooltip: ChPartTooltip = null  # a shelf part card's def, above the stage row while it is hovered

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
	# The screen is opaque: _show_shop keeps the ended battle in the tree, and without the backdrop the
	# arena and its chariots show through behind the stage row and the gold readout. A parent draws
	# under its children, so the garage and the cards stay on top.
	add_child(ChBackdrop.new())
	# add_child(ChWash.new(ChWash.SHOP_ALPHA))
	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_color_override(&"font_color", ChUi.ACCENT)
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
	# Added after middle, not with the gold label: the garage is a full-rect Control inside middle, and a
	# Control eats the click of anything drawn under it, so a toggle added first would be dead in the one
	# view it has to get out of.
	middle = Control.new()
	middle.name = "Middle"
	middle.anchor_right = 1.0
	middle.anchor_bottom = 1.0
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	add_child(toggle)
	stage_view = Control.new()
	stage_view.name = "Stage"
	stage_view.anchor_right = 1.0
	stage_view.anchor_bottom = 1.0
	stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(stage_view)
	stage_panel = Control.new()
	stage_panel.name = "StagePanel"
	stage_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_panel.draw.connect(_draw_stage_panel)
	stage_view.add_child(stage_panel)
	# Inside the stage view, so the toggle that hides the shop hides Next with it.
	next_button = Button.new()
	next_button.text = "Next →"
	next_button.anchor_left = 0.5
	next_button.anchor_right = 0.5
	next_button.offset_left = -70.0
	next_button.offset_right = 70.0
	next_button.offset_top = BUTTON_TOP
	next_button.offset_bottom = BUTTON_TOP + BUTTON_H
	next_button.theme_type_variation = &"GoButton"
	next_button.pressed.connect(_on_next)
	Feedback.attach_button(next_button)
	stage_view.add_child(next_button)
	# The bar is a later sibling than middle, so it draws over the garage's bottom seam.
	bar = ChInventoryBar.new()
	bar.name = "Bar"
	add_child(bar)
	bar.card_clicked.connect(_on_bar_clicked)
	bar.card_dropped.connect(_on_bar_dropped)
	# Last, so it draws over the stage row and the bar; its own _init sets the ignore filter and the
	# z index.
	tooltip = ChPartTooltip.new()
	tooltip.name = "Tooltip"
	add_child(tooltip)


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
	garage.body_requested.connect(_on_body_requested)
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
	# A click never drags, but the zones can still be rimmed from an earlier drag's card.
	if bar != null:
		bar.clear_highlight()
	_try_item(index)


func _on_item_dropped(index: int, at: Vector2) -> void:
	# A drag only means a buy or a take when it is let go on the bar; anywhere else glides home. The
	# rims go whatever the drop means.
	if bar == null:
		return
	bar.clear_highlight()
	if bar.slot_index_at(at) < 0:
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
		# A freed card never sends its own exit, so put a hovered one down before it goes.
		(card as ChCard).hover(false)
		stage_view.remove_child(card)
		card.queue_free()
	_shelf.clear()
	_reset_stage_rect()
	tooltip.hide_tooltip()


func _drop_taken(item_index: int) -> void:
	for at in range(_shelf.size() - 1, -1, -1):
		if _shelf[at][&"item_index"] != item_index:
			continue
		var card: Control = _shelf[at][&"card"]
		(card as ChCard).hover(false)
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
		garage.hold(ids[index], index)


func _on_bar_dropped(index: int, at: Vector2) -> void:
	# The bar's drop routing, in the one order that keeps a part: SELL first (it owns the right end),
	# then a slot, then the garage's own zones while the garage is showing.
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
	if garage == null or not garage.visible:
		return
	var id: StringName = run.inventory.part_ids[index] if index >= 0 \
		and index < run.inventory.part_ids.size() else &""
	if catalog.body(id) != null:
		# A body is not a slot part: the hull is its one drop zone, and the swap is the shop's rule.
		if garage.hull_at(at):
			_equip_body(index)
		return
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


func _on_body_requested(id: StringName, index: int) -> void:
	# The garage's held-body click: the hold names its copy, and an index the inventory no longer
	# answers with this id falls back to the first copy, the way the garage's drop_part does.
	if index < 0 or index >= run.inventory.part_ids.size() \
			or run.inventory.part_ids[index] != id:
		index = run.inventory.part_ids.find(id)
	_equip_body(index)


func _equip_body(index: int) -> void:
	# The swap, paid for by the shop: the bought body goes on the hull and the body it replaced goes
	# home to the inventory (see ChShopPhase.equip_body). The pit is redrawn here because the change is
	# the phase's, not the garage's, so the garage's own sync never ran.
	if phase == null or not phase.equip_body(index):
		return
	bar.refresh()
	garage.refresh()
	_refresh_gold()
	_pop_auto_sold()


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
		card.drag_started.connect(_on_shelf_drag_started)
		if card is ChPartCard:
			card.hover_changed.connect(_on_shelf_hover.bind(card as ChPartCard))
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
		var body_card := ChBodyCard.new(body_def, _on_item_clicked.bind(index))
		body_card.price = int(item[&"price"]) if show_price else -1
		body_card.custom_minimum_size = Vector2(
			maxf(OPTION_W, body_def.size.x * ChGarage.ZOOM + 16.0), BODY_H)
		body_card.size = body_card.custom_minimum_size
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


func _on_shelf_drag_started() -> void:
	# A shop or pack item is not sellable, so the slots rim and SELL does not.
	if bar != null:
		bar.highlight(null, false)


func _on_shelf_hover(entered: bool, card: ChPartCard) -> void:
	# A shelf part card names its part above itself. A body shelf card is a ChBodyDef and has none.
	if tooltip == null:
		return
	if not entered or card.def == null:
		tooltip.hide_tooltip()
		return
	tooltip.show_part(card.def, card.get_global_rect(), ChPartTooltip.Side.ABOVE, get_viewport_rect())


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
		_reset_stage_rect()
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
	var span := Rect2(cards[0].position, cards[0].size)
	for card in cards:
		span = span.merge(Rect2(card.position, card.size))
	stage_rect = span.grow(STAGE_PAD)
	stage_panel.queue_redraw()


func _reset_stage_rect() -> void:
	stage_rect = Rect2()
	stage_panel.queue_redraw()


func _draw_stage_panel() -> void:
	if stage_rect.size.x <= 0.0:
		return
	stage_panel.draw_style_box(ChUi.panel(), stage_rect)
	ChUi.draw_plaque(stage_panel, Vector2(stage_rect.get_center().x, stage_rect.position.y), "SHOP")


func _clear_stage() -> void:
	_reset_stage_rect()
	_option_cards.clear()
	_shelf.clear()
	_reroll_button = null
	tooltip.hide_tooltip()
	for child in stage_view.get_children():
		if child == next_button or child == stage_panel:
			continue
		if child is ChCard:
			(child as ChCard).hover(false)
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


func _bar_card(id: StringName) -> ChCard:
	# The bar's card for a thing just bought or taken, which is the node the placed beat kicks: a part's
	# card or a body's.
	for card in bar._cards:
		if ChInventoryBar.id_of(card) == id:
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
		super()
		var font := ChUi.FONT
		var line_h := font.get_height(ChUi.FONT_SIZE)
		var baseline := (size.y - line_h) * 0.5 + font.get_ascent(ChUi.FONT_SIZE)
		draw_string(font, Vector2(8.0, baseline), card_text, HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 16.0, ChUi.FONT_SIZE, ChUi.TEXT)


# A part in a pack: the part at the pit's zoom and its name, with no price row because the pack was
# already paid for when it opened.
class PackItemCard extends ChPartCard:
	func _init(def_in: ChPartDef, on_click: Callable) -> void:
		super(def_in, on_click)
		show_cost = false
