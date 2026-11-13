extends ChTest

# Task 10: the garage's logic — the inventory handshakes (drop, mount by index, lift), the flip click
# and the copy a fight is handed. ChGarage.setup is what a scene calls before any of these, so every
# test builds its own garage, inventory and layout: a garage owns the references it was handed, so a
# shared one would carry an earlier test's mounts.
# The pit is the only screen left: the bar owns the cards, so a mount arrives by index, and the pit's
# own rules are methods a test drives the way a mouse does. A press that moves past 6 px is a drag: it
# hands the path and the screen point to the owner and lifts nothing itself. `-- test_garage` runs
# them all, and the scene tests at the end instance the shipped garage.tscn rather than a bare
# ChGarage.
# The run's loop itself is tests/run/test_main_run.gd's: the garage here is the embeddable screen
# the shop puts in the middle, so nothing below starts a fight.
const GARAGE_SCENE := "res://game/garage/garage.tscn"


func _catalog() -> ChCatalog:
	var catalog := ChCatalog.load_default()
	assert_true(catalog != null, "the slice's defs load")
	# shortcut: one null-check here; a missing def fails every test below rather than
	# printing one confusing null access each.
	if catalog == null:
		return ChCatalog.new()
	return catalog


func _garage(inventory: ChInventory, layout: ChChariotLayout,
	catalog: ChCatalog) -> ChGarage:
	# A bare Control, off the tree: the logic methods read no nodes and draw nothing.
	# The test, not the scene, owns the inventory and the layout, which is how the later shop
	# wraps the garage by handing over its own pair.
	var garage := ChGarage.new()
	garage.setup(inventory, layout, catalog)
	return garage


func _inventory(ids: Array) -> ChInventory:
	var inventory := ChInventory.new()
	for id in ids:
		assert_true(inventory.add(id), "the starter id fits")
	return inventory


func _layout(body_id: StringName) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	# ChariotLayout.new() starts body_id empty, which swap_body has no position to measure from,
	# so a garage is only ever set up on a body the catalog has a def for.
	# shortcut: a body_id the catalog has no def for stays a caller error; setup invents no rule of
	# its own, and the hull simply shows nothing for it.
	layout.body_id = body_id
	return layout


func test_drop_takes_from_inventory() -> void:
	var inventory := _inventory([&"wheel", &"wheel", &"cutter_chainsaw"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	# The layout the test holds IS the one the garage was handed, so the mount reads back there.
	assert_true(layout.get_node([0]) != null, "so the wheel mounted")
	assert_eq(layout.slots[0].part_id, &"wheel", "as the wheel")
	# ChInventory.take lifts the FIRST copy, so the list stays in its original order minus one.
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "one copy left, order kept")
	# A part the inventory does not carry cannot be dropped, and the inventory stays as it was.
	assert_true(not garage.drop_part(&"cutter_rocket", [1]), "an id not carried is refused")
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "unchanged by the refusal")
	# ChChariotLayout.place refuses a taken slot, so the garage loses nothing from the inventory.
	assert_true(not garage.drop_part(&"wheel", [0]), "a taken slot refuses")
	assert_true(layout.slots.size() == 1, "and the layout gained nothing")
	assert_eq(inventory.part_ids, [&"wheel", &"cutter_chainsaw"], "so the part stayed carried")
	# Inherited from Task 4, and deliberately not hardened here: place accepts a slot index no
	# def owns, so the garage adds no range rule of its own. Such a mount reads back no anchor.
	assert_true(garage.drop_part(&"wheel", [9]), "an out-of-range index still mounts")
	# shortcut: anchor_of is asserted rather than a refusal, because a range check belongs in
	# Task 4's place(), which the brief says stays as it is.
	assert_eq(layout.anchor_of([9], _catalog()), Vector2.ZERO, "and it has no anchor")
	garage.free()
	_complete()


func test_lift_returns_subtree() -> void:
	var inventory := _inventory([&"strut", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts with nothing under it")
	# The strut's extension slot 0 is (0,-6), so a wheel bolted there is one path step deep.
	assert_true(garage.drop_part(&"wheel", [1, 0]), "the wheel bolts onto the strut")
	assert_true(inventory.part_ids.is_empty(), "both drops left the inventory empty")
	assert_true(not garage.lift([3]), "an empty slot lifts nothing")
	assert_true(garage.lift([1]), "lifting the strut takes its whole branch")
	# The child travelled with its parent, so it is no longer mounted either.
	# shortcut: the brief's exact claim is the two ids coming back, asserted next; get_node is the
	# supporting evidence that the branch rather than only its tip detached.
	assert_true(layout.get_node([1]) == null, "the branch left the body slot")
	assert_true(layout.slots.size() == 0, "nothing stays mounted, child included")
	assert_true(inventory.has(&"strut") and inventory.has(&"wheel"), "both ids back in inventory")
	assert_eq(inventory.part_ids.size(), 2, "so the strut and its wheel are carried again")
	# The child's path has no parent now, so it cannot be re-dropped before its parent is.
	assert_true(not garage.drop_part(&"wheel", [1, 0]), "a nested path needs its parent mounted")
	garage.free()
	_complete()


# --- Task 5: a lift that has nowhere to go ---------------------------------------------------------
# A 5-slot inventory refuses a branch whose parts do not all fit, and the refusal is decided before
# anything is cut: the branch stays mounted, nothing is auto-sold and nothing is lost (spec call 8).
# The fit check is the whole rule, so the same lift lands once a slot is free.

func test_lift_refused_when_branch_does_not_fit() -> void:
	var inventory := _inventory([&"wheel", &"wheel", &"wheel", &"wheel"])
	inventory.capacity = ChInventory.CAPACITY
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	# The branch is mounted through the layout so all four carried parts stay carried: four carried
	# in five slots leaves one free, and the strut's branch is two ids.
	assert_true(layout.place(_typed_path([1]), &"strut"), "the strut is mounted in slot 1")
	assert_true(layout.place(_typed_path([1, 0]), &"wheel"), "with a wheel bolted on its extension 0")
	assert_eq(inventory.free_slots(), 1, "one slot is free")
	assert_true(not garage.lift([1]), "two parts do not fit one slot, so the lift refuses")
	assert_true(layout.get_node([1]) != null, "the strut is still mounted")
	assert_true(layout.get_node([1, 0]) != null, "and its wheel is still bolted on")
	assert_eq(layout.slots.size(), 1, "nothing detached")
	assert_eq(inventory.part_ids.size(), 4, "and the kit gained nothing")
	# Make room and the very same lift lands, which pins that the refusal was the fit.
	assert_eq(inventory.remove_at(0), &"wheel", "one wheel leaves the kit")
	assert_eq(inventory.free_slots(), 2, "so the branch fits")
	assert_true(garage.lift([1]), "and the strut comes off with its wheel")
	assert_eq(inventory.part_ids, [&"wheel", &"wheel", &"wheel", &"strut", &"wheel"],
		"the branch came back whole, parent first")
	garage.free()
	_complete()


func test_lift_refusal_shakes_the_piece() -> void:
	# The refusal is felt: the piece keeps its node and takes the same rotation-only shake
	# ChCard.refuse plays, rather than the pop a successful lift gives.
	var catalog := _catalog()
	var inventory := _inventory([&"wheel", &"wheel", &"wheel", &"wheel"])
	inventory.capacity = ChInventory.CAPACITY
	var layout := _layout(&"cutter")
	# Mounted before the screen is built, so _sync_pit has a piece to draw (the bare test above
	# mounts the same way: the branch is a fixture here, not the thing under test).
	assert_true(layout.place(_typed_path([1]), &"strut"), "the strut is mounted in slot 1")
	assert_true(layout.place(_typed_path([1, 0]), &"wheel"), "with a wheel under it")
	var garage: ChGarage = _garage_scene(inventory, layout, catalog)
	var strut: ChPitPiece = garage.piece_at(_typed_path([1]))
	assert_true(strut != null, "the strut has a pit piece")
	if strut == null:
		_complete()
		return
	var juice := ChJuice.of(strut)
	assert_true(juice != null, "and the piece carries a Juice child")
	assert_true(not garage.lift([1]), "the lift refused")
	assert_true(garage.piece_at(_typed_path([1])) == strut, "the piece was not rebuilt or freed")
	juice.advance(ROTATION_PEAK_STEP)
	assert_near(absf(juice.rotation_value()), _wigged_rotation(deg_to_rad(8.0)), 0.0001,
		"the piece took the 8 degree refusal shake")
	assert_near(juice.scale_value(), 1.0, 0.0001, "with no pop, as ChCard.refuse does")
	_complete()


func test_click_flips() -> void:
	var catalog := _catalog()
	var inventory := _inventory([&"strut", &"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, catalog)
	assert_true(garage.drop_part(&"strut", [1]), "the strut takes cutter slot 1 at (9,4.5)")
	assert_true(garage.drop_part(&"wheel", [1, 1]), "the wheel sits on the strut's extension 1 at (4,-6)")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(13, -1.5), "unflipped parent: 9+4 across, 4.5-6 up")
	garage.click_part([1])
	# A flip turns the mount the other way, so the child's extension x negates: the anchor moves,
	# which is the only visible effect a flip has on a part that owns no range of its own.
	assert_true(layout.get_node([1]).flipped, "the flag toggled")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(5, -1.5), "flipped parent: 9-4 across")
	# The pit reads the layout's own walk now, so this pins the wiring: a second copy in the garage
	# would be free to drift again without it.
	assert_eq(garage.screen_of([1, 1]), garage.CHARIOT_AT + layout.anchor_of([1, 1], catalog) * garage.ZOOM,
		"a flipped nested part sits where the layout says it does")
	garage.click_part([1])
	assert_true(not layout.get_node([1]).flipped, "a second click toggles back")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(13, -1.5), "and the child returns to its cell")
	# ChChariotLayout.toggle_flip answers silently for a path nothing holds; the garage does not
	# add its own check, so a stray click changes nothing rather than losing a part.
	garage.click_part([2])
	assert_true(layout.slots.has(1), "the mounted strut is untouched by a click on an empty slot")
	garage.free()
	_complete()


# --- Task 7: the click chain ----------------------------------------------------------------------
# Placing a part is click, then click: the bar's click hands a part to hold(), and the pit's click is
# the second. Nothing leaves the inventory until a drop lands, so a hold is only a reference the screen
# keeps. The pointer rules live in hold / click_pit / right_click_pit, and these drive them the way the
# screen does.

func test_pick_and_place() -> void:
	var inventory := _inventory([&"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	garage.hold(&"wheel")
	assert_eq(garage.held_id, &"wheel", "a wheel is in hand")
	assert_eq(inventory.part_ids.size(), 2, "picking one up takes nothing out of the kit")
	# The slot's own pixel: screen_of answers for a slot nothing is mounted in yet, which is what a
	# click aimed at an empty marker needs.
	garage.click_pit(garage.screen_of([0]))
	assert_true(layout.get_node([0]) != null, "the second click mounted it in body slot 0")
	assert_eq(layout.get_node([0]).part_id, &"wheel", "as the wheel that was in hand")
	assert_eq(inventory.part_ids.size(), 1, "one wheel left carried")
	assert_eq(garage.held_id, &"", "and nothing is held once it is down")
	garage.free()
	_complete()


func test_hold_toggles() -> void:
	# Holding what is already held puts it back, which is how a player changes their mind without a
	# cancel button. The count check is gone with the strip: the bar owns whether a card can be pressed.
	var garage: ChGarage = _garage(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	garage.hold(&"wheel")
	assert_eq(garage.held_id, &"wheel", "the wheel is picked up")
	garage.hold(&"wheel")
	assert_eq(garage.held_id, &"", "and holding it again clears the hold")
	garage.free()
	_complete()


func test_click_elsewhere_cancels() -> void:
	var inventory := _inventory([&"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	garage.hold(&"wheel")
	# (5,5) is the garage's top-left corner, nowhere near a marker.
	garage.click_pit(Vector2(5, 5))
	assert_eq(garage.held_id, &"", "a click away from every slot puts the part back")
	assert_eq(inventory.part_ids.size(), 2, "and the kit is unchanged")
	assert_eq(layout.slots.size(), 0, "with nothing mounted")
	garage.free()
	_complete()


func test_click_mounted_lifts() -> void:
	# A click with nothing in hand on a mounted part lifts it: the strut takes its wheel with it.
	var inventory := _inventory([&"strut", &"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts in slot 1")
	assert_true(garage.drop_part(&"wheel", [1, 0]), "with a wheel on its extension 0")
	garage.click_pit(garage.screen_of([1]))
	assert_true(layout.get_node([1]) == null, "the strut came off the hull")
	assert_eq(layout.slots.size(), 0, "and took its wheel with it")
	assert_eq(inventory.part_ids.size(), 3, "both back in the kit, with the spare wheel")
	assert_true(inventory.has(&"strut"), "the strut is carried again")
	garage.free()
	_complete()


func test_right_click_flips() -> void:
	var inventory := _inventory([&"strut"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts in slot 1")
	garage.right_click_pit(garage.screen_of([1]))
	assert_true(layout.get_node([1]).flipped, "a right click turned the part round")
	garage.right_click_pit(garage.screen_of([1]))
	assert_true(not layout.get_node([1]).flipped, "and a second turned it back")
	# A right click on empty sand flips nothing at all rather than reaching for a part.
	garage.right_click_pit(Vector2(5, 5))
	assert_true(not layout.get_node([1]).flipped, "with nothing under the pointer, nothing flips")
	garage.free()
	_complete()


func test_drop_onto_strut_extension() -> void:
	# A free extension slot is a marker like any body slot, so the same click places into it: the
	# strut at Cutter slot 2 (-6,-3) hangs its extension 0 one part up.
	var inventory := _inventory([&"strut", &"cutter_chainsaw"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [2]), "the strut mounts in slot 2")
	garage.hold(&"cutter_chainsaw")
	garage.click_pit(garage.screen_of([2, 0]))
	assert_true(layout.get_node([2, 0]) != null, "the chainsaw bolted onto the strut's extension 0")
	assert_eq(layout.get_node([2, 0]).part_id, &"cutter_chainsaw", "as the chainsaw")
	assert_eq(garage.held_id, &"", "with the hold cleared")
	assert_true(inventory.part_ids.is_empty(), "and nothing left carried")
	garage.free()
	_complete()


func test_copy_of_build() -> void:
	# A deep copy of the build, so a caller can hand a fight a layout the fight cannot mutate
	# (ChBattle mirrors whatever it is given).
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(_inventory([&"wheel", &"wheel"]), layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "one mount, so the copy has a node to copy")
	var copy: ChChariotLayout = garage._copy_of_build()
	assert_true(copy.get_instance_id() != layout.get_instance_id(), "not the garage's instance")
	assert_true(copy.get_node([0]).get_instance_id() != layout.get_node([0]).get_instance_id(),
		"deep copy: even the node is new")
	assert_eq(copy.body_id, layout.body_id, "carrying the same body")
	assert_eq(copy.slots.size(), layout.slots.size(), "and the same mounts")
	assert_true(copy.get_node([0]).part_id == layout.get_node([0]).part_id, "the same part")
	# The copy keeps the same flips, because the pit and the fight have to agree on which way a
	# part faces (mirrored() would have inverted them, which is how an enemy build is sent).
	var copy_flip := copy.get_node([0]).flipped
	assert_eq(copy_flip, layout.get_node([0]).flipped, "the copy faces the same way")
	layout.toggle_flip([0])
	assert_true(layout.get_node([0]).flipped, "the garage's own mount changed")
	assert_eq(copy.get_node([0]).flipped, copy_flip, "and the copy kept its own flip")
	garage.free()
	_complete()


# --- Task 7: the built screen ---------------------------------------------------------------------
# The rebuild is a scene, so these tests instance garage.tscn: the pit's input surface, the hull and
# the tooltip only exist once the scene does. Everything above stays a bare ChGarage because the logic
# methods must work with no nodes at all (ChMain calls setup before add_child).

func _garage_scene(inventory: ChInventory, layout: ChChariotLayout,
	catalog: ChCatalog) -> ChGarage:
	# setup() before add_child, the order ChMain uses, so _enter_tree builds the pit from the layout
	# and the catalog it was handed.
	var scene: PackedScene = ResourceLoader.load(GARAGE_SCENE)
	assert_true(scene != null, "garage.tscn loads")
	var garage: ChGarage = scene.instantiate()
	garage.setup(inventory, layout, catalog)
	Engine.get_main_loop().get_root().add_child(garage)
	_track(garage)
	return garage


func _button(at: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	Engine.get_main_loop().get_root().push_input(event, true)


func _move(at: Vector2) -> void:
	# A motion, the way the pit reads the pointer: the hover, the tooltip and the marker nearest the
	# pointer all come from these, so a test that only clicks would never drive them.
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Engine.get_main_loop().get_root().push_input(motion, true)


func test_no_hint_labels() -> void:
	# The brief's rule: no screen says how to play. The embeddable pit's only text is the part
	# tooltip's, and the tooltip is hidden until something is hovered.
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	var hints: Array = []
	for node in garage.find_children("*", "Label", true, false):
		var text: String = node.text
		if text.begins_with("Click") or text.begins_with("Holding"):
			hints.append(text)
	assert_eq(hints, [], "no label tells the player what to click")
	assert_true(not garage.tooltip.visible, "the tooltip is away until something is hovered")
	_complete()


# --- Task 9: the pit as nodes --------------------------------------------------------------------
# The hull and every mounted part are nodes under $Pit now, in a PitView that undoes the pit's own
# offset, so a part can be moved by a juice beat without repainting the screen. The markers and the
# hover box keep their own draws between the parts, which is the same paint order the one `_draw`
# used to give. These five pin the tree the garage's feedback task attaches to: where a piece sits,
# that an unrelated change leaves it alone, that a lift takes its subtree's pieces with it, that the
# hull follows the body, and that order.

func test_pit_pieces_match_layout() -> void:
	var catalog := _catalog()
	var garage: ChGarage = _garage_scene(_inventory([&"wheel", &"wheel"]), _layout(&"cutter"), catalog)
	assert_true(garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	assert_true(garage.drop_part(&"wheel", [1]), "as the other")
	var wheel: ChPartDef = catalog.part(&"wheel")
	for path in [[0], [1]]:
		var typed := _typed_path(path)
		var piece: ChPitPiece = garage.piece_at(typed)
		assert_true(piece != null, "the part at %s has a piece" % [typed])
		if piece == null:
			continue
		# The drawn box's centre is where the part was painted before the split, so a piece that
		# sits anywhere else would have moved the whole pit.
		assert_eq(piece.position, garage._box_at(garage.screen_of(typed), wheel).get_center(),
			"the piece sits where the part's box is centred")
	var parts: Node = garage.get_node("Pit/PitView/Parts")
	assert_eq(parts.get_child_count(), 2, "one piece per mounted part, and nothing left behind")
	_complete()


func test_piece_survives_unrelated_change() -> void:
	# A part that did not change keeps its node, and with it the beat still in flight on it:
	# a rebuild would silently drop a wobble that is still running.
	var inventory := _inventory([&"wheel", &"wheel"])
	var garage: ChGarage = _garage_scene(inventory, _layout(&"cutter"), _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "the first wheel mounts")
	var first: ChPitPiece = garage.piece_at(_typed_path([0]))
	assert_true(first != null, "its piece exists")
	if first == null:
		_complete()
		return
	var juice := ChJuice.of(first)
	assert_true(juice != null, "the piece carries a Juice child")
	juice.juice_up(0.2, 0.1)
	juice.advance(PEAK_STEP)
	var bent := juice.scale_value()
	assert_true(garage.drop_part(&"wheel", [1]), "a second wheel lands in another slot")
	assert_true(garage.piece_at(_typed_path([0])) == first,
		"the first piece is the same instance after the second drop")
	assert_eq(ChJuice.of(first).scale_value(), bent,
		"and its beat is still running, so nothing rebuilt the piece under it")
	_complete()


func test_lift_frees_subtree_pieces() -> void:
	var inventory := _inventory([&"strut", &"wheel"])
	var garage: ChGarage = _garage_scene(inventory, _layout(&"cutter"), _catalog())
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts in slot 1")
	assert_true(garage.drop_part(&"wheel", [1, 0]), "with a wheel on its extension 0")
	var strut: ChPitPiece = garage.piece_at(_typed_path([1]))
	var wheel: ChPitPiece = garage.piece_at(_typed_path([1, 0]))
	assert_true(strut != null and wheel != null, "the branch has a piece per part")
	if strut == null or wheel == null:
		_complete()
		return
	# A beat still running when its piece is freed is the case the pieces have to survive: the
	# juice node goes with the piece, so the frames after a lift must not move a freed target.
	ChJuice.of(strut).juice_up(0.2, 0.1)
	ChJuice.of(wheel).juice_up(0.2, 0.1)
	assert_true(garage.lift([1]), "lifting the strut takes the whole branch")
	assert_true(garage.piece_at(_typed_path([1])) == null, "the strut's piece is gone")
	assert_true(garage.piece_at(_typed_path([1, 0])) == null, "and the wheel's with it")
	assert_eq(garage.get_node("Pit/PitView/Parts").get_child_count(), 0, "nothing is left drawn")
	for _frame in 3:
		await Engine.get_main_loop().process_frame
	_complete()


func test_pit_hull_follows_body() -> void:
	# The pit draws whatever body the layout names, and a piece sits where the layout says: the hull
	# comes from the def, never from where the last body left it. The body is set before the screen is
	# built here, because the swap itself is the shop's (Task 12) and no button cycles it any more.
	var catalog := _catalog()
	var layout := _layout(&"dozer")
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), layout, catalog)
	var hull: ChPitPiece = garage.hull_piece()
	assert_true(hull != null, "the pit has a hull piece")
	if hull == null:
		_complete()
		return
	# Cutter 34x9 cells, Dozer 22x30: the piece shows the body the layout is on.
	assert_eq(hull.body_def.size, catalog.body(&"dozer").size, "drawing the Dozer's hull")
	assert_true(garage.drop_part(&"wheel", [0]), "a wheel mounts in Dozer slot 0")
	var piece: ChPitPiece = garage.piece_at(_typed_path([0]))
	assert_true(piece != null, "the wheel has a piece")
	if piece == null:
		_complete()
		return
	assert_eq(piece.position,
		garage._box_at(garage.screen_of(_typed_path([0])), catalog.part(&"wheel")).get_center(),
		"and it sits where the layout's slot 0 is")
	_complete()


func test_pit_draw_order() -> void:
	# The order the one `_draw` painted in, now as siblings: hull, free-slot markers, parts, the
	# dragged piece, hover. After the pit view come the held layer and the tooltip, which stay on top.
	var garage: ChGarage = _garage_scene(_inventory([]), _layout(&"cutter"), _catalog())
	var pit: Control = garage.get_node("Pit")
	var view: Node = pit.get_child(0)
	assert_eq(view.name, &"PitView", "the pit's first child is the pit view")
	if view.name != &"PitView":
		_complete()
		return
	# The view undoes the pit's own offset, so a piece's position is a garage pixel - what
	# screen_of and _box_at answer in - and the pit cannot drift 60 px down unnoticed.
	assert_eq((view as Node2D).get_global_transform().origin, garage.get_global_transform().origin,
		"the pit view sits at the garage's own origin")
	var hull := view.get_node("Hull").get_index()
	var markers := view.get_node("Markers").get_index()
	var parts := view.get_node("Parts").get_index()
	var drag := view.get_node("Drag").get_index()
	var hover := view.get_node("Hover").get_index()
	assert_true(hull < markers, "the hull draws under the free-slot markers")
	assert_true(markers < parts, "the markers draw under the mounted parts")
	assert_true(parts < drag, "the dragged piece draws over the mounted ones")
	assert_true(drag < hover, "and the hover box draws over everything")
	_complete()


func _ready_garage(ids: Array) -> ChGarage:
	var garage := _garage_scene(_inventory(ids), _layout(&"cutter"), _catalog())
	for i in 2:
		await Engine.get_main_loop().process_frame
	return garage

func test_tooltip_hidden_while_held() -> void:
	# A part in hand hides the tooltip: the pointer is carrying something, so naming what it is over
	# would be the wrong thing to read. Putting it back lets the hull's hover show it again.
	var garage: ChGarage = await _ready_garage([&"wheel", &"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	_move(garage.get_global_position() + garage.screen_of([0]))
	assert_true(garage.tooltip.visible, "hovering the mounted wheel shows it")
	garage.hold(&"wheel")
	assert_true(not garage.tooltip.visible, "a part in hand hides it")
	_move(garage.get_global_position() + garage.screen_of([0]))
	assert_true(not garage.tooltip.visible, "and it stays hidden while held")
	garage.cancel_hold()
	assert_true(garage.tooltip.visible, "putting it back lets hover show it again")
	_complete()


func test_tooltip_on_hull_part() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	var at := garage.get_global_position() + garage.screen_of([0])
	_move(at)
	assert_true(garage.tooltip.visible)
	assert_eq(garage.tooltip.def.id, &"wheel")
	_move(Vector2(100, 500))
	assert_true(not garage.tooltip.visible, "moving off the hull hides it")
	_complete()

func test_tooltip_leaving_pit_clears_hull_hover() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	_move(garage.get_global_position() + garage.screen_of([0]))
	garage.get_node("Pit").mouse_exited.emit()
	assert_true(not garage.tooltip.visible, "leaving the pit drops the hull hover")
	_move(Vector2(100, 500))
	assert_true(not garage.tooltip.visible, "and a motion off the hull brings no stale tooltip back")
	_complete()

func test_no_info_panel_left() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.get_node_or_null("Pit/InfoPanel") == null)
	assert_true(not "hook_text" in ChPartDef.new(), "hook_text is gone")
	_complete()

# --- Task 10: the embeddable pit ------------------------------------------------------------------
# The bar owns the cards now, so the garage's half of a mount is by index: the bar says which copy and
# which slot, and a refusal leaves the part where the bar still shows it. The pit itself is dragged:
# a press that moves past 6 px takes the mounted piece off the pit and a release says where it went,
# which is the call Task 12 turns into a lift or a sell.

func test_mount_from_inventory() -> void:
	var inventory := _inventory([&"wheel", &"cutter_chainsaw"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.mount_from_inventory(1, [0]), "the chainsaw at the bar's index 1 mounts")
	assert_eq(layout.get_node([0]).part_id, &"cutter_chainsaw", "in body slot 0")
	assert_eq(inventory.part_ids, [&"wheel"], "and that copy left the kit")
	# The index is the handle, so the duplicate case takes the copy the bar pointed at, not the first.
	var dupes := _inventory([&"wheel", &"wheel"])
	var other := _layout(&"cutter")
	var second: ChGarage = _garage(dupes, other, _catalog())
	assert_true(second.mount_from_inventory(0, [1]), "index 0 mounts")
	assert_eq(dupes.part_ids.size(), 1, "one wheel left carried")
	assert_true(other.get_node([1]) != null, "on the slot the caller named")
	garage.free()
	second.free()
	_complete()


func test_mount_refused_restores() -> void:
	var inventory := _inventory([&"wheel", &"strut"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(layout.place(_typed_path([0]), &"strut"), "slot 0 is already taken")
	assert_true(not garage.mount_from_inventory(0, [0]), "a taken slot refuses the mount")
	assert_eq(inventory.part_ids, [&"wheel", &"strut"], "the kit is unchanged and in the same order")
	assert_eq(layout.get_node([0]).part_id, &"strut", "and the slot still holds what it held")
	# Nothing in the hand of a bar that is out of range either.
	assert_true(not garage.mount_from_inventory(9, [0]), "an index the kit has not got is refused")
	assert_eq(inventory.part_ids, [&"wheel", &"strut"], "with the kit untouched")
	garage.free()
	_complete()


func test_slot_at_global() -> void:
	# The bar hands a screen point in, so the pit converts it to its own pixels before asking which
	# marker is near: this is the drop-zone test an inventory card's release uses. The pit is placed
	# off the origin on purpose: at (0,0) screen pixels and pit pixels are the same number, so a
	# missing conversion would pass here and ship a wrong inverse to the bar.
	var garage: ChGarage = _garage_scene(_inventory([]), _layout(&"cutter"), _catalog())
	garage.position = Vector2(37, 23)
	assert_eq(garage.get_global_position(), Vector2(37, 23),
		"the pit sits off the origin, so screen and pit pixels differ")
	var marker: Vector2 = garage.screen_of([0])
	var at: Vector2 = garage.get_global_position() + marker
	var slot: Array = garage.slot_at(at)
	assert_true(not slot.is_empty(), "the screen point of a free marker names a slot")
	if slot.is_empty():
		_complete()
		return
	assert_eq(slot[0], _typed_path([0]), "the slot the marker belongs to")
	# And the other way: pit pixels handed in as if they were screen pixels are a pit-offset away,
	# so they must not name that same marker.
	assert_eq(garage.slot_at(marker), [], "the unconverted pit pixels name no slot")
	# A point far from every marker has no drop zone either.
	assert_eq(garage.slot_at(at + Vector2(-300, -200)), [], "a point far from the hull names no slot")
	_complete()


func test_piece_drag_emits() -> void:
	# Past 6 px the press is a drag: the piece follows the pointer and the release says where it was
	# let go, in screen pixels. Task 12 decides what a release over the bar means; the pit does not
	# lift anything itself.
	var inventory := _inventory([&"strut"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage_scene(inventory, layout, _catalog())
	# Off the origin, so the pointer's screen pixels and the pit's own pixels differ: a release that
	# skipped the way back would report a point a pit-offset away from where it happened.
	garage.position = Vector2(37, 23)
	assert_eq(garage.get_global_position(), Vector2(37, 23),
		"the pit sits off the origin, so screen and pit pixels differ")
	assert_true(garage.drop_part(&"strut", [1]), "the strut mounts in slot 1")
	var dropped: Array = []
	var sink := dropped
	garage.piece_dropped.connect(func(path: Array[int], at: Vector2): sink.append([path, at]))
	var from: Vector2 = garage.get_global_position() + garage.screen_of([1])
	var to: Vector2 = from + Vector2(0, 10)
	_button(from, true)
	_move(to)
	_button(to, false)
	assert_eq(dropped.size(), 1, "a release past the 6 px emitted once")
	if dropped.is_empty():
		_complete()
		return
	assert_eq(dropped[0][0], _typed_path([1]), "with the path the drag picked up")
	assert_eq(dropped[0][1], to, "and the pointer where it was let go")
	# The pit decided nothing: the strut is still mounted until the owner says what the drop means.
	assert_true(layout.get_node([1]) != null, "the drop itself lifted nothing")
	# Under the 6 px it is a click, which is today's lift.
	var clicks := 0
	var count := clicks
	garage.piece_dropped.connect(func(_path: Array[int], _at: Vector2): count += 1)
	_button(from, true)
	_move(from + Vector2(0, 3))
	_button(from + Vector2(0, 3), false)
	assert_eq(count, 0, "a 3 px release is a click, not a drag")
	assert_true(layout.get_node([1]) == null, "and the click lifted the strut as it always did")
	_complete()


func test_changed_after_every_change() -> void:
	# The bar refreshes on `changed`, so every mount, lift and flip announces itself and a refusal
	# does not: the bar has nothing to redraw for a state that did not move.
	var inventory := _inventory([&"strut", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage_scene(inventory, layout, _catalog())
	var seen: Array[int] = []
	var sink := seen
	garage.changed.connect(func(): sink.append(1))
	assert_true(garage.mount_from_inventory(0, [1]), "the strut mounts")
	assert_eq(seen.size(), 1, "a mount announced itself")
	garage.click_part([1])
	assert_eq(seen.size(), 2, "a flip announced itself")
	assert_true(garage.lift([1]), "the strut comes home")
	assert_eq(seen.size(), 3, "a lift announced itself")
	assert_true(garage.mount_from_inventory(1, [1]), "the strut mounts again, off the kit's index 1")
	assert_eq(seen.size(), 4, "the second mount announced itself too")
	assert_true(not garage.mount_from_inventory(0, [1]), "the taken slot refuses")
	assert_eq(seen.size(), 4, "and a refusal says nothing")
	assert_true(garage.drop_part(&"wheel", [0]), "a drop mounts")
	assert_eq(seen.size(), 5, "and announced itself")
	_complete()
