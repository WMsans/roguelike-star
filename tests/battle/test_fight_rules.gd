extends ChTest

# Task 8: the elite and boss modifiers, hooked into the live fight — ChFightRules' numbers, the fire
# multiplier on the hit path and on the enemy's burn tick, the bus's chain filter, the tick limit, and
# ChRun.rules() over the modifier that fight drew.
# The rig fixtures follow tests/battle/test_context.gd (hand-built defs on a hand-built body, so each
# test reads its own arithmetic) and tests/battle/test_behaviours_fire.gd (the real fire part defs from
# res://game/data/parts, so the "fire" tag the rule reads is the one that ships).

const GROUND_TOP := 160  # first rock row of ChTest's 480x180 arena
const ORIGIN := Vector2(120, 140)  # side 0's rig
const FAR_ORIGIN := Vector2(320, 140)  # side 1's rig, clear of the first
const TICK := 1.0 / 60.0  # one fight tick, ChBattle's own clock step
const BODY_HP := 100  # every rig's HP here, so a hit's arithmetic reads
const DAMAGE := 40  # the brief's deal_hit number: half of it is all a halved fire hit may cost
const BURN_TICKS := 60  # one second of ticks, the window ChDamage's 5 dps pays in full
const TALL_HP := 100000  # a hull no 30-tick fight can end
const TICK_LIMIT := 30  # the tick-limit fight's rule: half a second, not the 3600-tick budget


# The body every rig here sits on: 10x6 with four slots on its top row, the rig test_context.gd and
# test_behaviours_fire.gd use.
func _rig() -> ChBodyDef:
	var def := ChBodyDef.new()
	def.id = &"rig"
	def.hp = BODY_HP
	def.energy_cap = 20
	def.energy_regen = 0.0
	def.size = Vector2i(10, 6)
	def.slots = PackedVector2Array([Vector2(-5, -3), Vector2(5, -3), Vector2(0, -3), Vector2(-30, -3)])
	return def


# A part def of the burn test's own numbers: cost 0 and cooldown 0 is a passive part, which never asks
# for energy, so nothing but the burn can move its chariot's HP. 2x2 keeps its sample_rect inside the
# fire blob the test fills.
func _passive(id: StringName) -> ChPartDef:
	var def := ChPartDef.new()
	def.id = id
	def.energy_cost = 0
	def.cooldown = 0.0
	def.integrity = 100
	def.size = Vector2i(2, 2)
	def.charges = -1
	return def


# One of the slice's shipped defs, so the tags the rules read are the ones the game plays with.
func _loaded(id: StringName) -> ChPartDef:
	var def: ChPartDef = ChCatalog.load_default().part(id)
	assert_true(def != null, "%s loads from res://game/data/parts" % id)
	return def


# One layout mounting [[path, part_id]] in mount order on the rig body.
func _mount(mounts: Array) -> ChChariotLayout:
	var layout := ChChariotLayout.new()
	layout.body_id = &"rig"
	for mount in mounts:
		assert_true(layout.place(_typed_path(mount[0]), mount[1]), "%s mounts" % [mount[1]])
	return layout


# The part the builder put at a layout path; runtime.parts keeps every part's own path.
func _part_of(runtime: ChChariotRuntime, steps: Array[int]) -> ChPartRuntime:
	for part in runtime.parts:
		if part.path == steps:
			return part
	_record("no part mounted at %s" % [steps], "")
	return null


# A battle context over `rigs` (index = side) with a fresh bus, the shape both suites use.
func _battle(world: PixelWorld, catalog: ChCatalog, rigs: Array[ChChariotRuntime]) -> ChBattleContext:
	var ctx := ChBattleContext.new()
	ctx.world = world
	ctx.time = 0.0
	ctx.bus = ChEventBus.new()
	ctx.catalog = catalog
	ctx.chariots = rigs
	return ctx


# The floor the chariots stand on; fill_rect answers the cells written.
func _ground(world: PixelWorld) -> void:
	assert_eq(world.fill_rect(Rect2i(0, GROUND_TOP, 480, 20), &"rock"), 480 * 20, "rock floor laid")


# A listener of ChBehaviour's shape: the bus reads `part` off the listener to name its side.
class SideListener:
	extends RefCounted

	var part: ChPartRuntime = null


func _part_side(side: int) -> ChPartRuntime:
	var part := ChPartRuntime.new()
	part.side = side
	return part


# The table the spec pins: the elite number, and the boss's stronger one.
func test_of_numbers() -> void:
	# No modifier is the do-nothing rule, and it is what every fight without one runs on.
	var none := ChFightRules.new()
	assert_eq(none.modifier, &"", "the plain rule names no modifier")
	assert_near(none.fire_mult, 1.0, 0.0001, "nothing halves the damage")
	assert_eq(none.tick_limit, ChBattle.FIGHT_TICKS, "the fight keeps its whole 60 s budget")
	assert_near(none.chain_pass, 1.0, 0.0001, "every delivery goes through")
	assert_eq(none.banner_text(), "", "and there is nothing to banner")
	var fire := ChFightRules.of(&"fire_halved", false)
	assert_near(fire.fire_mult, 0.5, 0.0001, "an elite halves the player's fire damage")
	assert_eq(fire.banner_text(), "Fire damage halved", "and names it")
	assert_eq(fire.tick_limit, ChBattle.FIGHT_TICKS, "no other number moves")
	assert_near(fire.chain_pass, 1.0, 0.0001, "no other number moves")
	var fire_boss := ChFightRules.of(&"fire_halved", true)
	assert_near(fire_boss.fire_mult, 0.25, 0.0001, "the boss quarters it")
	assert_eq(fire_boss.banner_text(), "Fire damage halved", "the same banner, no number in it")
	var time := ChFightRules.of(&"time_limit", false)
	assert_eq(time.tick_limit, 40 * 60, "an elite gives 40 s of ticks")
	assert_eq(time.banner_text(), "Kill it in 40 s", "and banners the number it gave")
	assert_near(time.fire_mult, 1.0, 0.0001, "no other number moves")
	var time_boss := ChFightRules.of(&"time_limit", true)
	assert_eq(time_boss.tick_limit, 30 * 60, "the boss gives 30 s")
	assert_eq(time_boss.banner_text(), "Kill it in 30 s", "and banners that one")
	var chains := ChFightRules.of(&"chains_weak", false)
	assert_near(chains.chain_pass, 0.5, 0.0001, "an elite passes half the chain deliveries")
	assert_eq(chains.banner_text(), "Chains weakened", "and names it")
	var chains_boss := ChFightRules.of(&"chains_weak", true)
	assert_near(chains_boss.chain_pass, 0.25, 0.0001, "the boss passes a quarter")
	assert_eq(chains_boss.banner_text(), "Chains weakened", "the same banner, no number in it")
	_complete()


# The hit path: only the player's fire-tagged parts hit softer, and the tag comes off the def.
func test_fire_mult_on_player_fire_hit() -> void:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := ChCatalog.from_defs([_loaded(&"flamethrower"), _loaded(&"cutter_chainsaw")],
		[_rig()])
	# Side 0 carries both a fire-tagged Flamethrower and a Chainsaw that is not, so the two hits differ
	# only in the tag; side 1 carries a Flamethrower of its own.
	var mine := ChChariotBuilder.build(world, _parent(),
		_mount([[[0], &"flamethrower"], [[1], &"cutter_chainsaw"]]), catalog, 0, ORIGIN, false)
	var foe := ChChariotBuilder.build(world, _parent(), _mount([[[0], &"flamethrower"]]), catalog, 1,
		FAR_ORIGIN, false)
	var flame := _part_of(mine, [0])
	var saw := _part_of(mine, [1])
	var foe_flame := _part_of(foe, [0])
	assert_true(flame != null and saw != null and foe_flame != null, "all three parts mounted")
	assert_true(flame.def.tags.has("fire") and not saw.def.tags.has("fire"),
		"the Flamethrower is fire-tagged and the Chainsaw is not")
	var ctx: ChBattleContext = _battle(world, catalog, [mine, foe])
	var rules := ChFightRules.of(&"fire_halved", false)
	assert_near(rules.fire_mult, 0.5, 0.0001, "the fight's rule halves fire")
	ctx.rules = rules
	# The hull takes these hits, so no part wear moves the HP the asserts read.
	ctx.deal_hit(flame, foe.chassis, DAMAGE)
	assert_eq(foe.hp, BODY_HP - DAMAGE / 2, "the player's fire hit cost the enemy half of 40")
	ctx.deal_hit(saw, foe.chassis, DAMAGE)
	assert_eq(foe.hp, BODY_HP - DAMAGE / 2 - DAMAGE, "the Chainsaw still costs its full damage")
	ctx.deal_hit(foe_flame, mine.chassis, DAMAGE)
	assert_eq(mine.hp, BODY_HP - DAMAGE, "and the enemy's fire hit costs the player its full damage")
	_complete()


# One second of burning on a side-1 chariot at the given fire_mult, answered as the HP it costs.
func _burn_cost(fire_mult: float) -> int:
	var world: PixelWorld = await make_world()
	_ground(world)
	var catalog := ChCatalog.from_defs([_passive(&"strut")], [_rig()])
	# Two rigs, index = side: the side-0 one stands in no fire and must pay nothing.
	var mine := ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 0, ORIGIN,
		false)
	var foe := ChChariotBuilder.build(world, _parent(), _mount([[[0], &"strut"]]), catalog, 1, FAR_ORIGIN,
		false)
	var strut := _part_of(foe, [0])
	var ctx: ChBattleContext = _battle(world, catalog, [mine, foe])
	var rules := ChFightRules.new()
	rules.fire_mult = fire_mult
	ctx.rules = rules
	# Settle first, so the sample_rect the ticks read is the one the part holds once it is standing.
	for _tick in 30:
		await Engine.get_main_loop().process_frame
		world.step(1)
	var hp_before := foe.hp
	# The fire is re-filled every tick because the sim decides what becomes of a fire cell on its own,
	# which is what test_context.gd's burn test does for the same reason.
	for _tick in BURN_TICKS:
		world.fill_circle(Vector2i(strut.anchor_world()), 3, &"fire")
		await Engine.get_main_loop().process_frame
		world.step(1)
		ctx.tick(TICK, [0.0, 0.0], [false, false])
	assert_true(strut.burning, "the enemy's part read the fire and went burning")
	assert_eq(mine.hp, BODY_HP, "the rig standing in no fire paid nothing")
	return hp_before - foe.hp


func test_burn_mult_on_enemy() -> void:
	var full := await _burn_cost(1.0)
	var halved := await _burn_cost(0.5)
	assert_true(full >= 4 and full <= 6,
		"one second of burning costs the ~5 dps ChDamage pays (got %d)" % full)
	assert_true(halved < full, "and the halved rule costs less (%d of %d)" % [halved, full])
	assert_near(halved, full * 0.5, 1.0, "half as much, to the whole point the accumulator holds back")
	_complete()


# The bus's chain handicap: the deliveries to a player-side listener are the ones it drops.
func test_chain_filter() -> void:
	var bus := ChEventBus.new()
	# chain_pass is indexed by listener side, and a listener's side is the part its behaviour drives.
	bus.chain_pass = [0.0, 1.0]
	var heard := [0, 0, 0]  # [side 0's listener, side 1's, the listener that drives no part]
	var mine := SideListener.new()
	mine.part = _part_side(0)
	var theirs := SideListener.new()
	theirs.part = _part_side(1)
	var sink := RefCounted.new()  # ChBattleFeedback's shape: a listener with no `part` of its own
	bus.subscribe(mine, ChEvent.HIT, func(_event: ChEvent): heard[0] += 1)
	bus.subscribe(theirs, ChEvent.HIT, func(_event: ChEvent): heard[1] += 1)
	bus.subscribe(sink, ChEvent.HIT, func(_event: ChEvent): heard[2] += 1)
	var event := ChEvent.new()
	event.type = ChEvent.HIT
	for _at in 20:
		bus.emit(event)
	bus.unsubscribe_all(mine)
	bus.unsubscribe_all(theirs)
	bus.unsubscribe_all(sink)
	assert_eq(heard[0], 0, "a pass of 0.0 never delivered to the side-0 listener")
	assert_eq(heard[1], 20, "the side-1 listener heard all of them")
	assert_eq(heard[2], 20, "and so did a listener with no part, which is what feedback is")
	# The filter draws from the bus's own seeded rng, so a replayed fight drops the same deliveries: two
	# buses with the same seed and the same pass hear exactly as much as each other.
	var again := ChEventBus.new()
	for at in [bus, again]:
		at.chain_pass = [0.5, 1.0]
		at.rng.seed = 9001
	var one := [0]
	var two := [0]
	bus.subscribe(mine, ChEvent.HIT, func(_event: ChEvent): one[0] += 1)
	again.subscribe(mine, ChEvent.HIT, func(_event: ChEvent): two[0] += 1)
	for _at in 40:
		bus.emit(event)
		again.emit(event)
	bus.unsubscribe_all(mine)
	again.unsubscribe_all(mine)
	assert_true(one[0] > 0 and one[0] < 40, "a pass of 0.5 delivers some but not all (got %d)" % one[0])
	assert_eq(one[0], two[0], "and the same seed drops the same deliveries")
	_complete()


# A battle node in the tree with both chariots' drive and press seams from test_battle.gd stubbed to
# nothing: nobody steers and nobody fires, so only a rule can move the fight. The caller starts it, so
# it can connect `finished` first, and frees it when it is done reading.
func _idle_battle() -> ChBattle:
	var scene: PackedScene = ResourceLoader.load("res://game/battle/battle.tscn")
	assert_true(scene != null, "battle.tscn loads")
	var battle: Node2D = scene.instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	battle.drivers = [func(_b, _s): return 0.0, func(_b, _s): return 0.0]
	battle.pressers = [func(_b, _s): return false, func(_b, _s): return false]
	return battle


# The battle's half of the time limit: the tick loop stops at the rule's budget, and a fight nobody
# died in still names its result. Both chariots idle through the drivers/pressers seams test_battle.gd
# uses, so only the rule can end it.
func test_tick_limit() -> void:
	var battle: ChBattle = _idle_battle()
	var results: Array[StringName] = []
	var sink := results
	battle.finished.connect(func(result: StringName): sink.append(result))
	var rules := ChFightRules.new()
	rules.tick_limit = TICK_LIMIT
	await battle.start(_player_layout(), _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP), 12345, rules)
	assert_eq(results.size(), 1, "the short fight announced exactly one result")
	assert_eq(results, [&"draw"], "nobody died inside 30 ticks, so it is a draw")
	assert_near(battle.ctx.time, TICK_LIMIT * TICK, TICK,
		"and it spent the rule's %d ticks, not the 3600-tick budget" % TICK_LIMIT)
	assert_true(battle.hud.countdown != null, "a time-limit fight put a countdown on the HUD")
	# The wiring the modifier needs, read while the fight is over: the context got a rule to work from,
	# and a fight that asked for no modifier got no chain handicap and no banner.
	assert_true(battle.ctx.rules != null, "the fight ran with a rule object of its own")
	assert_near(battle.ctx.bus.chain_pass[0], 1.0, 0.0001, "no modifier, so no chain handicap")
	assert_near(battle.ctx.bus.chain_pass[1], 1.0, 0.0001, "on either side")
	assert_true(battle.hud.banner == null, "and nothing was bannered")
	battle.free()
	_complete()


# The seam every modifier depends on, end to end: a real ChFightRules.of(...) handed to start() gets its
# own chain share onto the fight's bus and its own words onto the fight's HUD. The rule's tick_limit is
# cut to TICK_LIMIT so the fight costs 30 frames rather than the full 3600; neither number asserted here
# comes from that budget.
func test_rules_reach_the_bus_and_the_banner() -> void:
	var battle: ChBattle = _idle_battle()
	var rules := ChFightRules.of(&"chains_weak", false)
	rules.tick_limit = TICK_LIMIT
	await battle.start(_player_layout(), _enemy_layout(), _fight_catalog(TALL_HP, TALL_HP), 12345, rules)
	assert_true(battle.ctx.rules == rules, "the fight ran on the rule object it was handed")
	assert_near(battle.ctx.bus.chain_pass[0], 0.5, 0.0001,
		"the rule's chain share reached the bus, on the player's side")
	assert_near(battle.ctx.bus.chain_pass[1], 1.0, 0.0001, "and the enemy's side stayed unhandicapped")
	var banner: Label = battle.hud.banner
	assert_true(banner != null, "the fight bannered its modifier at the start")
	assert_eq(banner.text if banner != null else "", "Chains weakened", "with the rule's own words")
	battle.free()
	_complete()


# The HUD half: the banner appears with the fight and goes away, and the countdown label exists only
# once a time-limit fight asks for one.
func test_banner_and_countdown() -> void:
	var hud := ChBattleHud.new()
	Engine.get_main_loop().get_root().add_child(hud)
	_track(hud)
	assert_true(hud.get("countdown") == null, "no countdown before a time-limit fight asks for one")
	hud.show_countdown(40)
	assert_true(hud.countdown != null, "the first call made the label")
	assert_eq(hud.countdown.text, "40 s", "and it reads the seconds left")
	var label: Label = hud.countdown
	hud.show_countdown(39)
	assert_true(hud.countdown == label, "the next tick writes on that label instead of adding one")
	hud.show_banner("Chains weakened")
	assert_true(hud.banner != null and hud.banner.visible, "the banner shows at fight start")
	assert_eq(hud.banner.text, "Chains weakened", "with the modifier's own text")
	# The spec's 2 s, spent on the tree's frames rather than a fight tick.
	var frames := 0
	while hud.banner != null and frames < 400:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(hud.banner == null, "and it is gone again after the spec's 2 s")
	_complete()


# ChRun's one line: the fight's drawn modifier and its kind make that fight's rule.
func test_run_rules_for_its_fight() -> void:
	var run := ChRun.start(7, ChCatalog.load_default())
	for index in [2, 5, 8]:
		assert_true(run.modifiers.has(index), "fight %d drew a modifier" % index)
		var rules := run.rules(index)
		assert_eq(rules.modifier, run.modifiers[index], "and its rule names that draw")
	var boss := run.rules(ChRun.LAST_INDEX)
	assert_eq(run.kind(ChRun.LAST_INDEX), &"boss", "the last fight is the boss")
	# The boss's stronger number, whichever modifier it drew.
	if boss.modifier == &"fire_halved":
		assert_near(boss.fire_mult, 0.25, 0.0001, "the boss quarters fire")
	elif boss.modifier == &"time_limit":
		assert_eq(boss.tick_limit, 30 * 60, "the boss gives 30 s")
	else:
		assert_near(boss.chain_pass, 0.25, 0.0001, "the boss passes a quarter of the deliveries")
	var normal := run.rules(0)
	assert_eq(normal.modifier, &"", "a normal fight drew nothing")
	assert_eq(normal.tick_limit, ChBattle.FIGHT_TICKS, "so it keeps the whole budget")
	assert_eq(normal.banner_text(), "", "and banners nothing")
	_complete()
