extends SceneTree

# Hand-pixelled sprites for the parts too small for gen_sprite.py (under ~16 px on the short side,
# see README.md). Each grid is the part at 1 px = 1 cell, facing +x; every pixel is solid, like the
# placeholder box the body is built from. The outer ring of every grid is the navy `k`, so the outline
# is one pixel on every side; an interior `k` is a deliberate hole (a ring's centre), not filler.
# Writes res://textures/sprites/<id>.png.
#   godot --headless --path . -s res://tools/sprites/hand_sprites.gd [-- id ...]

const OUT := "res://textures/sprites/"

const SPRITES := {
	&"freeze_charge": [{"k": "1a1c2c", "d": "3b5dc9", "l": "73eff7", "w": "f4f4f4"}, [
		"kkkk",
		"kwlk",
		"kdlk",
		"kkkk"]],
	&"strut": [{"k": "1a1c2c", "h": "c2d3dc", "m": "94b0c2", "d": "566c86"}, [
		"kkk",
		"khk",
		"kmk",
		"kmk",
		"kmk",
		"kmk",
		"kmk",
		"kkk"]],
	&"ember_battery": [{"k": "1a1c2c", "g": "566c86", "y": "ffcd75", "o": "ef7d57", "r": "b13e53"}, [
		"kkkkk",
		"kyyok",
		"kyork",
		"korrk",
		"kkkkk"]],
	&"hearth": [{"k": "1a1c2c", "L": "d77355", "b": "a03c32", "y": "ffcd75", "o": "ef7d57"}, [
		"kkkkkk",
		"kbLbLk",
		"kbbbbk",
		"kbyobk",
		"kboobk",
		"kkkkkk"]],
	&"ring_of_fire": [{"k": "1a1c2c", "g": "566c86", "y": "ffcd75", "o": "ef7d57", "r": "b13e53"}, [
		"kkkkkk",
		"kyyyyk",
		"kykkyk",
		"kykkrk",
		"koorrk",
		"kkkkkk"]],
	&"cutter_rocket": [{"k": "1a1c2c", "f": "333c57", "n": "566c86", "L": "e65a5a", "r": "b13e53", "d": "6d2433", "W": "f4f4f4", "g": "94b0c2"}, [
		"kkkkkkkk",
		"kdrLLLWk",
		"kkkkkkkk"]],
	&"corsair_harpoon": [{"k": "1a1c2c", "L": "41a6f6", "B": "3b5dc9", "d": "29366f", "g": "333c57", "s": "94b0c2", "W": "f4f4f4"}, [
		"kkkkkkkkkk",
		"kBBBBBssWk",
		"kkkkkkkkkk"]],
	&"cutter_chainsaw": [{"k": "1a1c2c", "O": "ef7d57", "y": "ffcd75", "r": "b13e53", "d": "333c57", "h": "c2d3dc", "m": "94b0c2", "x": "1a1c2c"}, [
		"kkkkkkkkkk",
		"khhmhhmhhk",
		"kOOrrddddk",
		"kkkkkkkkkk"]],
	&"firebolt_launcher": [{"k": "1a1c2c", "y": "ffcd75", "O": "ef7d57", "r": "b13e53", "D": "29366f"}, [
		"kkkkkkkk",
		"kOyyyyOk",
		"kOOOOOOk",
		"kkkkkkkk"]],
	&"flamethrower": [{"k": "1a1c2c", "y": "ffcd75", "O": "ef7d57", "r": "b13e53", "h": "94b0c2", "d": "333c57", "f": "ffcd75"}, [
		"kkkkkkkk",
		"kyOOrhhk",
		"kOrrddhk",
		"kkkkkkkk"]],
	&"ice_cream_mace": [{"k": "1a1c2c", "c": "8a5a3a", "C": "d9a066", "P": "f5a3c0", "W": "fff0f5", "p": "c0507a"}, [
		"kkkkkkkk",
		"kcCcPPPk",
		"kcCcWPpk",
		"kkkkkkkk"]],
}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id: StringName in SPRITES:
		if only.is_empty() or String(id) in only:
			_save(id, _grid(SPRITES[id][0], SPRITES[id][1]))
	quit()


func _grid(palette: Dictionary, rows: Array) -> Image:
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			image.set_pixel(x, y, Color(palette[rows[y][x]]))
	return image


func _save(id: StringName, image: Image) -> void:
	var path := OUT + String(id) + ".png"
	image.save_png(path)
	print(path)
