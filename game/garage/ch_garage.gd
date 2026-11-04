class_name ChGarage extends Control

# Task 16: the garage screen. setup() borrows the inventory and the layout the owner holds (ChMain
# today, the shop later), so the methods below are the handshakes between the two halves of one
# build: ChInventory carries what is not mounted, ChChariotLayout what is. The UI on top calls
# these same methods, so a test that drives them drives the screen's own rules.
# Deliberately thin on Tasks 4 and 5: take lifts the first copy, add never dedupes and place
# accepts a slot index no def owns, so the garage adds no rule of its own. drop_part checks the
# carry before it places, which is the one order that cannot lose a part on a refused place.
# selected_info reads the DEF, never a runtime: no fight has run yet, so cooldown_left,
# integrity and charges_left do not exist here, and a part out of charges parks cooldown_left
# = INF (Task 13) where only a fight HUD could show that trap.

signal fight_requested(layout: ChChariotLayout)

const ZOOM := 3.0  # cells -> pixels, the brief's 3x on the body
const BODIES := [&"cutter", &"dozer", &"corsair"]  # the cycle the "Body" button walks
const CHARIOT_AT := Vector2(210.0, 96.0)  # screen centre of the body, clear of the list
const INV_AT := Vector2(8.0, 26.0)  # first inventory row
const INV_LINE := 11.0  # row pitch, one 8px line plus a gap
const MARK_PX := 11.0  # how close a pointer has to sit to an empty marker to drop there
const FONT := 8
const MARK_COLOR := Color(0.75, 0.7, 0.55, 0.8)  # an empty slot, dim so it never competes
const HOVER_COLOR := Color(0.95, 0.9, 0.5)  # the hovered part and its range

var inventory: ChInventory = null
var layout: ChChariotLayout = null
var catalog: ChCatalog = null
var hover_path: Array[int] = []  # the mounted part under the pointer, empty when nothing is
var drag_id: StringName = &""  # a carried part the pointer is holding out to a slot
var info_label: Label = null
var body_button: Button = null
var fight_button: Button = null
var row_labels: Array[Label] = []
var left_held := false  # the pointer's own button state


func setup(inventory_in: ChInventory, layout_in: ChChariotLayout,
	catalog_in: ChCatalog) -> void:
	# Three references and nothing else: a lift returns a part where the owner can see it and a
	# drop takes it from there, so the screen keeps no copy of either half. The copy the brief
	# asks for belongs to request_fight, which is the only layout a fight could mutate.
	# shortcut: no validation. An unresolvable body_id is cycle_body's refusal, and Task 4's
	# place() left an out-of-range index legal on the same grounds, so the garage adds no rule.
	inventory = inventory_in
	layout = layout_in
	catalog = catalog_in


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
	return true


func click_part(path) -> void:
	# The brief's click on a placed part: only the flip flag changes, and what moves because of
	# it is where its children hang, which is the anchor both the drawn part and its markers use.
	if layout != null:
		layout.toggle_flip(_typed(path))


func _cycle_index() -> int:
	for at in BODIES.size():
		if BODIES[at] == layout.body_id:
			return at
	return -1


func cycle_body() -> void:
	# Cutter -> Dozer -> Corsair -> Cutter, walking BODIES. swap_body does the reseat by nearest
	# slot (Task 4) and hands back the subtrees that found no slot; those go home to the
	# inventory whole, so a part is never both mounted and carried at once.
	if layout == null or catalog == null:
		return
	# A body the cycle never visits has no next, so it stays put instead of jumping to Cutter
	# and reporting leftovers a caller would read as a reseat that never happened.
	var at := _cycle_index()
	if at < 0:
		return
	var next: StringName = BODIES[(at + 1) % BODIES.size()]
	# swap_body resolves the def through the catalog and refuses a swap onto an id it has no def
	# for, leaving body_id alone, so the cycle only ever announces a body it can seat onto.
	_lift_branches(layout.swap_body(catalog.body(next), catalog))


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
	return {
		"name": def.display_name,
		"cost": def.energy_cost,
		"cooldown": def.cooldown,
		"hook_text": def.hook_text,
		"range": def.proximity_range,
	}

func _at(path) -> Vector2:
	# Screen pixel for a path's anchor. +x is forward and +y is down, the arena's own axes, so
	# the pit reads the way the fight will draw it.
	return CHARIOT_AT + layout.anchor_of(_typed(path), catalog) * ZOOM


func _box_at(at: Vector2, def: ChPartDef) -> Rect2:
	# The drawn box of a part: the def's size in cells at ZOOM, centred on its anchor, which is
	# the same reading ChBattle's markers take (def.size is cells, 1:1 with the grid).
	var size := Vector2(maxi(1, def.size.x), maxi(1, def.size.y)) * ZOOM
	return Rect2(at - size * 0.5, size)


func _free_slots() -> Array:
	# Every slot nothing holds, as [path: Array[int], at: Vector2 in pixels]. The empty marker
	# the brief asks for and the place a pointer can drop into are this one list, so the screen
	# never offers a slot a drop would refuse. An extension slot appears once its parent is
	# mounted, because a deeper path has no parent node to read its def from.
	var out: Array = []
	if layout == null or catalog == null:
		return out
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def == null:
		return out
	for index in body_def.slots.size():
		if layout.slots.has(index):
			continue
		var one: Array[int] = [index]
		out.append([one, Vector2(body_def.slots[index])])
	for path in layout.all_paths():
		var step_parent: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(step_parent)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			continue
		var anchor := layout.anchor_of(step_parent, catalog)
		for slot in def.extension_slots.size():
			if node.children.has(slot):
				continue  # a taken extension draws its part where the marker would sit
			var off: Vector2 = def.extension_slots[slot]
			# A parent's flip turns its own extensions, which is what anchor_of does for a
			# mounted child, so an unmounted marker sits where that child would go.
			if node.flipped:
				off.x = -off.x
			var step: Array[int] = _typed(step_parent)  # a fresh path per slot, not a shared one
			step.append(slot)
			out.append([step, anchor + off])
	return out


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
		if not _box_at(_at(typed_path), def).has_point(pointer):
			continue
		if typed_path.size() - 1 > best_depth:
			best_depth = typed_path.size() - 1
			best = typed_path
	return best


func _inventory_rows() -> Array:
		# A full kit's ids (two of each part plus four wheels) read as one row per id, so the
		# list stays inside the viewport whatever how many copies are carried.
	var rows: Array = []
	if inventory == null:
		return rows
	for id in inventory.part_ids:
		var found := false
		for row in rows:
			if row[0] == id:
				row[1] += 1
				found = true
				break
		if not found:
			rows.append([id, 1])
	return rows


func _name_of(id: StringName) -> String:
	# A part on disk has a display name; an id the catalog has no def for still has to read as
	# something, and its id is the only name there is.
	var def: ChPartDef = catalog.part(id) if catalog != null else null
	if def == null or def.display_name == "":
		return String(id)
	return def.display_name


func _refresh_rows() -> void:
	var rows := _inventory_rows()
	while row_labels.size() < rows.size():
		var label := Label.new()
		label.position = INV_AT + Vector2(0.0, row_labels.size() * INV_LINE)
		label.add_theme_font_size_override("font_size", FONT)
		add_child(label)
		row_labels.append(label)
	for at in row_labels.size():
		var label: Label = row_labels[at]
		if at >= rows.size():
			label.hide()
			continue
		label.show()
		var id: StringName = rows[at][0]
		label.text = _name_of(id) if int(rows[at][1]) == 1 \
			else "%s x%d" % [_name_of(id), int(rows[at][1])]


func _refresh_panel() -> void:
	# The panel is the brief's hover info: name, cost, cooldown, hook text and the proximity
	# range, all from selected_info so the panel and the logic cannot disagree.
	if info_label == null:
		return
	if hover_path.is_empty():
		info_label.text = ""
		return
	var info := selected_info(hover_path)
	if info.is_empty():
		info_label.text = ""
		return
	info_label.text = "%s  cost %d  cooldown %.1fs  range %d\n%s" % [
		String(info["name"]), int(info["cost"]), float(info["cooldown"]),
		int(info["range"]), String(info["hook_text"])]


func _draw() -> void:
	# The pit: body, empty slot markers, mounted parts, and the hovered part's range circle.
	if layout == null or catalog == null:
		return
	var body_def: ChBodyDef = catalog.body(layout.body_id)
	if body_def == null:
		return
	var body_size := Vector2(maxi(1, body_def.size.x), maxi(1, body_def.size.y)) * ZOOM
	draw_rect(Rect2(CHARIOT_AT - body_size * 0.5, body_size), body_def.color)
	for entry in _free_slots():
		draw_rect(Rect2(entry[1] - Vector2(MARK_PX * 0.5, MARK_PX * 0.5),
			Vector2(MARK_PX, MARK_PX)), MARK_COLOR, true)
	for path in layout.all_paths():
		var typed_path: Array[int] = _typed(path)
		var node: ChSlotNode = layout.get_node(typed_path)
		var def: ChPartDef = catalog.part(node.part_id)
		if def == null:
			continue
		var box := _box_at(_at(typed_path), def)
		draw_rect(box, def.color)
		if node.flipped:
			# The facing edge, which is what a flip means: +x is forward and a flip negates the
			# extension offsets, so the notch says which way the part and its children point.
			var mid := box.get_center()
			draw_line(Vector2(mid.x - box.size.x * 0.5, mid.y - 4.0),
				Vector2(mid.x - box.size.x * 0.5, mid.y + 4.0), HOVER_COLOR)
	if hover_path.is_empty():
		return
	var hovered: ChSlotNode = layout.get_node(hover_path)
	var hdef: ChPartDef = catalog.part(hovered.part_id) if hovered != null else null
	if hdef == null:
		return
	var centre := _at(hover_path)
	if hdef.proximity_range > 0.0:
		# The brief's proximity outline: the def's range in cells, scaled onto the chariot.
		draw_circle(centre, hdef.proximity_range * ZOOM,
			Color(HOVER_COLOR.r, HOVER_COLOR.g, HOVER_COLOR.b, 0.12), true)
	draw_rect(_box_at(centre, hdef), HOVER_COLOR, true)


func _row_at(pointer: Vector2) -> StringName:
	# The carried row the pointer sits on, &"" for the gaps and for anywhere off the list.
	if inventory == null:
		return &""
	var rows := _inventory_rows()
	if pointer.x < INV_AT.x or pointer.y < INV_AT.y:
		return &""
	var at := int((pointer.y - INV_AT.y) / INV_LINE)
	if at >= rows.size():
		return &""
	return rows[at][0]


func _slot_near(pointer: Vector2) -> Array:
	# The free slot whose marker is nearest the pointer, as long as it is within reach: one
	# marker has to be aimable at 320x180, so the aim is forgiving rather than exact.
	var best: Array = []
	var best_gap := MARK_PX
	for entry in _free_slots():
		var gap: float = (entry[1] - pointer).length()
		if gap <= best_gap:
			best_gap = gap
			best = entry
	return best


func _follow_pointer(pointer: Vector2) -> void:
	# Hover is read from the pointer every motion, so the panel and the range circle follow the
	# pointer without a timer of their own.
	var next: Array[int] = _hover_at(pointer)
	if next == hover_path:
		return
	hover_path = next
	_refresh_panel()


func _pick_up(pointer: Vector2) -> void:
	# A press picks a part up out of the list; a press anywhere else picks nothing up, which is
	# what keeps a stray click on the pit from starting a drag.
	if drag_id == &"":
		drag_id = _row_at(pointer)


func _put_down(pointer: Vector2) -> void:
	# The end of a drag drops the held part into the nearest free marker. With nothing held, a
	# release over a mounted part is the brief's flip click. Anywhere else the part stays
	# carried, so a release off the pit loses nothing.
	if drag_id != &"":
		var slot := _slot_near(pointer)
		if not slot.is_empty():
			drop_part(drag_id, slot[0])
		drag_id = &""
		_refresh_rows()
	elif not hover_path.is_empty():
		click_part(hover_path)
	_follow_pointer(pointer)


func request_fight() -> void:
	# The brief's contract: the battle gets a copy, so it cannot mutate what the garage shows.
	# shortcut: the enemy layout stays ChMain's: which fight this screen starts is the owner's
	# decision, and this signal only says that one was asked for.
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
	# The nodes the scene declares, the same reading ChBattle takes of $Camera and $HUD. The
	# buttons' `pressed` signal is one logic call each, so the screen's two actions are the
	# methods the tests drive rather than a second path through the UI.
	body_button = $BodyButton
	fight_button = $FightButton
	info_label = $InfoLabel
	# The panel wraps a long hook text inside the viewport; a single line would run past it.
	info_label.autowrap_mode = 2  # TextWrapperMode.WORDS, as an enum value
	info_label.add_theme_font_size_override("font_size", FONT)
	# Mouse only: these are not in a focus chain, so no keyboard focus warnings on entry.
	body_button.focus_mode = 0
	fight_button.focus_mode = 0
	body_button.pressed.connect(cycle_body)
	fight_button.pressed.connect(request_fight)
	_refresh_rows()


func _process(_delta: float) -> void:
	# The pointer drives the screen: hover follows it every frame so the panel and the range
	# circle follow it without a timer of their own, the left button picks a part up out of the
	# list and puts it down on an empty marker, and a release over a mounted part is the flip
	# click. The pointer is read here rather than through Control's own drag hooks, whose names
	# are private to the engine version: the interaction stays one place.
	if layout == null:
		return
	var pointer := get_local_mouse_position()
	_follow_pointer(pointer)
	var held := Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT)
	if held and not left_held:
		_pick_up(pointer)
	elif left_held and not held:
		_put_down(pointer)
	left_held = held
