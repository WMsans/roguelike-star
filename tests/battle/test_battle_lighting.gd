extends ChTest

# The battle's bright look: the world lit at full ambient over a transparent backdrop, light allowed
# above 1.0 on an HDR canvas, and the parallax sky on a layer behind the world and under the HUD.

const ENEMY_HP := 30  # one Rocket hit ends the fight, so the run stays cheap (test_battle.gd's value)


func _battle_scene() -> Node2D:
	var battle: Node2D = ResourceLoader.load("res://game/battle/battle.tscn").instantiate()
	Engine.get_main_loop().get_root().add_child(battle)
	return battle


func _assert_lit(world: PixelWorld, when: String) -> void:
	assert_near(world.ambient, ChBattle.AMBIENT, 0.001, when + ": ambient")
	for i in 3:
		assert_near(world.ambient_tint[i], ChBattle.AMBIENT_TINT[i], 0.001, when + ": tint %d" % i)
	assert_near(world.light_headroom, ChBattle.LIGHT_HEADROOM, 0.001, when + ": headroom")
	assert_eq(world.backdrop_color.a, 0.0, when + ": the backdrop lets the sky through")


# One fight covers both moments the Review Focus names: lit as soon as the world exists, and still
# lit (with the sky still up) once the fight has frozen at its result.
func test_world_is_lit_bright_and_stays_lit() -> void:
	var battle := _battle_scene()
	battle.start(_player_layout(), _enemy_layout(), _fight_catalog(ENEMY_HP), 12345)
	var frames := 0
	while not battle.started and frames < 2 * WAIT_FRAMES:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(battle.started, "the fight got past its arena build")
	_assert_lit(battle.world, "at the start")
	frames = 0
	while battle.ticking and frames < 4000:
		await Engine.get_main_loop().process_frame
		frames += 1
	assert_true(not battle.ticking, "the fight reached its result")
	_assert_lit(battle.world, "after the result")
	var bg := battle.get_node("Background") as ChBackground
	assert_true(bg != null and bg.is_inside_tree() and bg.visible, "the sky is still up after the fight")
	battle.free()
	_complete()


func test_background_sits_behind_world() -> void:
	var battle: Node2D = _track(_battle_scene())
	var bg := battle.get_node_or_null("Background") as ChBackground
	assert_true(bg != null, "battle.tscn carries the ChBackground")
	if bg != null:
		assert_true(bg.layer < 0, "the sky draws behind the world's default layer")
		assert_true((battle.get_node("HUD") as CanvasLayer).layer > bg.layer, "the HUD draws over the sky")
	_complete()


# hdr_2d is the battle's alone: the garage and its UI share the root viewport and keep the 8-bit,
# sRGB-blended canvas they were laid out on, so the battle turns it on while it is in the tree and
# hands the viewport back as it found it.
func test_hdr_2d_only_while_battling() -> void:
	var viewport := Engine.get_main_loop().get_root() as Viewport
	assert_eq(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false), false, "off project-wide")
	var before := viewport.use_hdr_2d
	var battle := _battle_scene()
	assert_true(viewport.use_hdr_2d, "headroom above 1.0 only survives the multiply on an HDR canvas")
	battle.free()
	assert_eq(viewport.use_hdr_2d, before, "the viewport is handed back as the battle found it")
	_complete()
