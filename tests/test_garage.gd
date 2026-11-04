extends ChTest

# Task 16: the garage's logic — the inventory handshakes (drop, lift), the flip click, the body
# cycle and the copy `fight_requested` hands the battle. ChGarage.setup is what a scene calls
# before any of these, so every test builds its own garage, inventory and layout: a garage owns
# the references it was handed, so a shared one would carry an earlier test's mounts.
# The UI is built on these same methods, so nothing below touches the mouse.
# ChMain end to end (review finding 3): the brief's headline deliverable is the round trip -
# garage -> one battle -> result -> garage - and nothing above ever ran it. The seam is the
# shipped scene rather than a copy of ChMain's loop, which is also where the scene's own nodes
# get pinned: ChMain makes its screen in code, so main.tscn must not instance a second garage
# (review finding 2) drawing "Fight" over the live one.
# Cheapness: ChBattle always runs its 3600 ticks (Task 15's contract), so a fight left to its own
# budget costs the suite ~25 s of headless frames. test_main_round_trip drops the enemy's HP so
# `finished` fires in seconds and stops at what it can see that early; the watchdog test pays the
# full budget, because a watchdog that counts the fight's own frames (finding 1) can only speak
# when that loop ends. Both pin that ChMain did NOT free the battle it left ticking there, and the
# watchdog test then watches that fight go idle and sees ChMain let it go back to the garage.
const MAIN_SCENE := "res://game/main.tscn"
const MAIN_WAIT_MS := 30000  # a loop that cannot get back is waited on for 30 s, then recorded
const IDLE_WAIT_MS := 90000  # a fight that never stops ticking is waited on for 90 s, then recorded


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
		# shortcut: one level deep, which is main.tscn's own shape: the label and the garage.
		if child is ChGarage:
			screens += 1
	assert_eq(screens, 1, "the tree holds exactly one garage, the one ChMain made")
	assert_true(main.garage != null, "and ChMain made it")
	return main


# The wait test_main_round_trip uses: frames until the loop names an outcome, capped in real
# time rather than frames because ChMain counts its window in delta, so a frame cap would be a
# guess at headless speed. A loop that cannot get back costs the suite this cap once and records a
# failure instead of hanging the run. Returns the last thing the result panel said.
# Finding 3: the watch stops the moment the panel names an outcome, rather than running on to the
# garage. The fight keeps ticking the whole time, so a hull could reach 0 HP inside the window and
# the real result would replace the watchdog's line on the way back - which is how the watchdog
# pin used to be able to flip. Nothing is expected to change on the way back now (ChMain keeps the
# fight it did not free, so the loop stays on `fight` until the fight goes idle), and
# test_main_watchdog_returns waits for its own panel line, so stopping early costs nothing.
# "Named an outcome" means a panel line that is neither blank nor the fight's "Fighting ..." text.
func _wait_garage(main: ChMain) -> String:
	var outcome := ""
	var started_ms := Time.get_ticks_msec()
	while (main.label.text == "" or main.label.text == ChMain.FIGHT_TEXT) \
			and Time.get_ticks_msec() - started_ms < MAIN_WAIT_MS:
		await Engine.get_main_loop().process_frame
		if main.label.text != "":
			outcome = main.label.text
	return outcome


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
	assert_true(garage.drop_part(&"strut", [1]), "the strut takes cutter slot 1 at (6,3)")
	assert_true(garage.drop_part(&"wheel", [1, 1]), "the wheel sits on the strut's extension 1 at (4,-6)")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(10, -3), "unflipped parent: 6+4 across")
	garage.click_part([1])
	# A flip turns the mount the other way, so the child's extension x negates: the anchor moves,
	# which is the only visible effect a flip has on a part that owns no range of its own.
	assert_true(layout.get_node([1]).flipped, "the flag toggled")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(2, -3), "flipped parent: 6-4 across")
	garage.click_part([1])
	assert_true(not layout.get_node([1]).flipped, "a second click toggles back")
	assert_eq(layout.anchor_of([1, 1], catalog), Vector2(10, -3), "and the child returns to its cell")
	# ChChariotLayout.toggle_flip answers silently for a path nothing holds; the garage does not
	# add its own check, so a stray click changes nothing rather than losing a part.
	garage.click_part([2])
	assert_true(layout.slots.has(1), "the mounted strut is untouched by a click on an empty slot")
	garage.free()
	_complete()


func test_cycle_body_keeps_parts_and_returns_leftovers() -> void:
	# Corsair slots sit at (-8,3),(10,3),(-18,-5),(-8,-5),(2,-5),... and the Cutter's four at
	# (-4,3),(6,3),(-4,-3),(6,-3), so swap_body's greedy nearest pairing moves every mount except
	# the strut at Corsair slot 2 (-18,-5), which is 14 cells from the closest Cutter slot.
	var inventory := _inventory([&"wheel", &"wheel", &"strut", &"wheel", &"ember_battery",
	    &"cutter_rocket"])
	var layout := _layout(&"corsair")
	var garage: ChGarage = _garage(inventory, layout, _catalog())
	assert_true(garage.drop_part(&"wheel", [0]), "Corsair slot 0 at (-8,3)")
	assert_true(garage.drop_part(&"wheel", [1]), "Corsair slot 1 at (10,3)")
	assert_true(garage.drop_part(&"strut", [2]), "Corsair slot 2 at (-18,-5)")
	assert_true(garage.drop_part(&"wheel", [2, 0]), "a wheel bolted under that strut")
	assert_true(garage.drop_part(&"ember_battery", [3]), "Corsair slot 3 at (-8,-5)")
	assert_true(garage.drop_part(&"cutter_rocket", [4]), "Corsair slot 4 at (2,-5)")
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
	# Cutter -> Dozer: both bodies have six slots, so the nearest pairing keeps each index
	# (a Dozer slot sits under the Cutter slot it answers for), so nothing is left over.
	assert_eq(layout.body_id, &"dozer", "and the cycle keeps going")
	assert_eq(layout.slots.size(), 4, "all four fit the Dozer")
	assert_eq(inventory.part_ids, [&"strut", &"wheel"], "and the same two carried parts")
	assert_eq(layout.get_node([4]).part_id, &"ember_battery", "the Ember Battery moved to slot 4")
	assert_eq(layout.get_node([3]).part_id, &"cutter_rocket", "and the Rocket stayed at 3")
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
	var outcome := await _wait_garage(main)
	assert_eq(results, [&"win"], "the loop saw the fight's result, a win for the low-HP enemy")
	assert_eq(outcome, "You win!", "and the result panel named it on the way back")
	# Finding 2: the fight is still running its own 3600 ticks at that moment, so ChMain must NOT
	# have freed it - freeing a battle whose coroutine is suspended mid-loop is what the shipped
	# handoff used to do - and the loop is not back on the garage yet precisely because of it.
	assert_true(is_instance_valid(main.battle), "the still-ticking fight is still in the tree")
	assert_true(main.battle.ticking, "because its own tick loop is still running")
	assert_true(main.fight_left > 0.0, "a real result cancelled the countdown: it never ran down")
	# The build and the kit come back untouched whatever the loop did in between: ChMain owns ONE
	# layout and ONE inventory, and the fight only ever got a copy.
	assert_true(main.layout.get_instance_id() == build_id, "the SAME layout instance, not a rebuilt one")
	assert_eq(main.layout.slots.size(), 3, "still holding exactly the three mounts it was given")
	var rocket := main.layout.get_node([3])
	assert_true(rocket != null and rocket.part_id == &"cutter_rocket", "the Rocket in the same slot")
	assert_eq(main.inventory.part_ids.size(), carried, "and the same parts carried")
	# shortcut: this test's own teardown frees the fight it leaves behind mid-loop, which the shipped
	# loop no longer does; the release ChMain makes instead is pinned by test_main_watchdog_returns.
	# Waiting that out here too would be a second full-budget fight for the same pin.
	main.free()
	_complete()


func test_main_watchdog_returns() -> void:
	# Review finding 1: ChBattle emits `finished` only from an HP reaching 0 (plus its three
	# `aborted` paths), so a fight both hulls survive announces nothing at all and the loop would
	# sit on "Fighting ..." for ever. This is that fight, run at the shipped budget: a real battle,
	# both hulls standing, waited out to the end of the fight's own 3600-frame loop. Fixing finding
	# 1 removed the cheap way in - a countdown armed short used to speak in frames, and that is now
	# impossible while a fight is legitimately ticking, which is exactly the defect.
	var main: ChMain = _main_scene()
	main.garage.request_fight()
	assert_true(main.battle != null, "the fight started")
	assert_eq(main.fight_left, ChMain.FIGHT_WATCHDOG, "the watchdog armed at the fight's own budget")
	# Finding 1: that budget is the fight's currency. ChBattle's loop is `for _tick in FIGHT_TICKS:
	# await get_tree().process_frame` - 3600 FRAMES, no delta - so a countdown that spends real
	# seconds cuts the fight off on any machine under 60 fps, killing a fight that HP reaching 0 was
	# about to end. The units are pinned by what one frame spends, then the shipped value is put
	# back so the wait below runs the countdown ChMain really arms.
	assert_eq(ChMain.FIGHT_WATCHDOG, ChBattle.FIGHT_TICKS, "one budget, counted the way the fight counts it")
	main.fight_left = 30.0
	var spent_by := main.fight_left
	await Engine.get_main_loop().process_frame
	assert_near(spent_by - main.fight_left, 1.0, 0.001, "one frame of the countdown per frame run")
	main.fight_left = float(ChMain.FIGHT_WATCHDOG)
	# Finding 3: the fight cannot kill anyone, so no HP can reach 0 inside it. The pin used to read
	# `results == []` and the watchdog's own panel line some frames after the expiry, during which
	# the still-ticking fight could win the race and name a real result instead.
	var frames := 0
	while (main.battle.player == null or main.battle.enemy == null) and frames < 60:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(main.battle.player != null and main.battle.enemy != null, "both hulls built")
	main.battle.player.hp = 1000000
	main.battle.enemy.hp = 1000000
	assert_true(main.battle.ticking, "and the fight is in its own tick loop")
	var results: Array[StringName] = []
	var sink := results
	main.battle.finished.connect(func(result: StringName): sink.append(result))
	# The fight's own end, un-armed. IDLE_WAIT_MS is the cap that turns a loop that never stops
	# into a recorded failure rather than a hung run.
	var started := Time.get_ticks_msec()
	while main.battle != null and main.battle.ticking \
			and Time.get_ticks_msec() - started < IDLE_WAIT_MS:
		await Engine.get_main_loop().process_frame
	assert_true(not main.battle.ticking, "the fight spent its own 3600-frame loop")
	# ChMain sees the loop end on its own next frame, so the panel is read once it has spoken rather
	# than on the frame the flag went false.
	while main.label.text == ChMain.FIGHT_TEXT and Time.get_ticks_msec() - started < MAIN_WAIT_MS:
		await Engine.get_main_loop().process_frame
	# Finding 1's consequence, read off the fight's own clock: a hand-back that came early would
	# show a short clock here.
	assert_near(main.battle.ctx.time, ChBattle.FIGHT_TICKS * ChBattle.TICK, ChBattle.TICK, \
		"the fight ran all 3600 of its own ticks before the hand-back")
	assert_eq(results, [], "the fight announced nothing")
	assert_eq(main.screen, &"result", "the watchdog opened the 2 s window")
	assert_eq(main.label.text, ChMain.WATCHDOG_TEXT, "naming the non-win it hands back")
	assert_true(is_instance_valid(main.battle), "the fight it could not free is still in the tree")
	assert_true(main.garage != null and not main.garage.is_visible_in_tree(), "under a hidden garage")
	# The window's two seconds, then the release and the garage: this is the loop's way back from a
	# fight nobody died in.
	started = Time.get_ticks_msec()
	while main.screen != &"garage" and Time.get_ticks_msec() - started < MAIN_WAIT_MS:
		await Engine.get_main_loop().process_frame
	assert_eq(main.screen, &"garage", "the garage came back once the fight was over")
	assert_true(is_instance_valid(main.garage), "as a live screen again")
	assert_true(not is_instance_valid(main.battle), "and ChMain let the finished fight go")
	main.free()
	_complete()
