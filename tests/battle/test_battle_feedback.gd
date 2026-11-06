extends ChTest

# Task 8: the fight's bus events, played as feedback. Every test here drives one real
# ChBattleFeedback over two real chariots (ChChariotBuilder's, so the visuals it beats on are the
# juiced "Visual" sprites the fight itself moves) and hands it hand-made ChEvents; none of them runs
# a fight, so the mapping is read without a 60 s tick loop.
# Seam: on_event is the whole mapping — ChBattle subscribes it to the seven event types and nothing
# else calls it. The last two tests pin what the mapping may NOT touch: fight state, and the removed
# fire pulse.
# CONTRACT: every test_* ends with _complete().

const PLAYER_AT := Vector2(100, 100)
const ENEMY_AT := Vector2(380, 100)
const ROCKET_PATH := [3]  # the player Cutter's Rocket, ChTest._player_layout


func _arena() -> Dictionary:
	# Two chariots on one real world, the context that ties them together, and the HUD the beats aim
	# their bar nudges at. The chariots stay on the builder's own path: every visual, its Juice and
	# the part runtimes are the fight's, so a juice assertion reads the node the game kicks.
	# shortcut: the world is not stepped here, so the bodies never settle on ground they do not have;
	# the feedback path never reads a body transform, which is what lets this fixture skip the fill.
	var world = await make_world()
	var catalog := ChCatalog.load_default()
	var parent := _parent()
	var player: ChChariotRuntime = ChChariotBuilder.build(world, parent, _player_layout(),
		catalog, 0, PLAYER_AT, false)
	var enemy: ChChariotRuntime = ChChariotBuilder.build(world, parent, _enemy_layout().mirrored(),
		catalog, 1, ENEMY_AT, true)
	assert_true(player != null and enemy != null, "both chariots built")
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	var rigs: Array[ChChariotRuntime] = [player, enemy]
	ctx.chariots = rigs
	var hud := ChBattleHud.new()
	_track(hud)
	return {"feedback": ChBattleFeedback.new(ctx, hud), "player": player, "enemy": enemy,
		"hud": hud, "ctx": ctx, "world": world, "parent": parent}


func _event(type: StringName, side: int, source: Object, data := {}) -> ChEvent:
	# The shape ChBattleContext emits: the type, the actor's side, the acting part and its payload.
	var event := ChEvent.new()
	event.type = type
	event.side = side
	event.source = source
	event.position = source.anchor_world() if source != null else Vector2.ZERO
	event.data = data
	return event


func _part(rig: ChChariotRuntime, path: Array[int]) -> ChPartRuntime:
	# The part the builder mounted at a layout path; runtime.parts keeps every part's own path.
	for part in rig.parts:
		if part.path == path:
			return part
	_record("no part mounted at %s" % [path], "")
	return null


func _clear_popups() -> void:
	# The manager owns one pop-up layer for the whole game, so a test that counts labels runs the
	# clock past LIFE first (the way tests/feedback/test_popups.gd does).
	Feedback.popups.advance(0.9)
	assert_eq(Feedback.popups.active().size(), 0, "the pop-up layer starts idle")


func test_fire_kicks_the_firing_part() -> void:
	var arena = await _arena()
	var player: ChChariotRuntime = arena["player"]
	var rocket := _part(player, _typed_path(ROCKET_PATH))
	var juice := ChJuice.of(rocket.visual)
	assert_eq(juice.scale_spring.velocity, 0.0, "the firing part's visual starts at rest")
	arena["feedback"].on_event(_event(ChEvent.PART_FIRED, 0, rocket))
	assert_true(juice.scale_spring.velocity > 0.0,
		"fired kicks the visual of the part that fired")
	for part in player.parts:
		if part == rocket:
			continue
		assert_eq(ChJuice.of(part.visual).scale_spring.velocity, 0.0,
			"the fire kicks nothing else on the chariot")
	_complete()


func test_hit_kicks_attacker_and_target() -> void:
	_clear_popups()
	var arena = await _arena()
	var player: ChChariotRuntime = arena["player"]
	var enemy: ChChariotRuntime = arena["enemy"]
	var rocket := _part(player, _typed_path(ROCKET_PATH))
	# Any mounted enemy part will do: the payload names it, and the beat follows the name.
	var target: ChPartRuntime = enemy.parts[0]
	var attacker_visual := ChJuice.of(rocket.visual)
	var target_visual := ChJuice.of(target.visual)
	var enemy_bar := ChJuice.of(arena["hud"].enemy_bar)
	var player_bar := ChJuice.of(arena["hud"].player_bar)
	arena["feedback"].on_event(_event(ChEvent.HIT, 0, rocket,
		{"target_part": target, "hp_damage": 7}))
	assert_true(attacker_visual.scale_spring.velocity > 0.0, "landed kicks the attacker's part")
	assert_true(target_visual.scale_spring.velocity > 0.0, "struck kicks the part that was hit")
	assert_true(enemy_bar.scale_spring.velocity > 0.0, "nudge kicks the struck side's HP bar")
	assert_eq(player_bar.scale_spring.velocity, 0.0, "the attacker's own bar stays still")
	# The addon parses a label's bbcode a frame after pop(), so the text is read after two.
	var main_loop = Engine.get_main_loop()
	for _frame in 2:
		await main_loop.process_frame
	var popped: Array[RicherTextLabel] = Feedback.popups.active()
	assert_eq(popped.size(), 1, "the hit popped one line")
	if popped.size() == 1:
		assert_true(popped[0].get_parsed_text().contains("-7"),
			"struck's -%d became -7 (read %s)" % [7, popped[0].get_parsed_text()])
	_complete()


func test_hull_hit_wobbles_the_enemy_chassis() -> void:
	var arena = await _arena()
	var player: ChChariotRuntime = arena["player"]
	var rocket := _part(player, _typed_path(ROCKET_PATH))
	# target_part null is a hit on the hull itself: deal_hit resolves no part and pays the chariot's
	# own HP, so the beat has to land on that chariot's chassis visual.
	var enemy: ChChariotRuntime = arena["ctx"].enemy_of(rocket)
	assert_true(enemy != null, "enemy_of names the other chariot")
	var chassis := ChJuice.of(enemy.chassis_visual)
	var attacker_chassis := ChJuice.of(player.chassis_visual)
	var enemy_bar := ChJuice.of(arena["hud"].enemy_bar)
	var player_bar := ChJuice.of(arena["hud"].player_bar)
	arena["feedback"].on_event(_event(ChEvent.HIT, 0, rocket,
		{"target_part": null, "hp_damage": 7}))
	assert_true(chassis.scale_spring.velocity > 0.0,
		"a hull hit wobbles the enemy's chassis visual")
	assert_eq(attacker_chassis.scale_spring.velocity, 0.0,
		"and leaves the attacker's own chassis alone")
	# The event's side is the attacker's, so a hull hit must invert it to reach the enemy's bar.
	assert_eq(enemy_bar.scale_spring.velocity, 3.0,
		"a hull hit nudges the struck side's bar by nudge's 3")
	assert_eq(player_bar.scale_spring.velocity, 0.0,
		"and leaves the attacker's own bar at rest")
	_complete()


func test_enemy_hull_hit_nudges_the_player_bar() -> void:
	# The other direction of the same rule: a side-1 source hitting the hull must reach the player's
	# bar. Both formulas agree when target_part names a part, so only a null target pins the inversion.
	var arena = await _arena()
	var enemy: ChChariotRuntime = arena["enemy"]
	var source: ChPartRuntime = enemy.parts[0]
	var player: ChChariotRuntime = arena["ctx"].enemy_of(source)
	assert_true(player != null and player.side == 0, "enemy_of(source) names the player's chariot")
	var player_chassis := ChJuice.of(player.chassis_visual)
	var player_bar := ChJuice.of(arena["hud"].player_bar)
	var enemy_bar := ChJuice.of(arena["hud"].enemy_bar)
	arena["feedback"].on_event(_event(ChEvent.HIT, 1, source,
		{"target_part": null, "hp_damage": 7}))
	assert_true(player_chassis.scale_spring.velocity > 0.0,
		"the enemy's hull hit wobbles the player's chassis visual")
	assert_eq(player_bar.scale_spring.velocity, 3.0,
		"an enemy hull hit nudges the player's bar by nudge's 3")
	assert_eq(enemy_bar.scale_spring.velocity, 0.0,
		"and leaves the attacking side's own bar at rest")
	_complete()


func test_caught_fire_and_fired_differ() -> void:
	_clear_popups()
	var arena = await _arena()
	var player: ChChariotRuntime = arena["player"]
	var rocket := _part(player, _typed_path(ROCKET_PATH))
	arena["feedback"].on_event(_event(ChEvent.CAUGHT_FIRE, 0, rocket))
	var main_loop = Engine.get_main_loop()
	for _frame in 2:
		await main_loop.process_frame
	var popped: Array[RicherTextLabel] = Feedback.popups.active()
	assert_eq(popped.size(), 1, "caught_fire pops one line")
	if popped.size() == 1:
		assert_true(popped[0].get_parsed_text().contains("BURN!"),
			"caught_fire says BURN! (read %s)" % [popped[0].get_parsed_text()])
	_clear_popups()
	arena["feedback"].on_event(_event(ChEvent.PART_FIRED, 0, rocket))
	for _frame in 2:
		await main_loop.process_frame
	assert_eq(Feedback.popups.active().size(), 0,
		"a fire pops no text: the fired profile carries none")
	_complete()


func _fight_state(arena: Dictionary) -> Dictionary:
	# Everything feedback is forbidden to write, read off the live objects: each part's own numbers,
	# each chariot's HP and energy pool, and every body's transform, velocity and mass (the collision
	# shape's own answer), plus the world's material-particle count — the sand cells a burst would
	# become if it were not visual-only.
	var state := {}
	for rig in [arena["player"], arena["enemy"]]:
		var side: int = rig.side
		state["hp %d" % side] = rig.hp
		state["energy %d" % side] = rig.energy.value
		var bodies: Array = [rig.chassis]
		for at in rig.parts.size():
			var part: ChPartRuntime = rig.parts[at]
			bodies.append(part.body)
			state["part %d %d" % [side, at]] = [part.integrity, part.cooldown_left,
				part.charges_left, part.burning, part.freeze, part.broken]
		for at in bodies.size():
			var body = bodies[at]
			state["body %d %d" % [side, at]] = [body.global_transform, body.linear_velocity,
				body.get_mass()]
	state["particles_material"] = arena["world"].get_stats()["particles_material"]
	return state


func test_feedback_writes_no_fight_state() -> void:
	var arena = await _arena()
	var player: ChChariotRuntime = arena["player"]
	var rocket := _part(player, _typed_path(ROCKET_PATH))
	var target: ChPartRuntime = arena["enemy"].parts[0]
	# The world is bound the way a real fight binds it, so the beats take the world path and the
	# particles they spawn are the fight's own visual ones; an unbound world would let this test pass
	# without a single burst having been asked of it.
	Feedback.bind_world(arena["world"], arena["parent"])
	var before := _fight_state(arena)
	var feedback: ChBattleFeedback = arena["feedback"]
	feedback.on_event(_event(ChEvent.PART_FIRED, 0, rocket))
	feedback.on_event(_event(ChEvent.HIT, 0, rocket, {"target_part": target, "hp_damage": 7}))
	feedback.on_event(_event(ChEvent.CAUGHT_FIRE, 0, rocket))
	feedback.on_event(_event(ChEvent.FROZEN, 0, rocket))
	feedback.on_event(_event(ChEvent.THAWED, 0, rocket))
	feedback.on_event(_event(ChEvent.PART_BROKEN, 0, rocket))
	feedback.on_event(_event(ChEvent.ENERGY_GAINED, 0, rocket))
	# No frame runs between the snapshots: the world is not stepped, so any difference is the
	# feedback's own write.
	var after := _fight_state(arena)
	assert_eq(before, after, "no event changed any fight state")
	Feedback.unbind_world()
	_complete()


func test_no_pulse_left() -> void:
	# The 0.2 s fire pulse is Feedback's now, so the battle keeps no list of pulses and no drawing
	# for them. `in` reads an object's own members, which the sanity line proves first: without it a
	# broken operator would pass this pin for ever.
	var battle := ChBattle.new()
	assert_true("started" in battle, "`in` sees a ChBattle member (the pin below is meaningful)")
	assert_true(not ("pulses" in battle), "ChBattle keeps no pulse list")
	battle.free()
	_complete()
