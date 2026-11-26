@tool
extends RichTextEffect

# Syntax: [jump=45][]
var bbcode = "jump"

const SPLITTERS := " .,"

var _w_char = 0
var _last = 999

func _process_custom_fx(c:CharFXTransform):
	var t: RicherTextLabel = instance_from_id(get_meta("rt"))
	# shortcut: local Godot 4.7 compat port of rte_jump (absolute_index/character removed, t.size is a Vector2); drop when upstream richtext2 supports 4.7.
	var text := t.get_parsed_text()
	var index := c.range.x
	var is_splitter := index >= 0 and index < text.length() and text[index] in SPLITTERS
	if index < _last or is_splitter:
		_w_char = index
	
	_last = index
	var a = deg_to_rad(c.env.get("angle", 0))
	var s = -abs(sin(-c.elapsed_time * 6.0 + _w_char * PI * .025))
	s *= c.env.get("scale", 1.0) * t.font_size * .125
	c.offset.x += sin(a) * s
	c.offset.y += cos(a) * s
	return true
