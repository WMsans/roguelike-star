extends ChTest

# Task 16: the garage's logic — the inventory handshakes (drop, lift), the flip click, the body
# cycle and the copy `fight_requested` hands the battle. ChGarage.setup is what a scene calls
# before any of these, so every test builds its own garage, inventory and layout: a garage owns
# the references it was handed, so a shared one would carry an earlier test's mounts.
# The UI is built on these same methods, so the click chain below drives the same rules a mouse does.
# Task 7 replaced the drag with click-then-click, so the pointer rules are methods now and the tests
# below follow the brief's own wording: `-- test_garage` runs them all, and the two scene tests plus
# the input test at the end instance the shipped garage.tscn rather than a bare ChGarage.
# ChMain end to end (review finding 3): the brief's headline deliverable is the round trip -
# garage -> one battle -> result -> garage - and nothing above ever ran it. The seam is the
# shipped scene rather than a copy of ChMain's loop, which is also where the scene's own nodes
# get pinned: ChMain makes its screen in code, so main.tscn must not instance a second garage
# (review finding 2) drawing "Fight" over the live one.
# Cheapness: a fight stops at its own result (Task 3), so the round trip's low-HP enemy ends the
# fight in seconds instead of paying ChBattle's whole 3600-tick budget; only the draw test pays that,
# because a draw IS the budget running out. The three tests that pinned a fight still ticking behind
# the result window - the watchdog hand-back, the hidden fight's release and ChMain's retiring list -
# are gone with that machinery: Task 6 replaced them with the result panel and its back button.
const MAIN_SCENE := "res://game/main.tscn"
# The screen under test for the parts strip and the input path: ChMain instances this file too.
const GARAGE_SCENE := "res://game/garage/garage.tscn"
# A hull no fight ends: with both sides on this only the time limit can decide the fight, which is
# how test_main_draw_panel reaches the draw panel (test_battle.gd spells the same value for its half).
const TALL_HP := 100000
# The wait's cap in frames, not seconds: the fight is frame-driven (one tick per awaited frame), so
# WORLD_WAIT frames of arena streaming plus FIGHT_TICKS ticks is the exact worst case on any machine,
# and a screen that never changes still fails in a bounded run instead of hanging the suite.
const SCREEN_FRAMES := 6000


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
	# shortcut: a body_id the catalog has no def for stays a caller error; cycle_body's refusal
	# is what such a layout shows, and setup invents no rule of its own.
	layout.body_id = body_id
	return layout


func _main_scene() -> ChMain:
	# The shipped scene, so the test drives ChMain's own loop rather than restating it. ChMain
	# extends Node (it draws nothing), so it goes under the runner's root viewport like every
	# other node these tests add. ChMain._init builds the kit, the layout and the first screen,
	# so the instance answers the round trip with no setup of its own.
	var scene: PackedScene = ResourceLoader.load(MAIN_SCENE)
	assert_true(scene != null, "main.tscn loads")
	var main: ChMain = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(main)
	# Finding 2: the screen lives once, and it is the one ChMain made. A second garage.tscn in
	# main.tscn would draw its own "Body"/"Fight" pair on the same rects, so pick order alone
	# would decide which button the pointer reaches - and that instance is never setup().
	var screens := 0
	for child in main.get_children():
		# shortcut: one level deep, which is main.tscn's own shape: the panel layer and the garage.
		if child is ChGarage:
			screens += 1
	assert_eq(screens, 1, "the tree holds exactly one garage, the one ChMain made")
	assert_true(main.garage != null, "and ChMain made it")
	return main


# The wait the ChMain tests use: frames until ChMain's own screen is `want`. ChMain.screen is the
# state (garage, fight, result) that the deleted bottom-left label used to be read for, and nothing
# here counts ChMain's frames any more - the fight's ticks do, so a frame cap is the honest bound.
# The cap costs a silent screen one test's failure rather than hanging the run; every caller asserts
# the screen it waited for, so a capped wait reads as the failure it is.
func _wait_screen(main: ChMain, want: StringName) -> void:
	var frames := 0
	while main.screen != want and frames < SCREEN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1


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
# Placing a part is click, then click, and there is no hold-to-drag any more: the strip's card is the
# first click and the pit is the second. The rules the deleted pointer polling used to carry live in
# pick_part / click_pit / right_click_pit now, and these drive them the way the screen does. Nothing
# leaves the inventory until a drop lands, so a hold is only a reference the screen keeps.

func test_pick_and_place() -> void:
	var inventory := _inventory([&"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.pick_part(&"wheel"), "a carried wheel is picked up")
	assert_eq(garage.held_id, &"wheel", "and it is the one in hand")
	assert_eq(inventory.part_ids.size(), 2, "picking one up takes nothing out of the kit")
	# The slot's own pixel: screen_of answers for a slot nothing is mounted in yet, which is what a
	# click aimed at an empty marker needs.
	garage.click_pit(garage.screen_of([0]))
	assert_true(layout.get_node([0]) != null, "the second click mounted it in body slot 0")
	assert_eq(layout.get_node([0]).part_id, &"wheel", "as the wheel that was in hand")
	assert_eq(garage.card_counts()[&"wheel"], 1, "one wheel left carried")
	assert_eq(garage.held_id, &"", "and nothing is held once it is down")
	garage.free()
	_complete()


func test_pick_empty_refused() -> void:
	# Carrying none of a part: its card is disabled, and the rule behind the card refuses too.
	var garage: ChGarage = _garage(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	assert_true(not garage.pick_part(&"ice_cream_mace"), "a part the kit has none of is refused")
	assert_eq(garage.held_id, &"", "and nothing is in hand")
	# Picking what is already held puts it back, which is how a player changes their mind without
	# a cancel button.
	assert_true(garage.pick_part(&"wheel"), "the wheel is picked up")
	assert_true(garage.pick_part(&"wheel"), "picking it again is allowed")
	assert_eq(garage.held_id, &"", "and clears the hold")
	garage.free()
	_complete()


func test_click_elsewhere_cancels() -> void:
	var inventory := _inventory([&"wheel", &"wheel"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.pick_part(&"wheel"), "a wheel is in hand")
	# (5,5) is the garage's top-left corner, nowhere near a marker.
	garage.click_pit(Vector2(5, 5))
	assert_eq(garage.held_id, &"", "a click away from every slot puts the part back")
	assert_eq(garage.card_counts()[&"wheel"], 2, "and the kit is unchanged")
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
	assert_eq(garage.card_counts()[&"strut"], 1, "which the strip shows straight away")
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


func test_cycle_back() -> void:
	# Cutter -> Corsair is one step backwards down BODIES, which is what the top bar's left button
	# does; the forward direction is already pinned by the leftover test above.
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(_inventory([]), layout, _catalog())
	garage.cycle_body(-1)
	assert_eq(layout.body_id, &"corsair", "a step of -1 walks the cycle backwards")
	garage.cycle_body()
	assert_eq(layout.body_id, &"cutter", "and the default step walks it forward again")
	garage.free()
	_complete()


# Review focus for this task: a fight asked for, or a body swapped, while a part is in hand must not
# lose or duplicate it. Nothing leaves the inventory until a drop, so the hold is the only thing that
# can go wrong, and clearing it is the whole fix.
func test_fight_while_holding_keeps_inventory() -> void:
	var inventory := _inventory([&"wheel", &"wheel", &"cutter_rocket", &"strut"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.pick_part(&"wheel"), "a wheel is in hand")
	var before := inventory.part_ids.duplicate()
	var handed: Array = []
	var sink := handed
	garage.fight_requested.connect(func(copy: ChChariotLayout): sink.append(copy))
	garage.request_fight()
	assert_eq(handed.size(), 1, "the fight was still asked for")
	assert_eq(garage.held_id, &"", "the click into a fight dropped the hold")
	assert_eq(inventory.part_ids, before, "and the kit is exactly what it was")
	assert_eq(handed[0].slots.size(), 0, "the copy holds nothing the hold might have dropped")
	# The same for a body swap: the carried part is still carried, and the hold is gone.
	assert_true(garage.pick_part(&"cutter_rocket"), "the rocket is in hand")
	garage.cycle_body()
	assert_eq(garage.held_id, &"", "a body swap drops the hold too")
	assert_eq(inventory.part_ids, before, "with the kit untouched again")
	assert_eq(layout.body_id, &"dozer", "and the swap itself happened")
	garage.free()
	_complete()


func test_drop_onto_strut_extension() -> void:
	# A free extension slot is a marker like any body slot, so the same click places into it: the
	# strut at Cutter slot 2 (-6,-3) hangs its extension 0 one part up.
	var inventory := _inventory([&"strut", &"cutter_chainsaw"])
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"strut", [2]), "the strut mounts in slot 2")
	assert_true(garage.pick_part(&"cutter_chainsaw"), "the chainsaw is in hand")
	garage.click_pit(garage.screen_of([2, 0]))
	assert_true(layout.get_node([2, 0]) != null, "the chainsaw bolted onto the strut's extension 0")
	assert_eq(layout.get_node([2, 0]).part_id, &"cutter_chainsaw", "as the chainsaw")
	assert_eq(garage.held_id, &"", "with the hold cleared")
	assert_eq(garage.card_counts()[&"strut"], 0, "the strut is mounted, so the strip carries none")
	garage.free()
	_complete()


func test_cycle_body_keeps_parts_and_returns_leftovers() -> void:
	# Corsair slots sit at (-21,5),(21,5),(-20,-5),(-10,-5),(4,-5),... and the Cutter's four at
	# (-10,4.5),(9,4.5),(-6,-3),(6,-3). swap_body pairs them greedily by distance as a share of each
	# hull's size, so every mount moves except the strut at Corsair slot 2 (-20,-5): the Battery at
	# slot 3 is nearer the Cutter's rear top slot and takes it first.
	var inventory := _inventory([&"wheel", &"wheel", &"strut", &"wheel", &"ember_battery",
	    &"cutter_rocket"])
	var layout := _layout(&"corsair")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "Corsair slot 0 at (-21,5)")
	assert_true(garage.drop_part(&"wheel", [1]), "Corsair slot 1 at (21,5)")
	assert_true(garage.drop_part(&"strut", [2]), "Corsair slot 2 at (-20,-5)")
	assert_true(garage.drop_part(&"wheel", [2, 0]), "a wheel bolted under that strut")
	assert_true(garage.drop_part(&"ember_battery", [3]), "Corsair slot 3 at (-10,-5)")
	assert_true(garage.drop_part(&"cutter_rocket", [4]), "Corsair slot 4 at (4,-5)")
	assert_true(inventory.part_ids.is_empty(), "six drops left the inventory empty")
	garage.cycle_body()
	# Cutter -> Dozer -> Corsair -> Cutter, so a build starting on Corsair wraps to Cutter.
	assert_eq(layout.body_id, &"cutter", "the cycle moved one body on")
	assert_eq(layout.slots.size(), 4, "four of the five mounts found a Cutter slot")
	assert_eq(layout.get_node([0]).part_id, &"wheel", "the wheels kept a top-level slot each")
	assert_eq(layout.get_node([1]).part_id, &"wheel", "as did the other")
	assert_eq(layout.get_node([2]).part_id, &"ember_battery", "the Ember Battery took slot 2")
	assert_eq(layout.get_node([3]).part_id, &"cutter_rocket", "the Rocket took slot 3")
	assert_true(layout.get_node([2, 0]) == null, "and the branch that came back left nothing behind")
	# A leftover comes back as its whole subtree, so the ids travel parent first.
	assert_eq(inventory.part_ids, [&"strut", &"wheel"], "the branch came back whole, parent first")
	garage.cycle_body()
	# Cutter -> Dozer: the Tower has six slots for four mounts, so nothing is left over. Scaled to
	# each hull, the wheels stay on the bottom edge and the Cutter's two top slots sit nearest the
	# Tower's roof slots (4, 5), not its mid-side ones (2, 3).
	assert_eq(layout.body_id, &"dozer", "and the cycle keeps going")
	assert_eq(layout.slots.size(), 4, "all four fit the Dozer")
	assert_eq(inventory.part_ids, [&"strut", &"wheel"], "and the same two carried parts")
	assert_eq(layout.get_node([0]).part_id, &"wheel", "the wheels stayed on the bottom edge")
	assert_eq(layout.get_node([1]).part_id, &"wheel", "both of them")
	assert_eq(layout.get_node([4]).part_id, &"ember_battery", "the Ember Battery moved to slot 4")
	assert_eq(layout.get_node([5]).part_id, &"cutter_rocket", "and the Rocket to slot 5")
	garage.free()
	_complete()


func test_fight_emits_layout_copy() -> void:
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage(_inventory([&"wheel", &"wheel"]), layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "one mount, so the copy has a node to copy")
	var handed: Array = []
	var sink := handed
	garage.fight_requested.connect(func(copy: ChChariotLayout): sink.append(copy))
	garage.request_fight()
	assert_eq(handed.size(), 1, "Fight hands over exactly one layout")
	var copy: ChChariotLayout = handed[0]
	# The brief's point: the battle receives a copy, so it can never mutate the garage's build
	# (ChBattle mirrors the layout it is given).
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


func test_main_round_trip() -> void:
	var main: ChMain = _main_scene()
	# The kit, pinned: every part id the slice owns, two copies each, plus the four wheels.
	# shortcut: ChCatalog.load_default is the source ChMain spells the kit from, so the expected
	# counts come from it rather than a second hand-written list that can drift.
	# shortcut: the ids are counted rather than ordered; ChInventory.add appends in ChMain's own
	# list order, which is the kit's spelling and nobody's rule.
	var counts: Dictionary = {}
	for id in main.inventory.part_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	for def in ChCatalog.load_default().parts.values():
		assert_eq(counts.get(def.id, 0), 4 if def.id == &"wheel" else 2, "two of each part, four wheels")
	# The build the fight runs, mounted through the garage's own hand: wheels to move and a
	# Rocket in the Cutter's front slot, unflipped so it fires +x (Task 15's fight build).
	assert_true(main.garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	assert_true(main.garage.drop_part(&"wheel", [1]), "as the other")
	assert_true(main.garage.drop_part(&"cutter_rocket", [3]), "and the Rocket")
	# The pin's identity check: ChMain owns ONE layout and ONE inventory whatever the loop does, so
	# the garage that comes back is the same two halves with the same build on them.
	var build_id := main.layout.get_instance_id()
	var carried := main.inventory.part_ids.size()  # the kit minus the three parts just mounted
	# The fight is asked for the way the UI asks: the "Fight" Button's pressed signal is wired to
	# request_fight, so calling that method is what pressing the button does.
	var results: Array[StringName] = []
	var sink := results
	main.garage.request_fight()
	assert_true(main.battle != null, "the fight started, as an instantiated battle.tscn")
	assert_eq(main.screen, &"fight", "and the loop left the garage for it")
	# No Space key headless, and the volley is press-driven: the player presses by the enemy's rule.
	main.battle.pressers[0] = func(b, s): return b.ai_press(s)
	# ChBattle is an awaited coroutine, so the battle exists before its arena has loaded; the
	# signal is watched from outside as well, so the result ChMain read is the one it announced.
	main.battle.finished.connect(func(result: StringName): sink.append(result))
	# The enemy's HP goes low, the way Task 15's test_battle_finishes overrides it, so `finished`
	# fires seconds into the fight rather than after its whole 60 s budget.
	# shortcut: the override is runtime rather than a hand-built catalog; the def on disk is one
	# shared instance, so mutating it would make another task's Dozer fragile.
	# shortcut: 1 HP rather than 0, so the low value has to take a hit rather than reading dead
	# before the fight could; the probe measured ~4.6 HP/s of damage arriving.
	var frames := 0
	while main.battle.enemy == null and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	if main.battle.enemy != null:
		main.battle.enemy.hp = 1
	await _wait_screen(main, &"result")
	assert_eq(results, [&"win"], "the loop saw the fight's result, a win for the low-HP enemy")
	assert_eq(main.screen, &"result", "and the fight stopped on the result screen")
	assert_eq(main.result_panel.title.text, "You win", "the panel named the win")
	assert_true(not main.garage.is_visible_in_tree(), "the garage stays away under it")
	# The fight is still on screen behind the panel - a still picture, because ChBattle stopped at its
	# own result (Task 3) - and it is the panel's back button that frees it, not a window closing.
	# What the fight itself does at its result is pinned in test_battle.gd.
	var fought := main.battle
	assert_true(is_instance_valid(fought), "the ended fight is still in the tree under the panel")
	# A second `finished` is a contract violation, but the panel is the whole result screen: a second
	# one would stack over the first, so the handler refuses once a panel exists.
	fought.finished.emit(&"win")
	assert_eq(main.find_children("*", "ChResultPanel", true, false).size(), 1,
		"a second finished does not stack a second panel")
	assert_eq(main.screen, &"result", "and the screen is still the one panel")
	main.result_panel.back.pressed.emit()
	assert_eq(main.screen, &"garage", "back went to the garage")
	assert_true(main.garage != null and main.garage.is_visible_in_tree(), "as a live screen again")
	# The build and the kit come back untouched whatever the loop did in between: ChMain owns ONE
	# layout and ONE inventory, and the fight only ever got a copy.
	assert_true(main.layout.get_instance_id() == build_id, "the SAME layout instance, not a rebuilt one")
	assert_eq(main.layout.slots.size(), 3, "still holding exactly the three mounts it was given")
	var rocket := main.layout.get_node([3])
	assert_true(rocket != null and rocket.part_id == &"cutter_rocket", "the Rocket in the same slot")
	assert_eq(main.inventory.part_ids.size(), carried, "and the same parts carried")
	assert_true(main.battle == null, "and ChMain released the ended fight, node and reference")
	assert_true(not is_instance_valid(fought), "the fight node itself is gone")
	main.free()
	_complete()


# Review Focus 5 on ChMain's side: a fight whose time runs out reaches the result panel instead of
# leaving the game on a screen that never names anything. The HP override travels as a catalog
# (ChTest._fight_catalog), so the fight really does run its whole 3600-tick budget: this is the one
# test here that pays ChBattle's full clock, because a draw IS the clock running out.
func test_main_draw_panel() -> void:
	var main: ChMain = _main_scene()
	# The same build the round trip fights with, so the player has a weapon; TALL_HP means nothing it
	# fires can end the fight early.
	assert_true(main.garage.drop_part(&"wheel", [0]), "body slot 0 takes a wheel")
	assert_true(main.garage.drop_part(&"wheel", [1]), "as the other")
	assert_true(main.garage.drop_part(&"cutter_rocket", [3]), "and the Rocket")
	main.catalog = _fight_catalog(TALL_HP, TALL_HP)
	# ChMain fights the cached dozer_cook layout, whose own max_hp (1800) wins over the catalog's
	# TALL_HP, so the cached copy's max_hp is cleared for this fight and put back after it.
	var cook: ChChariotLayout = ResourceLoader.load(ChMain.ENEMY)
	var cook_hp := cook.max_hp
	cook.max_hp = 0
	main.garage.request_fight()
	assert_eq(main.screen, &"fight", "the fight started")
	await _wait_screen(main, &"result")
	cook.max_hp = cook_hp
	assert_eq(main.screen, &"result", "the timeout reached the result screen rather than hanging")
	assert_eq(main.result_panel.title.text, "Draw: time ran out", "and the panel named the draw")
	assert_true(main.battle != null and not main.battle.ticking, "on a fight that has stopped")
	main.free()
	_complete()


# Review Focus: "Back to garage" pressed twice in one frame. The first press is the hand-back; the
# second has to be a no-op rather than a second garage build, which would throw away the screen the
# first press just made. The panel is queue_free'd rather than freed (freeing a Button from inside
# its own `pressed` signal is not safe), so the second press still reaches this node's handler - and
# the garage's instance id is what tells the two outcomes apart, because a rebuild would leave one
# garage in the tree either way.
func test_back_twice_one_garage() -> void:
	var main: ChMain = _main_scene()
	main.garage.request_fight()
	var frames := 0
	while main.battle.enemy == null and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	if main.battle.enemy != null:
		main.battle.enemy.hp = 1
	await _wait_screen(main, &"result")
	assert_eq(main.screen, &"result", "the fight reached its result panel")
	var back: Button = main.result_panel.back
	var fought := main.battle
	back.pressed.emit()
	assert_true(main.result_panel == null, "the first press let the panel reference go")
	var first_garage := main.garage.get_instance_id()
	back.pressed.emit()
	assert_eq(main.screen, &"garage", "the presses left the loop on the garage")
	assert_true(main.garage.get_instance_id() == first_garage,
		"the second press did not rebuild the garage the first one made")
	var garages := 0
	for child in main.get_children():
		if child is ChGarage:
			garages += 1
	assert_eq(garages, 1, "and exactly one garage is a child of main")
	assert_true(main.battle == null and not is_instance_valid(fought),
		"while the fight was released once")
	# queue_free is deferred, so the press leaves the panel in the tree for this frame; the next one
	# proves it really left rather than being dropped from the reference alone.
	await Engine.get_main_loop().process_frame
	assert_eq(main.find_children("*", "ChResultPanel", true, false).size(), 0,
		"and the panel itself left the tree, not just the reference to it")
	main.free()
	_complete()


# --- Task 7: the built screen ---------------------------------------------------------------------
# The rebuild is a scene, so these three tests instance garage.tscn: the strip's cards and the
# tooltip only exist once the scene does. Everything above stays a bare ChGarage because the logic
# methods must work with no nodes at all (ChMain calls setup before add_child).

func _garage_scene(inventory: ChInventory, layout: ChChariotLayout,
	catalog: ChCatalog) -> ChGarage:
	# setup() before add_child, the order ChMain uses, so _enter_tree builds the strip from the
	# inventory it was handed.
	var scene: PackedScene = ResourceLoader.load(GARAGE_SCENE)
	assert_true(scene != null, "garage.tscn loads")
	var garage: ChGarage = scene.instantiate()
	garage.setup(inventory, layout, catalog)
	Engine.get_main_loop().get_root().add_child(garage)
	_track(garage)
	return garage


func _card_of(garage: ChGarage, id: StringName) -> ChPartCard:
	var found: ChPartCard = null
	for node in garage.find_children("*", "ChPartCard", true, false):
		if node.part_id == id:
			found = node
	return found


func _press(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	# One real click through the viewport's own input path. in_local_coords is on purpose: the runner's
	# window is 64x64 in headless while the canvas is 1280x720, so a non-local event would be scaled by
	# 1/20 on its way in (measured); a local one arrives in the canvas pixels the screen is laid out in.
	var root: Viewport = Engine.get_main_loop().get_root()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)


func _move(at: Vector2) -> void:
	# A motion, the way the pit reads the pointer: the hover, the info panel and the marker nearest the
	# pointer all come from these, so a test that only clicks would never drive them.
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Engine.get_main_loop().get_root().push_input(motion, true)


func test_strip_has_every_part() -> void:
	# One wheel carried, so every other card reads 0 and the disabled pin has a card to check.
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	var cards: Array = garage.find_children("*", "ChPartCard", true, false)
	assert_eq(cards.size(), garage.STRIP_ORDER.size(), "one card per part the strip lists")
	var order: Array = []
	for card in cards:
		order.append(card.part_id)
	assert_eq(order, garage.STRIP_ORDER, "in STRIP_ORDER's order")
	var mace := _card_of(garage, &"ice_cream_mace")
	assert_true(mace != null, "the mace has a card")
	assert_eq(mace.count, 0, "carrying none")
	assert_true(mace.disabled, "so it cannot be picked")
	# A disabled card is greyed out as well as unpickable, which is the spec's "stays in the strip,
	# greyed out and not clickable": the alpha is the whole of the grey-out.
	assert_near(mace.modulate.a, 0.45, 0.001, "a card carrying none is greyed out")
	var wheel := _card_of(garage, &"wheel")
	assert_eq(wheel.count, 1, "the carried wheel reads one")
	assert_true(not wheel.disabled, "and its card is live")
	assert_near(wheel.modulate.a, 1.0, 0.001, "and drawn at full strength")
	assert_eq(garage.card_counts().size(), garage.STRIP_ORDER.size(),
		"card_counts answers for every id the strip shows")
	# A drop updates the strip without a rebuild, which is the only thing that keeps it honest.
	assert_true(garage.drop_part(&"wheel", [0]), "the wheel mounts")
	assert_eq(wheel.count, 0, "and its card reads none carried")
	assert_true(wheel.disabled, "with nothing to pick")
	assert_near(wheel.modulate.a, 0.45, 0.001, "and greyed out once the last copy left the kit")
	_complete()


func test_no_hint_labels() -> void:
	# The brief's rule: no screen says how to play. The garage's only text is the top bar's and the
	# part tooltip's, and the tooltip is hidden until something is hovered.
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), _layout(&"cutter"), _catalog())
	var hints: Array = []
	for node in garage.find_children("*", "Label", true, false):
		var text: String = node.text
		if text.begins_with("Click") or text.begins_with("Holding"):
			hints.append(text)
	assert_eq(hints, [], "no label tells the player what to click")
	assert_eq(garage.get_node("TopBar/BodyName").text, "Cutter · Wedge", "the bar names the hull and its type")
	assert_eq(garage.get_node("TopBar/Stats").text, "HP 450 · Energy 10", "and its fight stats")
	assert_true(not garage.tooltip.visible, "the tooltip is away until something is hovered")
	_complete()


# Task 7 Step 7's evidence. A harness cannot put a human's mouse on a windowed game, so this drives the
# chain the way the window does: real InputEventMouseButton presses through the viewport, the pit's own
# gui_input converting them, the cards' own pressed signal picking a part up. Every step asserts what a
# player would see, and the only thing called by hand is the forced ending of the fight, because a
# Cutter carrying one wheel has nothing to shoot with (tools/screenshot.gd forces its win the same way).
func test_mouse_chain_plays_a_round_trip() -> void:
	var main: ChMain = _main_scene()
	# Two frames: a Container sorts its children at the end of a frame, so the cards are only where a
	# player sees them after that.
	for _frame in 2:
		await Engine.get_main_loop().process_frame
	var garage: ChGarage = main.garage
	var pit: Control = garage.get_node("Pit")
	assert_eq(pit.get_global_rect(), Rect2(0, 60, 1280, 500), "the pit fills the middle of 1280x720")
	# 1. pick a wheel off the strip, where its card is.
	var card := _card_of(garage, &"wheel")
	assert_true(card != null, "the strip has a wheel card")
	_press(card.get_global_rect().get_center())
	assert_eq(garage.held_id, &"wheel", "a click on the card took a wheel in hand")
	# 2. place it: a click on the pit at the marker screen_of names.
	_press(garage.get_global_position() + garage.screen_of([0]))
	assert_true(main.layout.get_node([0]) != null, "the pit click mounted it in body slot 0")
	assert_eq(main.layout.get_node([0]).part_id, &"wheel", "as a wheel")
	assert_eq(garage.held_id, &"", "with nothing left in hand")
	assert_eq(garage.card_counts()[&"wheel"], 3, "and one of the four wheels out of the kit")
	# The hover: a motion over empty pit space leaves the panel away, a motion over the mounted wheel
	# shows the part tooltip for its def.
	var panel: ChPartTooltip = garage.tooltip
	_move(Vector2(100, 500))
	assert_true(not panel.visible, "moving off the hull puts the tooltip away")
	_move(garage.get_global_position() + garage.screen_of([0]))
	assert_true(panel.visible, "hovering the mounted wheel filled it")
	assert_eq(garage.tooltip.def.id, &"wheel", "naming the part")
	# 3. flip it: a right click on the mounted part.
	_press(garage.get_global_position() + garage.screen_of([0]), MOUSE_BUTTON_RIGHT)
	assert_true(main.layout.get_node([0]).flipped, "a right click turned the wheel round")
	# A pick and a click on the root's own empty space - the band above the top bar - puts a part back,
	# which is the one way out of a hold that is not a second click on its card.
	_press(card.get_global_rect().get_center())
	assert_eq(garage.held_id, &"wheel", "the card held a wheel again")
	_press(Vector2(640, 3))
	assert_eq(garage.held_id, &"", "a click on the empty root put it back")
	assert_eq(main.layout.slots.size(), 1, "and mounted nothing extra")
	# 4. swap the body: the top bar's next-body button.
	_press(garage.get_node("TopBar/NextBody").get_global_rect().get_center())
	assert_eq(main.layout.body_id, &"dozer", "the next-body button walked the cycle on")
	assert_eq(garage.get_node("TopBar/BodyName").text, "Dozer · Tower", "and the bar named the new hull and its type")
	assert_eq(main.layout.slots.size(), 1, "the wheel came across with the hull")
	# 5. ask for a fight, and watch it end.
	_press(garage.get_node("TopBar/FightButton").get_global_rect().get_center())
	assert_eq(main.screen, &"fight", "the fight button started a fight")
	var frames := 0
	while main.battle == null and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	if main.battle == null:
		assert_true(false, "the fight reached the tree")
		main.free()
		_complete()
		return
	main.battle.enemy.hp = 0
	await _wait_screen(main, &"result")
	assert_eq(main.screen, &"result", "the win reached the result panel")
	# 6. go back: the panel's own button, clicked where it is drawn.
	_press(main.result_panel.back.get_global_rect().get_center())
	assert_eq(main.screen, &"garage", "the back button put the garage up again")
	for _frame in 2:
		await Engine.get_main_loop().process_frame
	# The end state a player sees: the same build facing the way it was left, and the strip still
	# showing the three wheels that are not bolted on.
	assert_eq(main.layout.slots.size(), 1, "the build came back as it was left")
	assert_true(main.layout.get_node([0]).flipped, "the flip survived the fight")
	assert_eq(main.garage.card_counts()[&"wheel"], 3, "the fresh garage shows three wheels to place")
	assert_eq(_card_of(main.garage, &"wheel").count, 3, "and the strip's own card agrees")
	main.free()
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
	juice.advance(0.03)
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


func test_cycle_body_rebuilds_hull() -> void:
	var catalog := _catalog()
	var layout := _layout(&"cutter")
	var garage: ChGarage = _garage_scene(_inventory([&"wheel"]), layout, catalog)
	var hull: ChPitPiece = garage.hull_piece()
	assert_true(hull != null, "the pit has a hull piece")
	if hull == null:
		_complete()
		return
	assert_eq(hull.body_def.size, catalog.body(&"cutter").size, "drawing the Cutter's hull")
	assert_true(garage.drop_part(&"wheel", [0]), "a wheel mounts in Cutter slot 0 at (-10,4.5)")
	var before: Vector2 = garage.piece_at(_typed_path([0])).position
	garage.cycle_body(1)
	assert_eq(layout.body_id, &"dozer", "the cycle walked to the Dozer")
	assert_true(garage.hull_piece() == hull, "the hull piece is reused, not rebuilt")
	# Cutter 34x9 cells, Dozer 22x30: the piece has to show the new body, not the one it started on.
	assert_eq(garage.hull_piece().body_def.size, catalog.body(&"dozer").size,
		"and it shows the Dozer's taller hull")
	# swap_body reseats the wheel on Dozer slot 0 at (-11,15), so its piece keeps its path and its part
	# and still has to move: the position comes from the layout, never from where the piece was.
	var piece: ChPitPiece = garage.piece_at(_typed_path([0]))
	assert_true(piece != null, "the wheel kept a piece on the new hull")
	if piece == null:
		_complete()
		return
	assert_eq(piece.position,
		garage._box_at(garage.screen_of(_typed_path([0])), catalog.part(&"wheel")).get_center(),
		"and it sits on the Dozer's slot 0")
	assert_true(piece.position != before, "which is not where the Cutter's slot 0 was")
	_complete()


func test_pit_draw_order() -> void:
	# The order the one `_draw` painted in, now as siblings: hull, free-slot markers, parts, hover.
	# After the pit view come the strip, the held layer and the tooltip, which stay on top.
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
	var hover := view.get_node("Hover").get_index()
	assert_true(hull < markers, "the hull draws under the free-slot markers")
	assert_true(markers < parts, "the markers draw under the mounted parts")
	assert_true(parts < hover, "and the hover box draws over everything")
	_complete()


func _ready_garage(ids: Array) -> ChGarage:
	var garage := _garage_scene(_inventory(ids), _layout(&"cutter"), _catalog())
	for i in 2:
		await Engine.get_main_loop().process_frame
	return garage

func test_tooltip_follows_card_hover() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"flamethrower"])
	var card := _card_of(garage, &"flamethrower")
	card.mouse_entered.emit()
	assert_true(garage.tooltip.visible)
	assert_eq(garage.tooltip.def.id, &"flamethrower")
	card.mouse_exited.emit()
	await Engine.get_main_loop().process_frame  # the exit's hide is judged a frame later
	assert_true(not garage.tooltip.visible)
	_complete()

func test_tooltip_card_to_card() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"flamethrower"])
	var a := _card_of(garage, &"wheel")
	var b := _card_of(garage, &"flamethrower")
	a.mouse_entered.emit()
	b.mouse_entered.emit()
	a.mouse_exited.emit()
	assert_true(garage.tooltip.visible, "a late exit from A does not hide B's tooltip")
	assert_eq(garage.tooltip.def.id, &"flamethrower")
	_complete()

func test_tooltip_hidden_while_held() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel", &"wheel"])
	var card := _card_of(garage, &"wheel")
	card.mouse_entered.emit()
	assert_true(garage.pick_part(&"wheel"))
	assert_true(not garage.tooltip.visible, "picking up hides it")
	_move(garage.get_global_position() + garage.screen_of([0]))
	assert_true(not garage.tooltip.visible, "and it stays hidden while held")
	garage.cancel_hold()
	assert_true(garage.tooltip.visible, "putting it back lets hover show it again")
	assert_true(garage.pick_part(&"wheel"))
	assert_true(garage.drop_part(&"wheel", [0]))
	garage.cancel_hold()
	assert_true(garage.tooltip.visible, "after a drop, hover shows it again")
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
	var card := _card_of(garage, &"wheel")
	card.mouse_entered.emit()
	card.mouse_exited.emit()
	await Engine.get_main_loop().process_frame  # the exit's hide is judged a frame later
	assert_true(not garage.tooltip.visible, "no stale hull tooltip comes back")
	_complete()

func test_tooltip_hidden_by_body_swap() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.drop_part(&"wheel", [0]))
	_move(garage.get_global_position() + garage.screen_of([0]))
	garage.cycle_body(1)
	assert_true(not garage.tooltip.visible)
	_complete()

func test_no_info_panel_left() -> void:
	var garage: ChGarage = await _ready_garage([&"wheel"])
	assert_true(garage.get_node_or_null("Pit/InfoPanel") == null)
	assert_true(not "hook_text" in ChPartDef.new(), "hook_text is gone")
	_complete()

func test_tooltip_card_to_card_exit_first_keeps_springs() -> void:
	# Godot's own order: A's exit lands before B's entry. The hop must not restart the pop from small.
	var garage: ChGarage = await _ready_garage([&"wheel", &"flamethrower"])
	var a := _card_of(garage, &"wheel")
	var b := _card_of(garage, &"flamethrower")
	a.mouse_entered.emit()
	var juice := ChJuice.of(garage.tooltip.boxes()[0])
	juice.scale_spring.value = 1.0
	juice.scale_spring.velocity = 0.0
	a.mouse_exited.emit()
	b.mouse_entered.emit()
	await Engine.get_main_loop().process_frame
	assert_true(garage.tooltip.visible, "the hop keeps the tooltip up")
	assert_eq(garage.tooltip.def.id, &"flamethrower")
	assert_true(juice.scale_spring.value > ChPartTooltip.POP_FROM + 0.1, "no restart from small")
	_complete()
