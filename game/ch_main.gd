class_name ChMain extends Node

# Task 16: the loop the slice is made of - garage, one fight, the result, garage again. This node
# owns the two halves of a build (the ChInventory and the current ChChariotLayout) and hands both
# to the garage screen, which is the API the later shop wraps the same way. The fight is ChBattle
# instantiated, never a copy of its loop, and ChBattle.start is a coroutine: the result comes back
# on `finished`, which is &"win", &"loss" or &"aborted" when the arena or a chariot could not
# build, so anything that is not &"win" reads as "no fight" and nothing here waits for a signal
# that already fired.

const GARAGE := "res://game/garage/garage.tscn"
const BATTLE := "res://game/battle/battle.tscn"
const ENEMY := "res://game/data/enemies/dozer_cook.tres"
const RESULT_SECONDS := 2.0
const FIGHT_WATCHDOG := 60.0  # ChBattle's own budget: FIGHT_TICKS 3600 at TICK 1/60 = 60 s of ticks
const WATCHDOG_TEXT := "Rounds ran out: nobody died."  # what the watchdog's non-win reads as
const SEED := 12345
const START := &"cutter"
const FIGHT_TEXT := "Fighting ..."
const STARTER_PARTS := [&"ice_cream_mace", &"cutter_chainsaw", &"flamethrower", &"hearth",
	&"cutter_rocket", &"corsair_harpoon", &"ember_battery", &"firebolt_launcher",
	&"ring_of_fire", &"freeze_charge", &"strut"]
const STARTER_WHEELS := 4  # the brief's four wheels, spelled out instead of paired

var catalog: ChCatalog = null
var inventory: ChInventory = null
var layout: ChChariotLayout = null  # the build the garage shows and the next fight takes
var garage: ChGarage = null
var battle: ChBattle = null
var label: Label = null
var screen: StringName = &"garage"  # what this node is showing: garage, fight or result
var shown: ChChariotLayout = null  # the copy a fight is running, never the garage's own
var result_left := 0.0  # seconds of the result panel left
var fight_left := 0.0  # seconds the current fight may run before it must hand the loop back


func _init() -> void:
	# Everything owned is made once here: the kit and the starting build, then the first screen.
	# shortcut: the fight seed is fixed, so a rematch is the same terrain and the same enemy -
	# the brief's loop is retried by eye rather than rerolled per run.
	catalog = ChCatalog.load_default()
	inventory = _starter_inventory()
	layout = ChChariotLayout.new()
	# An empty build on a body the catalog has a def for, so swap_body can measure it and the
	# pit opens on empty markers.
	layout.body_id = START
	label = Label.new()
	# The result panel: one line at the bottom left, the same 8px as the garage's own text.
	label.position = Vector2(8.0, 168.0)
	label.add_theme_font_size_override("font_size", 8)
	label.text = ""
	add_child(label)
	_show_garage()


func _starter_inventory() -> ChInventory:
	var kit := ChInventory.new()
	# capacity stays -1, the unlimited case: a lift then cannot lose a part to ChInventory's own
	# cap, which is a shop's rule to set, not the garage's.
	for id in STARTER_PARTS:
		# add never dedupes, so two of a part is two calls.
		kit.add(id)
		kit.add(id)
	for _wheel in STARTER_WHEELS:
		kit.add(&"wheel")
	return kit


func _show_garage() -> void:
	# The screen is instantiated each time it comes back, so the garage after a fight is a fresh
	# node over the same two halves: the layout it shows is the one that was never touched, which
	# is the brief's "returns to the garage with the layout unchanged".
	# The screen that was showing leaves before the new one arrives, so the tree holds one
	# garage at a time whatever the number of fights.
	if garage != null and is_instance_valid(garage):
		garage.free()
	var next: ChGarage = ResourceLoader.load(GARAGE).instantiate()
	next.setup(inventory, layout, catalog)
	next.fight_requested.connect(_on_fight_requested)
	add_child(next)
	garage = next
	screen = &"garage"
	label.text = ""


func _on_fight_requested(copy: ChChariotLayout) -> void:
	# The garage asked for a fight; which fight is the owner's call, and the enemy is the
	# slice's one fixed build, read as data (ChBattle mirrors it so it faces this build).
	# shortcut: no copy is made here: the layout arrives already copied by the garage, which is
	# what keeps the garage's own build off whatever the fight does to it.
	shown = copy
	screen = &"fight"
	# The garage screen stops taking the pointer while the fight runs, and leaves the tree when
	# the result window ends: the fight draws over it, and a build cannot be edited mid-fight.
	garage.set_process(false)
	garage.hide()
	fight_left = FIGHT_WATCHDOG
	await _start_battle()


func _start_battle() -> void:
	# One ChBattle scene per fight, the same reason the garage is instantiated: start() builds
	# its arena, HUD and markers from scratch, and a second call would write the first fight's
	# nodes. The coroutine is awaited here, so the fight's ticks run on this node's frames.
	var next: ChBattle = ResourceLoader.load(BATTLE).instantiate()
	battle = next
	next.finished.connect(_on_finished)
	add_child(next)
	label.text = FIGHT_TEXT
	await next.start(shown, ResourceLoader.load(ENEMY), catalog, SEED)
	# start() answers only after its whole tick budget, so `finished` has usually moved the
	# screen to the result panel already; nothing is written after that await.


func _open_result(text: String) -> void:
	# One window for every outcome, so a real `finished` and the watchdog hand the loop back the
	# same way: the battle node stays until the window ends, because start() may still be ticking.
	screen = &"result"
	result_left = RESULT_SECONDS
	label.text = text


func _on_finished(result: StringName) -> void:
	# The result window. &"aborted" is a fight that could not build, so it reads as "no fight"
	# next to &"loss": the brief makes anything that is not &"win" not a win, and the layout the
	# garage holds was never handed to the fight, so it comes back unchanged either way.
	# shortcut: one panel naming what happened, rather than three screens; to the player only a
	# win is a win, and the brief asks for the result for 2 s then the garage.
	_open_result("You win!" if result == &"win" else \
		"You lose." if result == &"loss" else "No fight: the battle could not start.")


func _process(delta: float) -> void:
	# The two countdowns, one per screen this node can be stuck on: a fight that has spent its
	# budget without announcing, then the result window's two seconds back to the garage. The
	# fight's ticks and the garage's pointer handling run their own nodes, so nothing else here
	# needs a frame.
	if screen == &"fight":
		# The watchdog: ChBattle emits `finished` only when an HP reaches 0, so a fight that runs
		# its whole tick budget with both hulls standing announces nothing, and this node is what
		# gets the loop back. Same budget the fight and the tests give it, so the watchdog only
		# speaks after a fight spent its own budget and stayed silent.
		# shortcut: two limits, both because ChBattle's contract stays win/loss/aborted: the outcome
		# is NAMED here rather than by the fight, and the budget is counted in real seconds while
		# the fight counts ticks, so on a display faster than 60 fps the fight's own loop returns
		# first and the panel waits out the rest of the countdown. Upgrade in ChBattle's result rule
		# if the slice ever wants a fight that ends with both hulls standing named as its own result.
		fight_left -= delta
		if fight_left > 0.0:
			return
		_open_result(WATCHDOG_TEXT)
		return
	if screen != &"result":
		return
	# The window counts real frames rather than reading a clock, so a headless run that ticks
	# faster than a display still waits the brief's two seconds.
	result_left -= delta
	if result_left > 0.0:
		return
	if battle != null and is_instance_valid(battle):
		# The fight ran to its tick budget before this window ended, so its coroutine is done
		# and the node is free to leave, which is the case Task 15's tests free on.
		battle.free()
	_show_garage()
