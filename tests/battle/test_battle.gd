extends ChTest

# Task 15: the battle scene — ChEnemyAI's drive decision, ChBattle's result rule, and one real
# headless fight that ends.
# Seam: the world, the arena fill, the two builds, the fight's tick loop and the win/lose emit
# live once in game/battle/ch_battle.gd. The tests below start a fight and watch frames only, so
# the fight loop is never re-implemented here.
# ChBattle.start is a coroutine that awaits one frame per tick, so a fight test awaits it.
# The catalog the fight tests hand over is ChCatalog.load_default's content with the Dozer's HP
# overridden to 30 (the brief's "the enemy with HP overridden to 30"), so one Rocket hit ends it.
# shortcut: the enemy HP override travels as a hand-built catalog because a def on disk is shared
# by every test in the run; mutating it would make a later test's Dozer fragile.

const FIGHT_SECONDS := 60.0  # the brief's ceiling: a headless fight has to finish inside this
const TICK := 1.0 / 60.0
const ENEMY_HP := 30  # the Dozer's HP overridden


func _typed_path(path) -> Array[int]:
	var steps: Array[int] = []
	for index in path:
		steps.append(index)
	return steps


func _player_layout() -> ChChariotLayout:
	# The brief's "player Cutter + Rocket": two wheels in the Cutter's low slots (y = 3) and the
	# Rocket in slot 3 (6, -3), unflipped so it fires +x, which is the way the player faces.
	var layout := ChChariotLayout.new()
	layout.body_id = &"cutter"
	for mount in [[[0], &"wheel"], [[1], &"wheel"], [[3], &"cutter_rocket"]]:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [_typed_path(mount[0])])
	return layout


func _enemy_layout() -> ChChariotLayout:
	# The fixed enemy of spec 5.9, as data: game/data/enemies/dozer_cook.tres. ChBattle mirrors it
	# (mirrored() plus the builder's mirror_x) so its parts face the player.
	var layout: ChChariotLayout = ResourceLoader.load("res://game/data/enemies/dozer_cook.tres")
	assert_true(layout != null, "the dozer_cook layout loads")
	return layout


func _dozer(enemy_hp: int) -> ChBodyDef:
	# The Dozer with the brief's HP override. ChBodyDef.duplicate() drops a script resource's own
	# properties on this build (verified: the copy answers an empty id and 0 HP), so the fields the
	# builder reads are written across one by one rather than guessed at.
	var loaded: ChBodyDef = ChCatalog.load_default().body(&"dozer")
	assert_true(loaded != null, "the dozer body def loads")
	var copy := ChBodyDef.new()
	copy.id = loaded.id
	copy.display_name = loaded.display_name
	copy.hp = enemy_hp
	copy.energy_cap = loaded.energy_cap
	copy.energy_regen = loaded.energy_regen
	copy.size = loaded.size
	copy.color = loaded.color
	copy.slots = loaded.slots
	copy.material = loaded.material
	return copy


func _catalog(enemy_hp: int) -> ChCatalog:
	# The slice's defs with the Dozer's HP overridden to 30, so one Rocket hit ends the enemy.
	# shortcut: the override travels as a catalog because a def on disk is shared by every test in
	# the run; mutating it would make a later test's Dozer fragile.
	var loaded := ChCatalog.load_default()
	var parts: Array[ChPartDef] = []
	for def in loaded.parts.values():
		parts.append(def)
	var bodies: Array[ChBodyDef] = []
	for def in loaded.bodies.values():
		bodies.append(_dozer(enemy_hp) if def.id == &"dozer" else def)
	return ChCatalog.from_defs(parts, bodies)


# The seam every fight test uses: connect to finished, start the fight, then let frames run.
# Returns whatever `finished` announced, in order, so "emitted once" is a size check.
func _fight(battle: Node2D, player_layout: ChChariotLayout, enemy_layout: ChChariotLayout,
	catalog: ChCatalog, seed: int) -> Array[StringName]:
	var results: Array[StringName] = []
	var sink := results
	battle.finished.connect(func(result: StringName): sink.append(result))
	await battle.start(player_layout, enemy_layout, catalog, seed)
	return results


func test_ai_approaches_then_holds() -> void:
	var ai := ChEnemyAI.new()
	assert_eq(ai.decide(420.0, 60.0, 6.0), -1.0, "target to the left: drive left")
	assert_eq(ai.decide(60.0, 420.0, 6.0), 1.0, "target to the right: drive right")
	assert_eq(ai.decide(420.0, 414.0, 6.0), 0.0, "inside reach: hold")
	assert_eq(ai.decide(420.0, 426.0, 6.0), 0.0, "exactly at reach: hold, the rule is |dx| <= range")
	assert_eq(ai.decide(420.0, 426.5, 6.0), 1.0, "one hair past reach: close in")
	assert_eq(ai.decide(100.0, 100.0, 0.0), 0.0, "no range to close: hold still")
	# The reach table ChBattle hands that parameter: a weapon's proximity_range is its reach in
	# cells (ChBehaviour._reach_box), and the Harpoon owns its behaviour's own range, counted only
	# while it can fire.
	var catalog := ChCatalog.load_default()
	var mace := ChPartRuntime.new()
	mace.def = catalog.part(&"ice_cream_mace")
	mace.cooldown_left = mace.def.cooldown
	var harpoon := ChPartRuntime.new()
	harpoon.def = catalog.part(&"corsair_harpoon")
	harpoon.cooldown_left = harpoon.def.cooldown
	var parts: Array[ChPartRuntime] = [mace, harpoon]
	var rig := ChChariotRuntime.new()
	rig.parts = parts
	assert_near(ai.reach(rig), 6.0, 0.001, "the shortest reach the Dozer can bring to bear is the Mace's 6")
	# The Harpoon's 120 cells count only while it can fire, so a Harpoon whose cooldown is still
	# running owns no range at all and the driver has nothing to close.
	var ranged := ChChariotRuntime.new()
	var only: Array[ChPartRuntime] = [harpoon]
	ranged.parts = only
	assert_true(is_inf(ai.reach(ranged)), "an unready Harpoon leaves the chariot with no range")
	assert_eq(ai.decide(60.0, 420.0, ai.reach(ranged)), 0.0, "so it stays put instead of charging")
	harpoon.cooldown_left = 0.0
	assert_near(ai.reach(ranged), 120.0, 0.001, "a ready Harpoon counts at its own 120 cells")
	assert_near(ai.reach(rig), 6.0, 0.001, "and the Mace is still the shortest reach")
	_complete()


# Review item 5: `preferred_range` is a weapon's reach in cells, measured from the part - and a part
# mounts on the hull's edge. A Dozer is 30 cells wide and a Cutter 30, so a driver that holds at the
# Mace's 6 parks the two hulls inside each other, where Box2D grinds them (every body is CAT_BODY
# against CAT_BODY, physics.cpp:24-33 binds no per-body filter) instead of fighting. The hulls' own
# half-widths therefore ride along with the reach.
func test_ai_holds_off_the_hulls() -> void:
	var ai := ChEnemyAI.new()
	var catalog := ChCatalog.load_default()
	var dozer := float(catalog.body(&"dozer").size.x) * 0.5
	var cutter := float(catalog.body(&"cutter").size.x) * 0.5
	assert_near(dozer + cutter, 30.0, 0.001, "the two hulls need 30 cells between their centres")
	# 30 apart centre to centre is the two hulls touching: the old rule read it as "6 cells to go" and
	# drove the enemy into the player, which is the stalemate the fight tests kept landing in.
	assert_eq(ai.decide(420.0, 390.0, 6.0, dozer, cutter), 0.0, "30 apart is inside the hulls: hold")
	assert_eq(ai.decide(420.0, 384.0, 6.0, dozer, cutter), 0.0,
		"reach + both half-widths is the hold, and |dx| <= hold holds there")
	assert_eq(ai.decide(420.0, 383.0, 6.0, dozer, cutter), -1.0, "one cell further out: close in")
	assert_eq(ai.decide(384.0, 420.0, 6.0, dozer, cutter), 0.0, "the other way round holds too")
	assert_eq(ai.decide(383.0, 420.0, 6.0, dozer, cutter), 1.0, "and drives right to reach it")
	# The brief's rule is still the rule: the hold is the shortest reach the chariot can bring to bear,
	# so a weapon that reaches further than the hulls keeps the fight at its own range, and a driver
	# with no weapon that reaches anything still stays put.
	assert_eq(ai.decide(100.0, 122.0, 14.0, 4.0, 4.0), 0.0, "a Chainsaw's 14 still rules at 22 apart")
	assert_eq(ai.decide(100.0, 123.0, 14.0, 4.0, 4.0), 1.0, "and one cell past it closes in")
	assert_eq(ai.decide(100.0, 420.0, INF, dozer, cutter), 0.0,
		"nothing to reach (INF + widths is INF): stay put")
	# Without the widths the brief's three-argument call is unchanged, which is what every earlier
	# caller and test that never passes them relies on.
	assert_eq(ai.decide(420.0, 390.0, 6.0), -1.0, "no widths given: the brief's rule, unchanged")
	_complete()


# Review Focus 4: both chariots reaching 0 HP on the same tick (a Ring of Fire pays its own
# chassis as it expands, so one tick can end both) is a loss for the player, not a crash.
func test_simultaneous_death_is_loss() -> void:
	assert_eq(ChBattle.result_for(true, true), &"loss", "both dead: the player loses")
	assert_eq(ChBattle.result_for(true, false), &"loss", "a dead player alone loses")
	assert_eq(ChBattle.result_for(false, true), &"win", "a dead enemy alone wins")
	assert_eq(ChBattle.result_for(false, false), &"", "neither dead is not a result")
	_complete()


func test_battle_finishes() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "the fight announced exactly one result")
	assert_eq(results, [&"win"], "the fight ended with a win inside the 60 s ceiling")
	# The markers have to sit on the parts at whatever zoom/pan the camera ends at, so they live under
	# the world's Node2D (the Camera2D's transform carries them) rather than the HUD CanvasLayer.
	assert_true(battle.marks.get_parent() == battle.world, "markers are parented to the world layer")
	# Same reason on the other axis: 2D draw order sorts by z_index before tree order, so a marker at
	# the bodies' own z sits under whichever hull or pile drew later and cannot be seen. Nothing under
	# game/ or the builders sets z_index, so the bodies answer 0 and the marker layer must beat them.
	assert_true(battle.marks.z_index > battle.player.chassis.z_index, "markers draw above the hulls")
	battle.free()
	_complete()


func _battle_scene() -> Node2D:
	# The scene itself, so the fight test drives the shipped scene rather than a copy of its loop.
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	return battle


# The &"aborted" contract, cheaply: a chariot whose body id the catalog has no def for cannot build,
# so start() returns early — and an early return still has to announce a result, or a caller awaiting
# `finished` hangs. This pays the world load and the arena fill only: the tick loop never starts, so
# there is no 60 s fight here. The ERROR lines the run prints are the contract's own push_error calls.
func test_aborted_battle_still_ends() -> void:
	var battle := _battle_scene()
	var broken := ChChariotLayout.new()
	broken.body_id = &"no_such_body"
	# This fight is built to fail on purpose, and the two diagnostics it makes are the abort path's
	# own: ch_chariot_builder.gd:18 ("body id no_such_body has no def") and ch_battle.gd:143 ("a
	# chariot did not build"). They are what the shipped game prints when a fight cannot start, so
	# the code keeps them; only their noise here is muted, over the frames this one fight runs, so a
	# real error anywhere else in the run still reaches the log.
	Engine.set_print_error_messages(false)
	var results := await _fight(battle, broken, _enemy_layout(), ChCatalog.load_default(), 12345)
	Engine.set_print_error_messages(true)
	assert_eq(results.size(), 1, "the aborted battle announced exactly one result")
	assert_eq(results, [&"aborted"], "a battle that cannot start ends with aborted")
	battle.free()
	_complete()


# The end of a fight does not stop its ticks: ChBattle runs the fight to its tick budget whatever
# the result, so a second `finished` never arrives.
func test_finished_emitted_once() -> void:
	var battle := _battle_scene()
	var results := await _fight(battle, _player_layout(), _enemy_layout(), _catalog(ENEMY_HP), 12345)
	assert_eq(results.size(), 1, "one finished across a whole budget of ticks")
	assert_eq(results, [&"win"], "and it is the win, not a second result")
	# The ticks ran past the end: the fight's clock reached the budget it was given, so this is
	# the second emit being refused rather than a loop that stopped at the result.
	assert_true(battle.ctx.time >= FIGHT_SECONDS - TICK, "ticks ran on past the result to the budget")
	battle.free()
	_complete()


# --- Review item 3: the spec's chains, read off a real fight --------------------------------------
# Everything above this line drives one seam in isolation. These two drive the shipped scene with a
# build made through the garage's own drop path, hold the fight's own drive keys the way a player
# holds D, and read what the fight's own event bus said. ChBattle has no stop and always spends its
# 3600-frame budget (Task 15's contract), so each of these pays one whole fight: measured, ~11 s each
# at the suite's headless frame rate.
const CHAIN_FRAMES := 4000  # the 3600-frame budget, plus the frames the arena takes to stream
const DRIVE_ON := 0.9  # seconds of held direction
const DRIVE_OFF := 0.3  # seconds released, so the queued parts are paid (drive is paid first)


func _garage_built(body_id: StringName, mounts: Array) -> ChChariotLayout:
	# The build the garage's pointer code makes: ChGarage.drop_part for each part, from an inventory
	# that carries it, onto the body the player picked. request_fight hands the fight a copy of exactly
	# this, so passing the layout on is what the Fight button does.
	var inventory := ChInventory.new()
	for mount in mounts:
		assert_true(inventory.add(mount[1]), "the kit carries %s" % [mount[1]])
	var layout := ChChariotLayout.new()
	layout.body_id = body_id
	var garage := ChGarage.new()
	garage.setup(inventory, layout, ChCatalog.load_default())
	for mount in mounts:
		assert_true(garage.drop_part(mount[1], mount[0]),
			"the garage drops %s into slot %s" % [mount[1], mount[0]])
	garage.free()
	return layout


# start() is a coroutine: it streams the arena on the tree's frames before its tick loop begins, so it
# is deliberately not awaited here. The caller waits for ctx (which owns the fight's bus), subscribes,
# then spends the frames the loop needs.
func _start_fight(battle: Node2D, player_layout: ChChariotLayout,
	enemy_layout: ChChariotLayout) -> void:
	battle.start(player_layout, enemy_layout, ChCatalog.load_default(), 12345)
	var frames := 0
	while battle.ctx == null and frames < 600:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(battle.ctx != null, "the fight reached its context")


# The drive keys: ChBattle._player_drive reads Input, so action_press is what holding the key at the
# keyboard is. Bursting it is what a player learns, because ChEnergy pays the drive before the queued
# parts and a direction held for ever starves the weapons. Returns the narrowest the two hulls ever
# got, centre to centre, which is the number the reach pins below read.
func _drive_fight_out(battle: Node2D) -> float:
	var frames := 0
	var min_gap := INF
	var held := false
	var next_flip := DRIVE_ON
	while battle.ticking and frames < CHAIN_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
		var t: float = battle.ctx.time
		if t >= next_flip:
			held = not held
			next_flip = t + (DRIVE_OFF if held else DRIVE_ON)
			if held:
				Input.action_press(&"ui_right")
			else:
				Input.action_release(&"ui_right")
		min_gap = minf(min_gap, absf(battle.enemy.chassis.global_position.x
			- battle.player.chassis.global_position.x))
	Input.action_release(&"ui_right")
	assert_true(frames < CHAIN_FRAMES, "the fight spent its own tick loop rather than the frame cap")
	return min_gap


# Every event the fight names, in the order it said them, with the two fields the chains read. The
# sinks stay arrays of Dictionaries because a lambda closes over an array by reference.
func _hear_all(battle: Node2D, heard: Array) -> void:
	var key := RefCounted.new()
	for type in [ChEvent.PART_FIRED, ChEvent.HIT, ChEvent.CAUGHT_FIRE, ChEvent.ENERGY_GAINED,
		ChEvent.FROZEN, ChEvent.THAWED, ChEvent.CELLS_CUT, ChEvent.PART_BROKEN]:
		battle.ctx.bus.subscribe(key, type, func(event: ChEvent): heard.append({
			"type": event.type,
			"side": event.side,
			"source": &"" if event.source == null or event.source.def == null
				else event.source.def.id,
			"target_part": null if event.data.get("target_part") == null
				else (event.data["target_part"] as ChPartRuntime).def.id,
			"sparks": event.data.get("sparks", 0),
			"hp_damage": event.data.get("hp_damage", 0),
		}))


# Chain 1 (spec 5.5): the Chainsaw cuts, something ignites, the Ember Battery pays energy. Over a real
# fight the cut lands on the Chainsaw's own 0.5 s cooldown, its sparks set something alight, and the
# battery pays for that catch. The chainsaw sits on the Corsair's front slot, so its 14-cell reach
# clears the hull's own edge and the sparks land outside it; the asserts below are the chain in order -
# a cut with sparks, a catch after it, the battery paying after that catch.
# The catch measured here is on the ENEMY's side, which is what the spec's "the target keeps burning"
# asks for. The fires the enemy's own Hearth rings into place also catch its parts, so the order is the
# evidence, not the count: an enemy catch lands between a cut and the battery's next payment.
func test_chain1_cut_ignites_and_pays_energy_in_a_real_fight() -> void:
	var battle := _battle_scene()
	var heard: Array = []
	var layout := _garage_built(&"corsair", [[[0], &"wheel"], [[1], &"wheel"],
		[[6], &"cutter_chainsaw"], [[3], &"ember_battery"]])
	_start_fight(battle, layout, _enemy_layout())
	_hear_all(battle, heard)
	var min_gap := await _drive_fight_out(battle)
	var cut := -1
	var caught := -1
	var paid := -1
	for at in heard.size():
		var entry: Dictionary = heard[at]
		if cut < 0 and entry["type"] == ChEvent.CELLS_CUT \
				and entry["source"] == &"cutter_chainsaw" and int(entry["sparks"]) >= 1:
			cut = at
		elif cut >= 0 and caught < 0 and entry["type"] == ChEvent.CAUGHT_FIRE:
			caught = at
		elif caught >= 0 and paid < 0 and entry["type"] == ChEvent.ENERGY_GAINED \
				and entry["source"] == &"ember_battery":
			paid = at
	assert_true(cut >= 0, "the Chainsaw cut cells and threw sparks (heard %d events)" % heard.size())
	assert_true(caught > cut, "something caught fire after that cut")
	assert_true(paid > caught, "and the Ember Battery paid energy for the catch")
	# Where the chain landed, as measured: the enemy side. The two hulls are not asserted to touch
	# here - this build's four parts make it the lightest one, and how close it gets varies with the
	# sand it ploughs (measured between 130 and 183 cells). The chain does not need contact: the sparks
	# fly, the sand burns, and the battery pays.
	assert_eq(int(heard[caught]["side"]) if caught >= 0 else -1, 1,
		"the catch this chain made was on the enemy's side")
	assert_true(min_gap < 260.0,
		"and the two chariots were in the same half of the arena (narrowest %.0f)" % min_gap)
	battle.free()
	_complete()


# Chain 2 (spec 5.5): the Freeze Charge's freeze on a Mace hit, then the Shatter's x3 on the frozen
# part. This is the harness the final review asked for - the plan's own build (a Mace and a Harpoon on
# the Corsair's front slots) fought for real through ChBattle, built by the garage's own drop path. It
# pins the two things that are stable run to run:
#   - the player's chariot drives out of its corner. That is what the wheel mounts buy (see
#     ChBodyDef): a loaded chariot used to sit with its motors on and the hulls could never meet,
#     which is the state this test used to pin as "min_gap > 100".
#   - the Mace swings on its own cooldown, so the fight pays it through ChBattleContext's loop.
# What it does NOT pin: how close the two hulls get. With the wheel mounts fixed they met (38 cells,
# the two hulls touching) in three runs of this build and stayed 186 apart in a fourth, because
# whether the sand and the two pools let the player across varies run to run; the fight resolves
# either way (ChBattle always spends its frame budget).
# Nothing freezes, and that is chain 2's remaining gap. A weapon's reach box is at the part's own
# height (one cell for these defs), and the Dozer's wheels hang 14 cells below a Corsair's top slots,
# so a Mace hits the Dozer's chassis almost every swing and a wheel only when the Dozer has rolled
# over - measured: one wheel hit in a whole fight, and its 0.5 of freeze decays at 0.25/s
# (ChPartRuntime) long before the next swing. tests/battle/test_behaviours_melee.gd pins the freeze
# build-up, the x3 and the thaw at the same height, where the chain's rules are reachable. Closing the
# last link needs a design call - a taller reach band, a chariot-wide freeze, or a weapon that reaches
# down - not a tuning pass, so it is named here rather than faked.
func test_chain2_melee_build_drives_out_of_its_corner() -> void:
	var battle := _battle_scene()
	var heard: Array = []
	var layout := _garage_built(&"corsair", [[[0], &"wheel"], [[1], &"wheel"],
		[[6], &"ice_cream_mace"], [[5], &"freeze_charge"], [[4], &"corsair_harpoon"]])
	_start_fight(battle, layout, _enemy_layout())
	_hear_all(battle, heard)
	var min_gap := await _drive_fight_out(battle)
	var swung := 0
	var frozen := 0
	for entry in heard:
		if entry["type"] == ChEvent.PART_FIRED and entry["source"] == &"ice_cream_mace":
			swung += 1
		elif entry["type"] == ChEvent.FROZEN:
			frozen += 1
	assert_true(swung > 0, "the fight paid the Mace, so it swung on its own cooldown")
	# Measured 180-220 cells of travel for this build; the loaded chariots that could not drive at all
	# managed 0-31 (a hull resting on the sand with its wheels buried).
	assert_true(absf(battle.player.chassis.global_position.x - 60.0) > 60.0,
		"the player's chariot drove out of its corner (ended at x %.0f, hulls %.0f apart)" % [
			battle.player.chassis.global_position.x, min_gap])
	assert_eq(frozen, 0, "nothing froze: the melee band misses the Dozer's wheels (see above)")
	battle.free()
	_complete()
