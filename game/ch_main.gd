class_name ChMain extends Node

# Task 16: the loop the slice is made of - garage, one fight, its result, garage again. This node
# owns the two halves of a build (the ChInventory and the current ChChariotLayout) and hands both
# to the garage screen, which is the API the later shop wraps the same way. The fight is ChBattle
# instantiated, never a copy of its loop, and ChBattle.start is a coroutine: the result comes back
# on `finished`, which is &"win", &"loss" or &"draw" from a fight that ended, or &"aborted" when the
# arena or a chariot could not build.
# Task 3 made `finished` the fight's own end, so nothing here holds or retires a fight that is still
# running: the signal opens a result panel over a battle that has already stopped, and the panel's
# back button frees the battle and puts the garage back (Task 6).

const GARAGE := "res://game/garage/garage.tscn"
const BATTLE := "res://game/battle/battle.tscn"
const ENEMY := "res://game/data/enemies/dozer_cook.tres"
const SEED := 12345
const START := &"cutter"
const STARTER_PARTS := [&"ice_cream_mace", &"cutter_chainsaw", &"flamethrower", &"hearth",
	&"cutter_rocket", &"corsair_harpoon", &"ember_battery", &"firebolt_launcher",
	&"ring_of_fire", &"freeze_charge", &"strut"]
const STARTER_WHEELS := 4  # the brief's four wheels, spelled out instead of paired

var catalog: ChCatalog = null
var inventory: ChInventory = null
var layout: ChChariotLayout = null  # the build the garage shows and the next fight takes
var garage: ChGarage = null
var battle: ChBattle = null
var result_panel: ChResultPanel = null
var _panel_layer: CanvasLayer = null  # what the result panel is drawn on: see _init
var screen: StringName = &"garage"  # what this node is showing: garage, fight or result
var shown: ChChariotLayout = null  # the copy a fight is running, never the garage's own


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
	# The result panel's own canvas layer, because a Camera2D transforms every canvas item it shares a
	# layer with - Controls included - so a panel on the default layer is drawn at the zoomed world's
	# coordinates rather than over the screen (measured: a centred panel landed at 3558,2078 and never
	# showed). The battle's HUD is on a layer of its own for the same reason; this one is above it, so
	# the panel is never behind the HUD.
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 2
	add_child(_panel_layer)
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


func _on_fight_requested(copy: ChChariotLayout) -> void:
	# The garage asked for a fight; which fight is the owner's call, and the enemy is the
	# slice's one fixed build, read as data (ChBattle mirrors it so it faces this build).
	# shortcut: no copy is made here: the layout arrives already copied by the garage, which is
	# what keeps the garage's own build off whatever the fight does to it.
	shown = copy
	screen = &"fight"
	# The garage screen leaves the tree at the hand-back: the fight draws over it, and a build cannot
	# be edited mid-fight. hide() is what stops its clicks; nothing here reads the pointer on a frame.
	garage.hide()
	await _start_battle()


func _start_battle() -> void:
	# One ChBattle scene per fight, the same reason the garage is instantiated: start() builds
	# its arena, HUD and markers from scratch, and a second call would write the first fight's
	# nodes.
	var next: ChBattle = ResourceLoader.load(BATTLE).instantiate()
	battle = next
	# The battle is named to the handler, so a `finished` from a fight this node no longer shows
	# cannot open a panel over a later one.
	next.finished.connect(func(result: StringName) -> void: _on_finished(result, next))
	add_child(next)
	# start() answers once its own loop is over, and `finished` fired just before that, so the screen
	# is already the result panel by here; nothing is written after this await.
	await next.start(shown, ResourceLoader.load(ENEMY), catalog, SEED)


func _on_finished(result: StringName, from: ChBattle) -> void:
	# The result screen, over the fight that decided it: ChBattle stops at its own result (Task 3), so
	# the battle behind this panel is a still picture, and the panel is the only thing left to press.
	# &"aborted" reads as "no fight" rather than "loss": the arena or a chariot could not build, and
	# the layout the garage holds was never handed to anything that could have changed it.
	# shortcut: one panel naming what happened rather than three screens; to the player only a win is
	# a win.
	if from != battle:
		return
	# Idempotent against a contract-violating second `finished`: the panel is the whole result screen,
	# so a second one would stack over the first and orphan it under the layer.
	if result_panel != null:
		return
	# The HUD is a CanvasLayer above the fight's own nodes, so it would keep drawing the last HP of a
	# fight nobody can act on any more; the result screen is the panel alone.
	from.hud.visible = false
	screen = &"result"
	result_panel = ChResultPanel.new()
	result_panel.show_result(result)
	result_panel.back_pressed.connect(_on_back_pressed)
	_panel_layer.add_child(result_panel)


func _on_back_pressed() -> void:
	# The brief's hand-back - the garage, and the panel and the fight that opened it go with it.
	# Idempotent, because a second press can land in the same frame: the panel is queue_free'd rather
	# than freed (freeing a Button from inside its own `pressed` signal is not safe), so its signal is
	# still connected when that press arrives, and a second _show_garage would throw away the garage
	# the first press just made.
	if screen != &"result":
		return
	# queue_free, and not free: the panel's Button is what emitted the press this is running under.
	result_panel.queue_free()
	result_panel = null
	_release_battle()
	_show_garage()


func _release_battle() -> void:
	# The battle node leaves the tree once ChBattle's own loop is over, and `finished` is that moment
	# (Task 3), so no tick or coroutine check belongs here. The world is a child of the fight, so it
	# goes with it - on the `aborted` legs too, where the world was built but never started.
	# The reference goes with the node, so `battle` only ever names a fight this node still holds.
	if battle != null and is_instance_valid(battle):
		battle.free()
	battle = null
