class_name ChGarage extends Control

# Task 10: the embeddable pit. The garage is a Control a screen puts anywhere (ChMain today, the shop
# later) and it owns only the build: a centred chariot in a pit, the free-slot markers, the part in
# hand and the part tooltip. The inventory, the cards and the buttons belong to whoever embeds it -
# the bar under it and the shop above it - so the handshakes here are by index and by id: the bar says
# which copy of a part to mount and where, and the pit says which mounted piece was dragged off it.
# setup() borrows the inventory and the layout the owner holds, so the logic methods below are the
# handshakes between the two halves of one build: ChInventory carries what is not mounted,
# ChChariotLayout what is. The click methods on top call these same rules, so a test that drives them
# drives the screen's own rules, with or without a scene.
# Deliberately thin: add never dedupes and place accepts a slot index no def owns, so the garage adds
# no rule of its own beyond the fit check lift shares with a body swap, the one rule that stops a full
# inventory from losing a branch - lifted off the hull or orphaned by a body swap. drop_part checks
# the carry before it places, which is the one order that cannot lose a part on a refused place; a
# mount from the bar takes the copy by index and removes it only after the place landed. The tooltip
# reads the DEF, never a runtime: no fight has run yet, so cooldown_left, integrity and charges_left
# do not exist here.
# Nothing leaves the inventory on a pick: a part in hand is only an id, so a fight asked for or a hold
# cancelled mid-way can lose nothing (both clear the hold first).

# After any mount, lift or flip: the bar refreshes its cards from it. Not on a refusal, where nothing
# changed. Same-tick duplicates are fine - the bar just redraws.
signal changed
# A mounted piece dragged past DRAG_THRESHOLD and let go, with the GLOBAL (screen) point it was let go
# at: the owner compares that against its own drop zones, decides, and calls lift() or sells it. The
# pit leaves the piece mounted until the owner says what the drop means.
signal piece_dropped(path: Array[int], at: Vector2)

const ZOOM := 6.0  # cells -> pixels: the hull, the parts and the one in hand all read at this scale
const CHARIOT_AT := Vector2(640, 250)  # the hull's centre, in garage-local pixels
const MARK_PX := 32.0  # a free slot's marker, and how close a pointer has to sit to drop into it
const DRAG_THRESHOLD := 6.0  # px a press on a mounted piece moves before it is a drag, as ChCard's
const DASH := 6.0  # one dash of an empty slot's marker
const GAP := 4.0  # and the space after it
const MARK_COLOR := Color(0.75, 0.7, 0.55, 0.8)  # an empty slot, dim so it never competes
const HOVER_COLOR := Color(0.95, 0.9, 0.5)  # the hovered part and its range

var inventory: ChInventory = null
var layout: ChChariotLayout = null
var catalog: ChCatalog = null
var held_id: StringName = &""  # the carried part in hand; &"" when nothing is
var hover_path: Array[int] = []  # the mounted part under the pointer, empty when nothing is

var _pit: Control = null  # the input surface: a click here places, lifts, flips or drags a piece
var _pit_view: Node2D = null  # the pit's nodes, offset so their positions are garage-local pixels
var _hull: ChPitPiece = null  # the body the build sits on
var _markers: Node2D = null  # the free slot markers, drawn between the hull and the parts
var _parts: Node2D = null  # one ChPitPiece per mounted part
var _drag_layer: Node2D = null  # the dragged piece, drawn under the pointer over the parts
var _hover: Node2D = null  # the hovered part's box and range, drawn over everything
var _pieces := {}  # path string -> ChPitPiece: what _parts holds, and the way back from a path
var _held_layer: Control = null  # the part in hand, drawn over everything at the pointer
var tooltip: ChPartTooltip = null  # the one part tooltip, the garage's last child so it draws on top
var _pointer := Vector2.ZERO  # the last pointer the pit saw, garage-local: the marker nearest it fills

var _pressed := false  # a left press on the pit is down; its motion and release come through _input
var _drag_from := Vector2.ZERO  # that press, garage-local, which the 6 px is measured from
var _press_path: Array[int] = []  # the mounted piece it landed on, empty when it landed on sand
var _drag_path: Array[int] = []  # the piece a drag picked up; empty while it is still a click
var _drag_at := Vector2.ZERO  # the pointer while it drags: the piece is drawn here


func _init() -> void:
	# The one theme (Task 5), set here rather than in the .tscn: a scene cannot call a static, and the
	# theme has to be on the root before any child is drawn.
	theme = ChUi.theme()


func setup(inventory_in: ChInventory, layout_in: ChChariotLayout,
	catalog_in: ChCatalog) -> void:
	# Three references and nothing else: a lift returns a part where the owner can see it and a
	# drop takes it from there, so the screen keeps no copy of either half. The copy a fight is handed
	# belongs to the owner too (ChMain still asks for one until Task 13).
	# The order is setup() then add_child: _enter_tree builds the pit's nodes, so a caller that sets up
	# after entering the tree has a pit with no hull in it until it does.
	# shortcut: no validation. An unresolvable body_id is ChChariotLayout's own business, and Task 4's
	# place() left an out-of-range index legal on the same grounds, so the garage adds no rule.
	inventory = inventory_in
	layout = layout_in
	catalog = catalog_in
	_sync_pit()


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
	changed.emit()
	_sync_pit()
	# After the sync, so the piece the beat kicks is the one the drop just built.
	Feedback.play(&"placed", piece_at(step))
	_refresh_tooltip()
	return true


func mount_from_inventory(index: int, path) -> bool:
	# The bar's drop onto a free marker: place first, remove the copy only once the place landed. A
	# refusal therefore leaves the part at the same index the bar already drew it at - the brief's
	# "puts the part back at the same index" - and with two copies of an id it is the index that says
	# which one, which take(id) could not.
	if inventory == null or layout == null:
		return false
	if index < 0 or index >= inventory.part_ids.size():
		return false
	var step: Array[int] = _typed(path)
	if not layout.place(step, inventory.part_ids[index]):
		return false
	inventory.remove_at(index)
	changed.emit()
	_sync_pit()
	# After the sync, so the piece the beat kicks is the one the mount just built.
	Feedback.play(&"placed", piece_at(step))
	_refresh_tooltip()
	return true


func lift(path) -> bool:
	# A lift hands the whole branch home to the inventory: remove returns the subtree with its
	# children, and its ids go back parent first, which is the order that lets a re-drop mount
	# the parent again before the child that needs it.
	# The fit is checked before anything is cut (spec call 8): a branch whose parts do not all fit is
	# refused outright, so the layout, the inventory and the pit stay exactly as they were and nothing
	# is auto-sold.
	if inventory == null or layout == null:
		return false
	var step: Array[int] = _typed(path)
	var node: ChSlotNode = layout.get_node(step)
	if node == null:
		return false
	if _overflows(layout.subtree_part_ids(node).size()):
		_refuse_piece(step)
		return false
	# get_node just resolved this path, so remove cannot answer null for it.
	_lift_branches([layout.remove(step)])
	changed.emit()
	_sync_pit()
	return true


func _overflows(count: int) -> bool:
	# The one "does it all fit" rule, and it is read before anything is cut: more ids than the kit has
	# free slots and the handshake is refused outright, so nothing is auto-sold and nothing is lost.
	# lift and the shop's body buy share it. free_slots covers ChMain's unlimited kit with the same
	# rule, and an inventory that is not there at all has nowhere for a part to go, so it overflows
	# everything.
	if inventory == null:
		return true
	return count > inventory.free_slots()


func _refuse_piece(path: Array[int]) -> void:
	# The refusal shake: the same rotation-only beat ChCard.refuse plays (8 degrees, no pop), on the
	# pit piece that owns a Juice child from its own _init. A refused lift is what shakes today; the
	# owner of a refused drag (a release with nowhere to go) is the other caller this exists for.
	# shortcut: Feedback has no `refuse` profile and ChFeedbackManager.KINDS is pinned at 13, so the
	# juice is kicked directly; upgrade if a refusal profile is ever added.
	var piece := piece_at(path)
	var juice := ChJuice.of(piece) if piece != null else null
	if juice != null:
		juice.juice_up(0.0, deg_to_rad(8.0))


func click_part(path) -> void:
	# A click on a placed part: only the flip flag changes, and what moves because of it is where its
	# children hang, which is the anchor both the drawn part and its markers use.
	if layout != null:
		layout.toggle_flip(_typed(path))
		changed.emit()


func hold(id: StringName) -> void:
	# The bar's click: a part comes to hand, and the bar owns "is this card draggable" now, so the
	# garage asks the inventory nothing - a held id the kit carries none of draws no part and drops
	# nowhere, which is the refusal that needs no rule here.
	# Holding the part already in hand is how a player puts it back, so that clears the hold instead.
	if id == held_id:
		cancel_hold()
		return
	held_id = id
	if _held_layer != null:
		_held_layer.queue_redraw()
	_refresh_tooltip()


func slot_at(global: Vector2) -> Array:
	# The drop-zone test an inventory card's release uses: the screen point of a free marker, taken
	# back into the garage's own pixels, answers that slot's path and cells, or nothing when no marker
	# is near. The bar hands in screen pixels, so the conversion happens here rather than at the bar.
	return _slot_near(_to_local(global))


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
	_refresh_tooltip()
	_sync_pit()


func _lift_branches(branches) -> Array[StringName]:
	# Whole subtrees go home, parent first: subtree_part_ids is the order a builder needs, which
	# is also the order that lets a re-drop mount a parent before the child that needs it.
	# What does not fit comes back as overflow instead of being dropped on the floor: both callers check
	# free_slots first (lift the branch, a body swap the whole build), so nothing overflows today. Task
	# 7's body buy is the first caller that hands back real overflow, and it sells it.
	var overflow: Array[StringName] = []
	if inventory == null:
		return overflow
	for branch in branches:
		for id in layout.subtree_part_ids(branch):
			# add never dedupes, so a returning branch really is new copies: it left the pit.
			if not inventory.add(id):
				overflow.append(id)
	return overflow


func screen_of(path) -> Vector2:
	# The pixel a path's anchor sits at, mounted or not: an empty slot has no node to read, so the
	# position comes from the defs, which is what makes a click aimed at a marker land on it. The walk
	# lives in the layout, the same one anchor_of reads, so the pit and the fight cannot drift.
	if layout == null or catalog == null:
		return CHARIOT_AT
	return CHARIOT_AT + layout.cells_of(_typed(path), catalog) * ZOOM


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
			out.append([one, layout.cells_of(one, catalog)])
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
			out.append([step, layout.cells_of(step, catalog)])
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
		_refresh_tooltip()
	_sync_pit()


func _refresh_tooltip() -> void:
	# The one place the tooltip is shown or hidden: a held part hides it, and otherwise it names the
	# hull part under the pointer, or nothing is shown at all. The cards' own tooltips belong to the bar.
	if tooltip == null:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	if held_id != &"":
		tooltip.hide_tooltip()
	else:
		var def := _hovered_def()
		if def == null:
			tooltip.hide_tooltip()
		else:
			tooltip.show_part(def, _box_at(screen_of(hover_path), def), ChPartTooltip.Side.RIGHT, bounds)


func _hovered_def() -> ChPartDef:
	# The def of the mounted part under the pointer, null when nothing (or an id with no def) is.
	if hover_path.is_empty() or layout == null or catalog == null:
		return null
	var node: ChSlotNode = layout.get_node(hover_path)
	return catalog.part(node.part_id) if node != null else null


func _on_pit_exited() -> void:
	# A pointer that leaves the pit straight off a hull part sends the pit no motion, so the hover
	# would stay on the part and come back the moment the pointer came in again over sand.
	hover_path = []
	_refresh_tooltip()
	_sync_pit()


func _copy_of_build() -> ChChariotLayout:
	# The copy a fight is handed (ChMain's temporary Enter key asks for one until Task 13), so the fight
	# cannot mutate what the garage shows: same body, same mounts, same flips, no shared node.
	# ChariotLayout's only deep copy is mirrored(), which also inverts every flip (that is how
	# an enemy build is sent round), so the copy is built from the class's own parts instead:
	# all_paths is parent-first, which is the order place needs for a nested path, and the flip
	# is re-applied with the class's own toggle_flip so the build faces the way the pit shows it.
	var copy := ChChariotLayout.new()
	copy.body_id = layout.body_id
	copy.max_hp = layout.max_hp
	for path in layout.all_paths():
		var step: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(step)
		copy.place(step, node.part_id)
		if node.flipped:
			copy.toggle_flip(step)
	return copy


func _enter_tree() -> void:
	# The nodes the scene declares, the same reading ChBattle takes of $Camera and $HUD: the pit's input
	# surface and the layer the part in hand is drawn on. A garage is instanced per screen (ChMain
	# frees and rebuilds it), so this runs once; the guard keeps a node that is taken out and put back
	# from building a second pit.
	if tooltip != null:
		return
	_pit = $Pit
	_build_pit_nodes()
	_pit.gui_input.connect(_on_pit_input)
	_pit.mouse_exited.connect(_on_pit_exited)
	_held_layer = $HeldLayer
	_held_layer.draw.connect(_draw_held)
	tooltip = ChPartTooltip.new()
	add_child(tooltip)
	_sync_pit()


func _on_pit_input(event: InputEvent) -> void:
	# A real mouse, on the pit. A Control hands its handler positions local to itself, so the convert
	# is what puts a click in the garage's own pixels; then left places a part in hand, or arms a press
	# on a mounted piece, and right flips. The motion and release of that press arrive through _input
	# instead (see there), because a drag leaves the pit on its way to the bar.
	if not event is InputEventMouse:
		return
	var at: Vector2 = _pit.position + (event as InputEventMouse).position
	if event is InputEventMouseMotion:
		_follow_pointer(at)
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		right_click_pit(at)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		if held_id != &"":
			click_pit(at)
		else:
			_pressed = true
			_drag_from = at
			_press_path = _hover_at(at)
	_follow_pointer(at)


func _gui_input(event: InputEvent) -> void:
	# The root's empty space: a left click there puts the part in hand back. The pit handles its own
	# clicks, so only what it did not take arrives here. Motions are not read: _input has every one.
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		cancel_hold()


func _input(event: InputEvent) -> void:
	# The press's motion and release are read here rather than through the pit's gui_input, so a drag
	# that leaves the pit on its way to the bar is still followed: this is the one place every motion
	# arrives, the same seam ChCard takes its own drag through. The part in hand follows the pointer
	# from here too.
	if not event is InputEventMouse:
		return
	var mouse := event as InputEventMouse
	if _pressed:
		if event is InputEventMouseMotion:
			_drag_to(_to_local(mouse.global_position))
		elif event is InputEventMouseButton \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and not (event as InputEventMouseButton).pressed:
			_end_drag(_to_local(mouse.global_position))
			return
	if held_id != &"" and _held_layer != null and event is InputEventMouseMotion:
		_held_layer.queue_redraw()


func _to_local(global: Vector2) -> Vector2:
	# A screen point in the garage's own pixels: Control has no to_local (that is Node2D's), so this is
	# the canvas item's transform taken backwards. The pit's gui_input and the bar's drops agree on it.
	return get_global_transform_with_canvas().affine_inverse() * global


func _drag_to(at: Vector2) -> void:
	# The press on a mounted piece: under the 6 px it is still the click it always was, past it the
	# piece comes off the pit and is drawn at the pointer until it is let go.
	_drag_at = at
	if _drag_path.is_empty():
		if _press_path.is_empty() or at.distance_to(_drag_from) <= DRAG_THRESHOLD:
			return
		_drag_path = _press_path
	_sync_drag()


func _end_drag(at: Vector2) -> void:
	# The press let go. A drag hands the path and the screen point to the owner, which lifts it or
	# sells it - the pit changes nothing here. A press that never moved past the threshold is today's
	# click on a mounted part: it lifts the branch.
	var dropped: Array[int] = _drag_path
	var pressed: Array[int] = _press_path  # the press's own piece: a release under 6 px is a click
	_pressed = false
	_drag_path = []
	_press_path = []
	_drag_at = at
	_sync_drag()
	_follow_pointer(at)
	if not dropped.is_empty():
		piece_dropped.emit(dropped, get_global_transform_with_canvas() * at)
		return
	if not pressed.is_empty():
		lift(pressed)


func _sync_drag() -> void:
	# The dragged piece is drawn at the pointer rather than in its slot, so its own piece is hidden
	# until it lands. A drop the owner refuses re-shows it by clearing _drag_path and syncing again.
	for key in _pieces:
		_pieces[key].visible = key != str(_drag_path)
	if _drag_layer != null:
		_drag_layer.queue_redraw()


func _draw_drag() -> void:
	# The dragged part, at the pointer and at the pit's zoom, so it reads as the piece that will be
	# dropped rather than a thumbnail of it.
	if _drag_path.is_empty() or catalog == null or layout == null:
		return
	var node: ChSlotNode = layout.get_node(_drag_path)
	var def: ChPartDef = catalog.part(node.part_id) if node != null else null
	if def != null:
		ChPartCard.paint(_drag_layer, _drag_at, def, ZOOM, node.flipped)


func _build_pit_nodes() -> void:
	# The pit's nodes, added under $Pit so the held layer and the tooltip stay on top. PitView undoes the
	# pit's own offset, so a child's position is a garage pixel - the same space screen_of, _box_at and
	# _free_slots answer in - and the children keep the paint order the one _draw had: hull, markers,
	# parts, the dragged piece, hover.
	_pit_view = Node2D.new()
	_pit_view.name = "PitView"
	_pit.add_child(_pit_view)
	_pit.move_child(_pit_view, 0)
	# The pit's rect is not final when this runs - this node enters the tree before its own child does -
	# so the offset is taken again whenever the rect changes, which is before the first frame is drawn.
	_pit.item_rect_changed.connect(_place_pit_view)
	_hull = ChPitPiece.new()
	_hull.name = "Hull"
	_hull.position = CHARIOT_AT
	_pit_view.add_child(_hull)
	_markers = Node2D.new()
	_markers.name = "Markers"
	_markers.draw.connect(_draw_markers)
	_pit_view.add_child(_markers)
	_parts = Node2D.new()
	_parts.name = "Parts"
	_pit_view.add_child(_parts)
	_drag_layer = Node2D.new()
	_drag_layer.name = "Drag"
	_drag_layer.draw.connect(_draw_drag)
	_pit_view.add_child(_drag_layer)
	_hover = Node2D.new()
	_hover.name = "Hover"
	_hover.draw.connect(_draw_hover)
	_pit_view.add_child(_hover)


func _place_pit_view() -> void:
	# The pit's offset undone, so a child of PitView sits at a garage pixel: the space screen_of,
	# _box_at and _free_slots answer in.
	if _pit_view != null:
		_pit_view.position = -_pit.position


func piece_at(path: Array[int]) -> ChPitPiece:
	# The piece a path's part is drawn as, null when nothing is mounted there: the handle a feedback
	# beat kicks, and how a test tells a reused piece from a rebuilt one.
	return _pieces.get(str(path))


func hull_piece() -> ChPitPiece:
	# The hull's own node: what a body swap redraws.
	return _hull


func _sync_pit() -> void:
	# The pit brought up to date: the hull, one piece per mounted part, and the two draws between
	# them. A piece whose path and part are unchanged is reused, so a change elsewhere leaves its
	# wobble in flight alone; a piece whose path is gone or whose part changed is freed here.
	# Every layout and hover change lands here, which is why the pit needs no _draw of its own.
	# shortcut: nothing is synced before _enter_tree builds the nodes, which is setup()'s order.
	if _parts == null or layout == null or catalog == null:
		return
	_place_pit_view()
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def != null and _hull.body_def != body_def:
		_hull.show_hull(body_def)
	var live := {}
	for path in layout.all_paths():
		var typed_path: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(typed_path)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			continue
		var key := str(typed_path)
		live[key] = true
		var box := _box_at(screen_of(typed_path), def)
		var piece: ChPitPiece = _pieces.get(key)
		if piece != null and piece.part_def != null and piece.part_def.id == node.part_id:
			# The slot can move under a part - a body swap reseats it, a flip moves what hangs off
			# it - so the position follows the layout even when the piece itself is reused.
			piece.position = box.get_center()
			if piece.flipped != node.flipped:
				piece.show_part(def, node.flipped)
			continue
		if piece != null:
			_drop_piece(key)
		var fresh := ChPitPiece.new()
		fresh.show_part(def, node.flipped)
		fresh.position = box.get_center()
		_parts.add_child(fresh)
		_pieces[key] = fresh
	for key in _pieces.keys():
		if not live.has(key):
			_drop_piece(key)
	_markers.queue_redraw()
	_hover.queue_redraw()
	# A piece rebuilt mid-drag is visible by default, so the dragged one is hidden again here.
	_sync_drag()


func _drop_piece(key: String) -> void:
	# A piece leaves the tree now but frees at the end of the frame: the child count a test reads is
	# already right, and a juice kick still in flight goes with the node instead of moving it.
	var piece: ChPitPiece = _pieces[key]
	_pieces.erase(key)
	_parts.remove_child(piece)
	piece.queue_free()


func _draw_markers() -> void:
	# The free slot markers, between the hull and the parts. A free slot is a dashed empty square;
	# while a part is in hand, the one a click would drop into is filled, which is the only
	# instruction the screen gives.
	var near := _slot_near(_pointer) if held_id != &"" else []
	for entry in _free_slots():
		var marker := Rect2(CHARIOT_AT + entry[1] * ZOOM - Vector2(MARK_PX, MARK_PX) * 0.5,
			Vector2(MARK_PX, MARK_PX))
		if not near.is_empty() and entry[1] == near[1]:
			_markers.draw_rect(marker, Color(ChUi.ACCENT, 0.2))
		_dashed_rect(_markers, marker, MARK_COLOR)


func _draw_hover() -> void:
	# The hovered part's box and range circle, over everything, read from the layout rather than the
	# piece, so a part's pop does not drag the outline with it.
	if layout == null or catalog == null or hover_path.is_empty():
		return
	var hovered: ChSlotNode = layout.get_node(hover_path)
	var hdef: ChPartDef = catalog.part(hovered.part_id) if hovered != null else null
	if hdef == null:
		return
	var centre := screen_of(hover_path)
	if hdef.proximity_range > 0.0:
		# The brief's proximity outline: the def's range in cells, scaled onto the chariot.
		_hover.draw_circle(centre, hdef.proximity_range * ZOOM,
			Color(HOVER_COLOR.r, HOVER_COLOR.g, HOVER_COLOR.b, 0.12), true)
	_hover.draw_rect(_box_at(centre, hdef), HOVER_COLOR, true)


func _dashed_rect(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	# A free slot's marker: dashed so it reads as an empty socket rather than a part. The canvas is
	# the node the draw signal is on, because a draw command lands on the item it is called on.
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for at in 4:
		_dashed_line(canvas, corners[at], corners[(at + 1) % 4], color)


func _dashed_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var span := to - from
	var length := span.length()
	if length <= 0.0:
		return
	var step := span / length
	var at := 0.0
	while at < length:
		canvas.draw_line(from + step * at, from + step * minf(at + DASH, length), color)
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
