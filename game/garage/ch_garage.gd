class_name ChGarage extends Control

# Task 7: the garage screen, rebuilt for the 1280x720 canvas: a centred chariot in a pit, the kit as one
# strip of cards under it, and no paging and no hint line anywhere. The parts strip is the whole kit at
# once; a card is clicked to take a part in hand and the pit is clicked again to place it. There is no
# hold-to-drag: the pointer polling behind the deleted drag (its button flag, its carried id and its
# inventory rows) went with Task 4's 320x180 layout, so nothing here reads the pointer on a frame.
# setup() borrows the inventory and the layout the owner holds (ChMain today, the shop later), so the
# logic methods below are the handshakes between the two halves of one build: ChInventory carries what
# is not mounted, ChChariotLayout what is. The click methods on top call these same rules, so a test
# that drives them drives the screen's own rules, with or without a scene.
# Deliberately thin: take lifts the first copy, add never dedupes and place accepts a slot index no def
# owns, so the garage adds no rule of its own. drop_part checks the carry before it places, which is the
# one order that cannot lose a part on a refused place. selected_info reads the DEF, never a runtime: no
# fight has run yet, so cooldown_left, integrity and charges_left do not exist here.
# Nothing leaves the inventory on a pick: a part in hand is only an id, so a fight asked for or a body
# swapped mid-hold can lose nothing (both clear the hold first).

signal fight_requested(layout: ChChariotLayout)

const ZOOM := 6.0  # cells -> pixels: the hull, the cards and the part in hand all read at this scale
const CHARIOT_AT := Vector2(640, 300)  # the hull's centre, in garage-local pixels
const BODIES := [&"cutter", &"dozer", &"corsair"]  # the cycle the body buttons walk
# The strip's order, and card_counts' keys: every part the slice has, wheels first.
const STRIP_ORDER := [&"wheel", &"ice_cream_mace", &"cutter_chainsaw", &"flamethrower", &"hearth",
	&"cutter_rocket", &"corsair_harpoon", &"ember_battery", &"firebolt_launcher", &"ring_of_fire",
	&"freeze_charge", &"strut"]
const MARK_PX := 32.0  # a free slot's marker, and how close a pointer has to sit to drop into it
const CARD_GAP := 8  # between two cards in the strip
const DASH := 6.0  # one dash of an empty slot's marker
const GAP := 4.0  # and the space after it
const MARK_COLOR := Color(0.75, 0.7, 0.55, 0.8)  # an empty slot, dim so it never competes
const HOVER_COLOR := Color(0.95, 0.9, 0.5)  # the hovered part and its range

var inventory: ChInventory = null
var layout: ChChariotLayout = null
var catalog: ChCatalog = null
var held_id: StringName = &""  # the carried part in hand; &"" when nothing is
var hover_path: Array[int] = []  # the mounted part under the pointer, empty when nothing is

var _cards: Array[ChPartCard] = []  # the strip's cards, in STRIP_ORDER
var _pit: Control = null  # the input surface: a click here places, lifts or flips
var _held_layer: Control = null  # the part in hand, drawn over everything at the pointer
var _info_panel: PanelContainer = null
var _info_name: Label = null
var _info_line: Label = null
var _info_hook: Label = null
var _body_name: Label = null
var _stats: Label = null
var _pointer := Vector2.ZERO  # the last pointer the pit saw, garage-local: the marker nearest it fills


func _init() -> void:
	# The one theme (Task 5), set here rather than in the .tscn: a scene cannot call a static, and the
	# theme has to be on the root before any child is drawn.
	theme = ChUi.theme()


func setup(inventory_in: ChInventory, layout_in: ChChariotLayout,
	catalog_in: ChCatalog) -> void:
	# Three references and nothing else: a lift returns a part where the owner can see it and a
	# drop takes it from there, so the screen keeps no copy of either half. The copy the brief
	# asks for belongs to request_fight, which is the only layout a fight could mutate.
	# The refreshes are for a screen that is already on the tree (a caller that sets up after
	# add_child); on ChMain's order - setup, then add_child - they are no-ops.
	# shortcut: no validation. An unresolvable body_id is cycle_body's refusal, and Task 4's
	# place() left an out-of-range index legal on the same grounds, so the garage adds no rule.
	inventory = inventory_in
	layout = layout_in
	catalog = catalog_in
	_refresh_top()
	_refresh_cards()
	queue_redraw()


func _typed(path) -> Array[int]:
	# all_paths and the scene hand untyped paths while the layout's methods take Array[int],
	# which Godot checks at runtime, so one conversion covers every call site below.
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func drop_part(part_id: StringName, path) -> bool:
	# has -> place -> take is the one order that keeps every part: a taken slot refuses at place
	# so nothing was lifted, and take cannot fail after the has() that just passed.
	if inventory == null or layout == null or not inventory.has(part_id):
		return false
	var step: Array[int] = _typed(path)
	if not layout.place(step, part_id):
		return false
	inventory.take(part_id)
	_refresh_cards()
	queue_redraw()
	return true


func lift(path) -> bool:
	# A lift hands the whole branch home to the inventory: remove returns the subtree with its
	# children, and its ids go back parent first, which is the order that lets a re-drop mount
	# the parent again before the child that needs it.
	if inventory == null or layout == null:
		return false
	var branch: ChSlotNode = layout.remove(_typed(path))
	if branch == null:
		return false
	_lift_branches([branch])
	_refresh_cards()
	queue_redraw()
	return true


func click_part(path) -> void:
	# A click on a placed part: only the flip flag changes, and what moves because of it is where its
	# children hang, which is the anchor both the drawn part and its markers use.
	if layout != null:
		layout.toggle_flip(_typed(path))


func pick_part(id: StringName) -> bool:
	# The strip's click: a carried part comes to hand, and a part the kit has none of is refused (the
	# card is disabled as well, but the rule is here so a click by any other route obeys it too).
	# Picking the part already in hand is how a player puts it back, so that clears the hold instead.
	if _count_of(id) <= 0:
		return false
	if id == held_id:
		cancel_hold()
		return true
	held_id = id
	if _held_layer != null:
		_held_layer.queue_redraw()
	return true


func click_pit(pointer: Vector2) -> void:
	# Click, then click: with a part in hand this is the place click, which drops it into the nearest
	# free slot within reach and hands it over. Anywhere else puts it back - nothing left the inventory
	# when it was picked up, so a miss costs nothing. With nothing in hand, a click on a mounted part
	# lifts that part's whole branch.
	if held_id != &"":
		var slot := _slot_near(pointer)
		if slot.is_empty():
			cancel_hold()
			return
		drop_part(held_id, slot[0])
		cancel_hold()
		return
	var path: Array[int] = _hover_at(pointer)
	if not path.is_empty():
		lift(path)


func right_click_pit(pointer: Vector2) -> void:
	# The flip click: the mounted part under the pointer faces the other way.
	var path: Array[int] = _hover_at(pointer)
	if not path.is_empty():
		click_part(path)


func cancel_hold() -> void:
	# Putting a part back: the hold is only a reference, so this is the whole of it.
	held_id = &""
	if _held_layer != null:
		_held_layer.queue_redraw()
	queue_redraw()


func cycle_body(step: int = 1) -> void:
	# The body buttons: BODIES walked forward by one, or backwards on a step of -1. swap_body does the
	# reseat by nearest slot (Task 4) and hands back the subtrees that found no slot; those go home to
	# the inventory whole, so a part is never both mounted and carried at once.
	# A fight or a swap clears the hold first: the part is still carried either way, but a held id the
	# hull no longer knows about is a state the pit would have to explain.
	cancel_hold()
	if layout == null or catalog == null:
		return
	# A body the cycle never visits has no next, so it stays put instead of jumping to Cutter
	# and reporting leftovers a caller would read as a reseat that never happened.
	var at := _cycle_index()
	if at < 0:
		return
	var count := BODIES.size()
	var next: StringName = BODIES[((at + step) % count + count) % count]
	# swap_body resolves the def through the catalog and refuses a swap onto an id it has no def
	# for, leaving body_id alone, so the cycle only ever announces a body it can seat onto.
	_lift_branches(layout.swap_body(catalog.body(next), catalog))
	# The paths the pointer was over are the old hull's slots, so the hover goes with them.
	hover_path = []
	_fill_info({})
	_refresh_top()
	_refresh_cards()
	queue_redraw()


func _cycle_index() -> int:
	for at in BODIES.size():
		if BODIES[at] == layout.body_id:
			return at
	return -1


func _lift_branches(branches) -> void:
	# Whole subtrees go home, parent first: subtree_part_ids is the order a builder needs, which
	# is also the order that lets a re-drop mount a parent before the child that needs it.
	if inventory == null:
		return
	for branch in branches:
		for id in layout.subtree_part_ids(branch):
			# add never dedupes, so a returning branch really is new copies: it left the pit.
			# shortcut: an over-capacity add (a shop's 5-slot inventory) loses the part to
			# ChInventory's own rule; ChMain hands this screen an unlimited one.
			inventory.add(id)


func card_counts() -> Dictionary:
	# Every id the strip lists, mounted or not: a part the kit carries none of reads 0 and its card is
	# disabled, which is how the strip says what is left.
	var out := {}
	for id in STRIP_ORDER:
		out[id] = _count_of(id)
	return out


func _count_of(id: StringName) -> int:
	if inventory == null:
		return 0
	var total := 0
	for carried in inventory.part_ids:
		if carried == id:
			total += 1
	return total


func selected_info(path) -> Dictionary:
	# The panel's fields, straight off the def: cost, cooldown and hook text are what a player
	# decides with, and range is the proximity circle drawn beside it.
	if layout == null or catalog == null:
		return {}
	var node: ChSlotNode = layout.get_node(_typed(path))
	if node == null:
		return {}
	var def: ChPartDef = catalog.part(node.part_id)
	if def == null:
		# A mounted id with no def has nothing to say; the panel stays empty rather than naming
		# a part the catalog cannot describe.
		return {}
	var info := _info_of(def)
	info["range"] = def.proximity_range
	return info


func _info_of(def: ChPartDef) -> Dictionary:
	# The panel's shape for a def nothing has mounted yet, which is what a card hovers: the same fields
	# selected_info answers for a mount, so a card and a hull read alike.
	return {
		"name": def.display_name,
		"cost": def.energy_cost,
		"cooldown": def.cooldown,
		"hook_text": def.hook_text,
	}


func screen_of(path) -> Vector2:
	# The pixel a path's anchor sits at, mounted or not: an empty slot has no node to read, so the
	# position comes from the defs, which is what makes a click aimed at a marker land on it.
	return CHARIOT_AT + _cells_of(_typed(path)) * ZOOM


func _cells_of(path: Array[int]) -> Vector2:
	# Body-local cells for any path: the body slot's own position, then one extension offset per step,
	# whose x negates on a flipped parent. The same walk anchor_of does, which answers only for a path
	# that holds a part - the markers and the drop pointer need the position of a slot nothing fills.
	if layout == null or catalog == null or path.is_empty():
		return Vector2.ZERO
	var body: ChBodyDef = catalog.body(layout.body_id)
	if body == null or path[0] < 0 or path[0] >= body.slots.size():
		return Vector2.ZERO
	var at := Vector2(body.slots[path[0]])
	var node: ChSlotNode = layout.slots.get(path[0])
	for i in range(1, path.size()):
		# A path with a hole in its middle names no slot: the part that would own it is not mounted.
		if node == null:
			return Vector2.ZERO
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null or path[i] < 0 or path[i] >= def.extension_slots.size():
			return Vector2.ZERO
		var off: Vector2 = def.extension_slots[path[i]]
		if node.flipped:
			off.x = -off.x
		at += off
		node = node.children.get(path[i])
	return at


func _box_at(at: Vector2, def: ChPartDef) -> Rect2:
	# The drawn box of a part: the def's size in cells at ZOOM, centred on its anchor, which is
	# the same reading ChBattle's markers take (def.size is cells, 1:1 with the grid).
	var size := Vector2(maxi(1, def.size.x), maxi(1, def.size.y)) * ZOOM
	return Rect2(at - size * 0.5, size)


func _free_slots() -> Array:
	# Every slot nothing holds, as [path: Array[int], at: Vector2 in body cells]. The empty marker the
	# pit draws and the place a pointer can drop into are this one list, so the screen never offers a
	# slot a drop would refuse. An extension slot appears once its parent is mounted, because a deeper
	# path has no parent node to read its def from.
	var out: Array = []
	if layout == null or catalog == null:
		return out
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def == null:
		return out
	for index in body_def.slots.size():
		if not layout.slots.has(index):
			var one: Array[int] = [index]
			out.append([one, _cells_of(one)])
	for path in layout.all_paths():
		var typed_path: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(typed_path)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			continue
		for slot in def.extension_slots.size():
			if node.children.has(slot):
				continue  # a taken extension draws its part where the marker would sit
			var step: Array[int] = _typed(typed_path)  # a fresh path per slot, not a shared one
			step.append(slot)
			out.append([step, _cells_of(step)])
	return out


func _slot_near(pointer: Vector2) -> Array:
	# The free slot whose marker is nearest the pointer, as long as it is within reach: a 32px marker
	# has to be aimable, so the aim is forgiving rather than exact.
	var best: Array = []
	var best_gap := MARK_PX
	for entry in _free_slots():
		var gap: float = (CHARIOT_AT + entry[1] * ZOOM - pointer).length()
		if gap <= best_gap:
			best_gap = gap
			best = entry
	return best


func _hover_at(pointer: Vector2) -> Array[int]:
	# The mounted part whose drawn box covers the pointer, deepest first when boxes overlap: a
	# part bolted onto another owns the space it hangs in.
	var best: Array[int] = []
	var best_depth := -1
	if layout == null or catalog == null:
		return best
	for path in layout.all_paths():
		var typed_path: Array[int] = _typed(path)
		var def: ChPartDef = catalog.part(layout.get_node(typed_path).part_id)
		if def == null:
			continue
		if not _box_at(screen_of(typed_path), def).has_point(pointer):
			continue
		if typed_path.size() - 1 > best_depth:
			best_depth = typed_path.size() - 1
			best = typed_path
	return best


func _follow_pointer(pointer: Vector2) -> void:
	# Hover is read from the pointer every motion, so the panel and the range circle follow the pointer
	# without a timer of their own. The redraw is here too: the free slot the drawing fills is the one
	# nearest the pointer, so the pit has to be redrawn when the pointer moves.
	_pointer = pointer
	var next: Array[int] = _hover_at(pointer)
	if next != hover_path:
		hover_path = next
		_fill_info(selected_info(hover_path))
	queue_redraw()


func _fill_info(info: Dictionary) -> void:
	# The InfoPanel's three lines, off the dict selected_info and _info_of answer with; an empty dict is
	# nothing hovered, so the panel goes away rather than showing a blank slab.
	if _info_panel == null:
		return
	_info_panel.visible = not info.is_empty()
	if info.is_empty():
		return
	_info_name.text = String(info["name"])
	_info_line.text = "Cost %d · Cooldown %.1fs" % [int(info["cost"]), float(info["cooldown"])]
	_info_hook.text = String(info["hook_text"])


func request_fight() -> void:
	# The brief's contract: the battle gets a copy, so it cannot mutate what the garage shows.
	# The hold goes first: nothing left the inventory on the pick, so clearing the id is all it takes to
	# keep the kit whole across the fight.
	# shortcut: the enemy layout stays ChMain's: which fight this screen starts is the owner's
	# decision, and this signal only says that one was asked for.
	cancel_hold()
	if layout == null:
		return
	fight_requested.emit(_copy_of_build())


func _copy_of_build() -> ChChariotLayout:
	# The copy the fight is handed: same body, same mounts, same flips, no shared node.
	# ChariotLayout's only deep copy is mirrored(), which also inverts every flip (that is how
	# an enemy build is sent round), so the copy is built from the class's own parts instead:
	# all_paths is parent-first, which is the order place needs for a nested path, and the flip
	# is re-applied with the class's own toggle_flip so the build faces the way the pit shows it.
	var copy := ChChariotLayout.new()
	copy.body_id = layout.body_id
	for path in layout.all_paths():
		var step: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(step)
		copy.place(step, node.part_id)
		if node.flipped:
			copy.toggle_flip(step)
	return copy


func _enter_tree() -> void:
	# The nodes the scene declares, the same reading ChBattle takes of $Camera and $HUD. A garage is
	# instanced per screen (ChMain frees and rebuilds it), so this runs once; the guard keeps a node
	# that is taken out and put back from building a second strip.
	if _info_panel != null:
		return
	_pit = $Pit
	_pit.gui_input.connect(_on_pit_input)
	_held_layer = $HeldLayer
	_held_layer.draw.connect(_draw_held)
	_info_panel = $Pit/InfoPanel
	_info_name = $Pit/InfoPanel/Rows/Name
	_info_line = $Pit/InfoPanel/Rows/Line
	_info_hook = $Pit/InfoPanel/Rows/Hook
	_body_name = $TopBar/BodyName
	_stats = $TopBar/Stats
	var prev: Button = $TopBar/PrevBody
	var next: Button = $TopBar/NextBody
	var fight: Button = $TopBar/FightButton
	# Mouse only: these are not in a focus chain, so no keyboard focus warnings on entry.
	for button in [prev, next, fight]:
		button.focus_mode = Control.FOCUS_NONE
	# One logic call each: the buttons are the methods the tests drive, not a second path through the UI.
	prev.pressed.connect(cycle_body.bind(-1))
	next.pressed.connect(cycle_body.bind(1))
	fight.pressed.connect(request_fight)
	# The one action that starts a fight is the one GO-coloured control; the theme covers every other
	# button, so this is the only local restyle.
	fight.add_theme_stylebox_override("normal", ChUi.flat(ChUi.GO))
	fight.add_theme_stylebox_override("hover", ChUi.flat(ChUi.GO.lightened(0.08), ChUi.ACCENT))
	_build_strip()
	_refresh_top()
	_refresh_cards()
	queue_redraw()


func _build_strip() -> void:
	# One card per id STRIP_ORDER lists, in that order: the strip is the whole kit at once, so there is
	# no paging and no row count to keep. A card's press is its own pick call; the hover is wired here
	# because this is where the defs and the InfoPanel meet.
	var row: HBoxContainer = $Strip/Scroll/Cards
	row.add_theme_constant_override("separation", CARD_GAP)
	for id in STRIP_ORDER:
		var def: ChPartDef = catalog.part(id) if catalog != null else null
		if def == null:
			continue  # an id the catalog has no def for cannot be drawn
		var card := ChPartCard.new(def, self)
		card.mouse_entered.connect(_fill_info.bind(_info_of(def)))
		card.mouse_exited.connect(_fill_info.bind({}))
		row.add_child(card)
		_cards.append(card)


func _refresh_cards() -> void:
	# The strip's counts, off the inventory: the one place a card learns what is left, called from every
	# mutator that carries a part in or out (a drop, a lift, a body swap).
	for card in _cards:
		card.set_count(_count_of(card.part_id))


func _refresh_top() -> void:
	# The bar's own numbers, off the body def: the hull's name and what this build starts a fight with.
	if _body_name == null or catalog == null or layout == null:
		return
	var def: ChBodyDef = catalog.body(layout.body_id)
	if def == null:
		# A body with no def has nothing to name; the id is the only thing there is to show.
		_body_name.text = String(layout.body_id)
		_stats.text = ""
		return
	_body_name.text = def.display_name
	_stats.text = "HP %d · Energy %d" % [def.hp, def.energy_cap]


func _on_pit_input(event: InputEvent) -> void:
	# A real mouse, on the pit. A Control hands its handler positions local to itself, so the convert
	# is what puts a click in the garage's own pixels; then left places or lifts and right flips. The
	# same pointer drives the hover, so the panel and the marker nearest it follow the mouse.
	if not event is InputEventMouse:
		return
	var at: Vector2 = _pit.position + (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		_follow_pointer(at)
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		click_pit(at)
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		right_click_pit(at)
	_follow_pointer(at)


func _gui_input(event: InputEvent) -> void:
	# The root's empty space: a left click there puts the part in hand back. The pit, the strip's cards
	# and the buttons all handle their own clicks (the containers pass inside themselves), so only what
	# none of them took arrives here. Motions are not read: _input has every one of them already.
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		cancel_hold()


func _input(event: InputEvent) -> void:
	# The part in hand follows the pointer, including across the strip, whose cards take their own
	# motion: this is the one place every motion arrives. Nothing else is read here - a motion over the
	# pit is the pit's own, and the hold is the only state a redraw of the layer can be needed for.
	if held_id == &"" or _held_layer == null:
		return
	if event is InputEventMouseMotion:
		_held_layer.queue_redraw()


func _draw() -> void:
	# The pit, in garage-local pixels: the hull, the free slot markers, the mounted parts and the
	# hovered part's range circle. CHARIOT_AT is the hull's centre and +x is forward, the arena's own
	# axes, so the pit reads the way the fight will draw it.
	if layout == null or catalog == null:
		return
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def == null:
		return
	var body_size := Vector2(maxi(1, body_def.size.x), maxi(1, body_def.size.y)) * ZOOM
	draw_rect(Rect2(CHARIOT_AT - body_size * 0.5, body_size), body_def.color)
	# A free slot is a dashed empty square; while a part is in hand, the one a click would drop into is
	# filled, which is the only instruction the screen gives.
	var near := _slot_near(_pointer) if held_id != &"" else []
	for entry in _free_slots():
		var marker := Rect2(CHARIOT_AT + entry[1] * ZOOM - Vector2(MARK_PX, MARK_PX) * 0.5,
			Vector2(MARK_PX, MARK_PX))
		if not near.is_empty() and entry[1] == near[1]:
			draw_rect(marker, Color(ChUi.ACCENT, 0.2))
		_dashed_rect(marker, MARK_COLOR)
	for path in layout.all_paths():
		var typed_path: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(typed_path)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			continue
		var box := _box_at(screen_of(typed_path), def)
		ChPartCard.paint(self, box.get_center(), def, ZOOM)
		if node.flipped:
			# The facing edge, which is what a flip means: +x is forward and a flip negates the
			# extension offsets, so the notch says which way the part and its children point.
			draw_line(Vector2(box.position.x, box.get_center().y - 4.0),
				Vector2(box.position.x, box.get_center().y + 4.0), HOVER_COLOR)
	if hover_path.is_empty():
		return
	var hovered: ChSlotNode = layout.get_node(hover_path)
	var hdef: ChPartDef = catalog.part(hovered.part_id) if hovered != null else null
	if hdef == null:
		return
	var centre := screen_of(hover_path)
	if hdef.proximity_range > 0.0:
		# The brief's proximity outline: the def's range in cells, scaled onto the chariot.
		draw_circle(centre, hdef.proximity_range * ZOOM,
			Color(HOVER_COLOR.r, HOVER_COLOR.g, HOVER_COLOR.b, 0.12), true)
	draw_rect(_box_at(centre, hdef), HOVER_COLOR, true)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	# A free slot's marker: dashed so it reads as an empty socket rather than a part.
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for at in 4:
		_dashed_line(corners[at], corners[(at + 1) % 4], color)


func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var span := to - from
	var length := span.length()
	if length <= 0.0:
		return
	var step := span / length
	var at := 0.0
	while at < length:
		draw_line(from + step * at, from + step * minf(at + DASH, length), color)
		at += DASH + GAP


func _draw_held() -> void:
	# The part in hand, at the pointer and at the pit's zoom, so it reads as the thing that will be
	# dropped rather than a thumbnail of it. The pointer is read at draw time because that is the only
	# position that cannot be stale: a motion the strip's cards swallow still moved the mouse.
	if held_id == &"" or catalog == null:
		return
	var def: ChPartDef = catalog.part(held_id)
	if def == null:
		return
	ChPartCard.paint(_held_layer, _held_layer.get_local_mouse_position(), def, ZOOM)
