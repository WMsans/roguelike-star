class_name ChMain extends Node

# Task 13: the run's own loop. A run is ten fights (ChRun) and a shop between them (ChShopScreen),
# and this node owns the one catalog and the one run every screen reads. `screen` names what is up:
# &"fight", &"result" or &"shop".
# A fight is ChBattle instantiated, never a copy of its loop, and ChBattle.start is a coroutine: the
# result comes back on `finished`, which is &"win", &"loss" or &"draw" from a fight that ended, or
# &"aborted" when the arena or a chariot could not build. ChRun hands that fight its own copies of
# both builds, so nothing a fight does can reach the run's build.

const BATTLE := "res://game/battle/battle.tscn"

var catalog: ChCatalog = null
var run: ChRun = null
var battle: ChBattle = null
var shop: ChShopScreen = null
var result_panel: ChResultPanel = null
var _panel_layer: CanvasLayer = null  # what the shop and the result panel are drawn on: see _init
var screen: StringName = &""  # what this node is showing: fight, result or shop
var _result := &""  # what the panel is showing, which the back button branches on


func _init() -> void:
	# The one catalog the whole run reads: ChCatalog.load_default() builds a new table per call, so a
	# second one would price and HP-read a different table than the run holds.
	catalog = ChCatalog.load_default()
	# The shop and the result panel share this canvas layer, because a Camera2D transforms every canvas
	# item it shares a layer with - Controls included - so a panel on the default layer is drawn at the
	# zoomed world's coordinates rather than over the screen (measured: a centred panel landed at
	# 3558,2078 and never showed). The battle's HUD is on a layer of its own for the same reason; this
	# one is above it, so a screen is never behind the HUD.
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 2
	add_child(_panel_layer)
	# The game opens in fight 1.
	_new_run()


func _new_run() -> void:
	# A run from its own seed, then its first fight: the shop is between fights, so there is none yet.
	run = ChRun.start(randi(), catalog)
	_start_battle()


func _show_shop() -> void:
	# The shop between fights. It is built while run.fight_index is still the fight just won, because
	# ChShopPhase credits run.reward(run.fight_index) in its constructor; the index advances after the
	# screen exists, so the reward paid is the one that fight earned.
	var next := ChShopScreen.new()
	shop = next
	next.fight_requested.connect(_start_battle)
	# Added before setup: the screen and its bar anchor themselves to the viewport on _ready, so their
	# rects are final and the bar's slots sit at their real screen points.
	_panel_layer.add_child(next)
	next.setup(run, catalog)
	run.fight_index += 1
	screen = &"shop"


func _start_battle() -> void:
	# One ChBattle scene per fight, the same reason a screen is instantiated: start() builds its
	# arena, HUD and markers from scratch, and a second call would write the first fight's nodes.
	screen = &"fight"
	_free_screens()
	var next: ChBattle = ResourceLoader.load(BATTLE).instantiate()
	battle = next
	# The battle is named to the handler, so a `finished` from a fight this node no longer shows
	# cannot open a panel over a later one.
	next.finished.connect(func(result: StringName) -> void: _on_finished(result, next))
	add_child(next)
	# The fight streams its arena on the tree's own frames, and _init starts the run's first fight
	# before this node is in the tree (a scene's _init runs at instantiate(), not at add_child). The
	# ready signal is the moment both nodes are in it.
	if not is_inside_tree():
		await ready
	# start() answers once its own loop is over, and `finished` fired just before that, so the screen
	# is already the result panel by here; nothing is written after this await.
	await next.start(run.player_layout(), run.enemy_layout(run.fight_index), catalog,
		run.fight_seed(run.fight_index), run.rules(run.fight_index))


func _on_finished(result: StringName, from: ChBattle) -> void:
	# The result screen, over the fight that decided it: ChBattle stops at its own result, so the
	# battle behind this panel is a still picture, and the panel is the only thing left to press.
	# &"aborted" reads as "no fight" rather than "loss": nothing was fought, and the run's build was
	# never handed to anything that could have changed it.
	if from != battle:
		return
	# Idempotent against a contract-violating second `finished`: the panel is the whole result screen,
	# so a second one would stack over the first and orphan it under the layer.
	if result_panel != null:
		return
	# The HUD is a CanvasLayer above the fight's own nodes, so it would keep drawing the last HP of a
	# fight nobody can act on any more; the result screen is the panel alone.
	if from.hud != null:
		from.hud.visible = false
	_result = result
	screen = &"result"
	result_panel = ChResultPanel.new()
	# The run's last fight is the run itself won, which a bare &"win" cannot name.
	result_panel.show_result(result, run.is_last(run.fight_index))
	result_panel.back_pressed.connect(_on_back_pressed)
	_panel_layer.add_child(result_panel)


func _on_back_pressed() -> void:
	# Where the result's one button leads: a run that ended starts a new one, a fight that could not
	# start is retried on the same fight, and anything else goes to the shop for the next fight.
	# Idempotent, because a second press can land in the same frame: the panel is queue_free'd rather
	# than freed (freeing a Button from inside its own `pressed` signal is not safe), so its signal is
	# still connected when that press arrives. Every leg below sets `screen` before it returns, so the
	# second press finds a different screen and is a no-op.
	if screen != &"result":
		return
	var ends_run := result_panel != null and result_panel.ends_run
	var result := _result
	_result = &""
	if result_panel != null:
		result_panel.queue_free()
		result_panel = null
	if ends_run:
		_new_run()
	elif result == &"aborted":
		_start_battle()
	else:
		_show_shop()


func _free_screens() -> void:
	# Every screen this node showed leaves before the next one arrives, so the tree holds one screen
	# at a time. The result panel is queue_free'd for the reason above; the shop and the battle leave
	# the screen at once, so a fight is never drawn (or clicked) under the screen that replaced it.
	if result_panel != null and is_instance_valid(result_panel):
		result_panel.queue_free()
	if shop != null and is_instance_valid(shop):
		# The shop is freed from inside its own signal (its Fight button emitted fight_requested), and
		# Godot's free() refuses an object that is calling: detaching it takes it off the screen now,
		# and queue_free takes the node out of the tree at the end of the frame.
		shop.get_parent().remove_child(shop)
		shop.queue_free()
	if battle != null and is_instance_valid(battle):
		battle.free()
	result_panel = null
	shop = null
	battle = null
