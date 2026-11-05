extends ChTest

# ChBackground: the screen-space parallax sky behind the battle. art_uv is the GDScript twin of the
# shaders' mapping, so the layout math is pinned here without reading pixels back.

const SCREEN := Vector2(1280, 720)
const TEXEL := 1.0 / 320.0


func test_art_uv_centres_at_rest() -> void:
	for z in [4.0, 4.5]:
		var uv := ChBackground.art_uv(Vector2(0.5, 0.5), SCREEN, z, ChBackground.REST, 0.25)
		assert_near(uv.x, 0.5, 0.0001, "zoom %s x" % z)
		assert_near(uv.y, 0.5, 0.0001, "zoom %s y" % z)
	_complete()


func test_pan_snaps_to_whole_texels() -> void:
	var at_rest := ChBackground.art_uv(Vector2(0.5, 0.5), SCREEN, 4.0, ChBackground.REST, 0.25)
	var under := ChBackground.art_uv(Vector2(0.5, 0.5), SCREEN, 4.0, ChBackground.REST + Vector2(3, 0), 0.25)
	var one := ChBackground.art_uv(Vector2(0.5, 0.5), SCREEN, 4.0, ChBackground.REST + Vector2(4, 0), 0.25)
	assert_near(under.x, at_rest.x, 0.000001, "0.75 texel of pan floors to none")
	assert_near(one.x - at_rest.x, TEXEL, 0.000001, "1 texel of pan moves one texel")
	_complete()


func test_layers_wrap_horizontally() -> void:
	for cam_x in [0.0, 480.0]:
		for edge in [0.0, 1.0]:
			var uv := ChBackground.art_uv(Vector2(edge, 0.5), SCREEN, 4.0, Vector2(cam_x, 90), 0.55)
			assert_true(is_finite(uv.x), "cam %s edge %s is finite" % [cam_x, edge])
			var wrapped := fposmod(uv.x, 1.0)
			assert_true(wrapped >= 0.0 and wrapped < 1.0, "cam %s edge %s wraps into the art" % [cam_x, edge])
	_complete()


func test_art_uv_vertical_outside_is_flagged() -> void:
	var top := ChBackground.art_uv(Vector2(0.5, 0.0), SCREEN, 4.5, ChBackground.REST, 0.25)
	assert_true(top.y >= 0.0, "at zoom 4.5 the art covers the top of the screen")
	var high := ChBackground.art_uv(Vector2(0.5, 0.0), SCREEN, 4.0, ChBackground.REST - Vector2(0, 40), 1.0)
	assert_true(high.y < 0.0, "a camera 40 cells up reads above the art")
	_complete()


func test_no_camera_holds_rest() -> void:
	var bg: ChBackground = _track(load("res://game/battle/background/background.tscn").instantiate())
	Engine.get_main_loop().get_root().add_child(bg)
	await Engine.get_main_loop().process_frame
	var mat := (bg.get_node("Mid") as ColorRect).material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("pan"), Vector2.ZERO)
	assert_near(mat.get_shader_parameter("view_zoom"), ChBattle.ZOOM_WIDEST)
	_complete()


func test_scene_shape() -> void:
	var bg = _track(load("res://game/battle/background/background.tscn").instantiate())
	assert_true(bg is ChBackground, "the scene root is a ChBackground")
	assert_eq(bg.layer, -10)
	var names: Array[String] = []
	for child in bg.get_children():
		names.append(String(child.name))
	assert_eq(names, ["Sky", "Mid", "Front"])
	_complete()
