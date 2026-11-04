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


func _on_finished(result: StringName) -> void:
	# The result window. &"aborted" is a fight that could not build, so it reads as "no fight"
	# next to &"loss": the brief makes anything that is not &"win" not a win, and the layout the
	# garage holds was never handed to the fight, so it comes back unchanged either way.
	# shortcut: one panel naming what happened, rather than three screens; to the player only a
	# win is a win, and the brief asks for the result for 2 s then the garage.
	# shortcut: a fight that ends with neither chariot dead emits no `finished` at all (Task
	# 15's contract is win/loss/aborted), so the window never opens and the player keeps
	# driving the fight. A tick-budget result belongs to ChBattle's result rule, not here.
	screen = &"result"
	result_left = RESULT_SECONDS
	label.text = "You win!" if result == &"win" else \
		"You lose." if result == &"loss" else "No fight: the battle could not start."
	# The battle node stays in the tree until the window ends: start() is still ticking its
	# budget, and freeing the node that owns a running coroutine is not a safe move.


func _process(delta: float) -> void:
	# The only per-frame work is the result window: two seconds, then back to the garage with
	# the layout untouched. The fight's ticks and the garage's pointer handling run their own
	# nodes, so nothing else here needs a frame.
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
