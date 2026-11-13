class_name ChInventoryBar extends PanelContainer

# Task 11: the inventory bar. The bottom strip of the 1280x720 screen (the garage's pit ends at y 540,
# so this is the 172 px under it): five slot rects on the left, the SELL zone on the right, and one
# ChPartCard per carried part standing in its slot. It is its own Control because the shop screen
# embeds it, and it reads the inventory the run owns rather than keeping one.
# The bar owns no rule the shop or the garage has: a click says which part index it means, a drop says
# which index and where it was let go, and the screen routes that. The only thing it decides is where
# its own rects are.
# A card is a child of the layer, not of a container, so refresh() can place it in its slot; the card's
# follow spring eases any move, which is why a reorder glides instead of snapping.
# _cards is the inventory's order and refresh() keeps it so: the click and drop handlers read a card's
# index off it at event time, so no handler ever carries a stale slot.

signal card_clicked(index: int)
# The global (screen) point it was let go at: the screen tests its own drop zones against it.
signal card_dropped(index: int, at: Vector2)

# The strip's height. The screen reserves the bottom 180 px and the pit's last pixel is y 540, so 172
# leaves the garage an 8 px seam above the bar.
const HEIGHT := 172.0
const SLOT_W := 112.0  # a ChPartCard is 88 wide, so a slot has 12 px either side of it
const SLOT_H := 148.0
const SLOT_GAP := 12.0
const SLOT_X := 16.0  # the left inset, and the sell zone's right one
const SELL_W := 200.0

var inventory: ChInventory = null
var catalog: ChCatalog = null
var sell_label: Label = null

# One card per carried part, in inventory order (see the header).
var _cards: Array[ChPartCard] = []
# The five slot rects and the sell zone, in _layer's own pixels; the two hit tests convert into it.
var _slots: Array[Rect2] = []
var _sell := Rect2()
# The layer is the bar's content rect: it draws the zones and holds the cards and the label, because a
# Container would fit every child to the whole bar and a card has to sit in its own slot.
var _layer: Control = null
var _drag_def: ChPartDef = null  # the part a drag carries, while the accepting zones are rimmed
var _drag_card: ChPartCard = null  # set only for a BAR card's drag: the bar follows the label then


func _init() -> void:
	# The one theme, set here rather than in a scene: PanelContainer draws its own panel from it.
	theme = ChUi.theme()
	_layer = Control.new()
	_layer.name = "Layer"
	# Transparent to the mouse: the cards under it still get their own clicks, and a press on an empty
	# slot falls through to whatever the screen put behind the bar.
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_bar)
	add_child(_layer)
	sell_label = Label.new()
	sell_label.name = "SellLabel"
	sell_label.text = "SELL"
	sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer.add_child(sell_label)
	# A resize re-places the zones and the cards: refresh is the one path that does both.
	resized.connect(refresh)


func _ready() -> void:
	# The bar is the screen's bottom strip, so it anchors itself there: full width, HEIGHT tall.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	refresh()


func setup(inventory_in: ChInventory, catalog_in: ChCatalog) -> void:
	# Borrowed, not copied: the bar draws whatever the run carries right now, and refresh() is called
	# after every phase action that changes it.
	inventory = inventory_in
	catalog = catalog_in
	refresh()


func refresh() -> void:
	# Idempotent: it is called after every phase action, from a resize, and by setup. A card is keyed to
	# its part, not to a slot, so a reorder keeps every node and only moves it - which the card's follow
	# spring eases (a position change would snap otherwise). A part that left is freed, a new one gets
	# a card.
	_layout()
	var ids: Array[StringName] = []
	if inventory != null:
		ids = inventory.part_ids
	var spare := _cards.duplicate()
	var cards: Array[ChPartCard] = []
	for id in ids:
		var card: ChPartCard = null
		for index in spare.size():
			if spare[index].part_id == id:
				card = spare[index]
				spare.remove_at(index)
				break
		if card == null:
			var def: ChPartDef = catalog.part(id) if catalog != null else null
			# shortcut: an id with no def draws no card, which shifts the cards after it up a slot; the
			# shop and the garage only ever add ids the catalog holds, so upgrade if a save may not.
			if def == null:
				continue
			card = _make_card(def)
		cards.append(card)
	for card in spare:
		_layer.remove_child(card)
		card.queue_free()
	_cards = cards
	for index in _cards.size():
		var card := _cards[index]
		card.size = card.custom_minimum_size
		card.position = _slots[index].get_center() - card.size * 0.5
		if card.get_parent() == null:
			# Added after it is placed, so its first frame is already in its slot rather than flying in
			# from the layer's origin: ChCard absorbs a move as a spring, and a new card has none to absorb.
			_layer.add_child(card)
	_layer.queue_redraw()


func slot_index_at(global: Vector2) -> int:
	# The drop-zone test an inventory card's release uses: 0-4, or -1 off the slots. The bar is not at
	# the screen's origin, so the point is taken into the bar's own pixels rather than compared as is.
	var at := _to_local(global)
	for index in _slots.size():
		if _slots[index].has_point(at):
			return index
	return -1


func over_sell(global: Vector2) -> bool:
	return _sell.has_point(_to_local(global))


func highlight(card_def: ChPartDef) -> void:
	# While a card is dragged, the zones that would accept it get an ACCENT rim. The def is kept
	# because it is what the sell zone prices when the pointer is over it.
	_drag_def = card_def
	_layer.queue_redraw()


func clear_highlight() -> void:
	# The drag ended (or was refused): the rims go and the zone label rests on "SELL" again.
	_drag_def = null
	_drag_card = null
	sell_label.text = "SELL"
	_layer.queue_redraw()


func _make_card(def: ChPartDef) -> ChPartCard:
	# ChPartCard connects its own pick in its constructor, but the handler needs the card, which does
	# not exist yet: the one-element array carries it to the Callable.
	var holder: Array[ChPartCard] = []
	var card := ChPartCard.new(def, func() -> void: card_clicked.emit(_index_of(holder[0])))
	holder.append(card)
	# One card per carried part: there is no "×n" to read, and the play a card makes is its own.
	card.show_count = false
	card.set_count(1)
	card.drag_started.connect(_on_card_drag_started.bind(card))
	card.dropped.connect(_on_card_dropped.bind(card))
	return card


func _on_card_drag_started(card: ChPartCard) -> void:
	_drag_card = card
	highlight(card.def)


func _on_card_dropped(at: Vector2, card: ChPartCard) -> void:
	# The index is read before the screen hears the drop: its handler sells or reorders the part, and
	# after that there would be no card left to find. The label and the rims go first for the same reason
	# - the bar's own state must not depend on the card still being carried.
	var index := _index_of(card)
	clear_highlight()
	card_dropped.emit(index, at)


func _update_sell_label(global: Vector2) -> void:
	# The zone's label reads the dragged part's sell value only while the pointer is over SELL. The bar
	# calls this from _input for one of its own cards' drags; Task 12 sets the label itself while a shop
	# item is dragged.
	if _drag_def != null and over_sell(global):
		sell_label.text = "+$%d" % ChPrices.sell_value(_drag_def.rarity)
	else:
		sell_label.text = "SELL"


func _input(event: InputEvent) -> void:
	# Only a bar card's drag is followed here: ChCard takes every motion through its own _input while it
	# is pressed, so the bar reads the same events to know which zone the pointer is over.
	if _drag_card == null:
		return
	if event is InputEventMouseMotion:
		_update_sell_label((event as InputEventMouseMotion).global_position)


func _index_of(card: ChPartCard) -> int:
	# Read at event time: _cards is the inventory's order, so a card's place in it is the slot it means.
	return _cards.find(card)


func _layout() -> void:
	# The layer takes the panel's content rect, the same one the container would fit it to: taking the
	# theme's own margins keeps the rects final before the first frame, so a test reads them with none.
	if _layer == null:
		return
	var box := get_theme_stylebox(&"panel", &"PanelContainer")
	var origin := Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	var inner := size - origin \
		- Vector2(box.get_margin(SIDE_RIGHT), box.get_margin(SIDE_BOTTOM))
	_layer.position = origin
	_layer.size = inner
	var top := (inner.y - SLOT_H) * 0.5
	_slots.clear()
	for index in ChInventory.CAPACITY:
		_slots.append(Rect2(
			Vector2(SLOT_X + index * (SLOT_W + SLOT_GAP), top), Vector2(SLOT_W, SLOT_H)))
	_sell = Rect2(Vector2(inner.x - SLOT_X - SELL_W, top), Vector2(SELL_W, SLOT_H))
	sell_label.position = _sell.position
	sell_label.size = _sell.size
	_layer.queue_redraw()


func _to_local(global: Vector2) -> Vector2:
	# A screen point in the layer's own pixels: Control has no to_local, so this is the canvas
	# transform taken backwards, the same reading ChGarage._to_local takes.
	return _layer.get_global_transform_with_canvas().affine_inverse() * global


func _draw_bar() -> void:
	# The five empty slots and the sell zone, drawn under the cards: an empty slot stays a slot, so a
	# half-empty bar still reads as five slots with room. They are rects rather than labels because the
	# screen's minimal HUD has no capacity counter.
	var rim := ChUi.ACCENT if _drag_def != null else Color(0, 0, 0, 0)
	for rect in _slots:
		_layer.draw_style_box(ChUi.flat(ChUi.BUTTON, rim), rect)
	_layer.draw_style_box(ChUi.flat(ChUi.BUTTON, rim), _sell)
