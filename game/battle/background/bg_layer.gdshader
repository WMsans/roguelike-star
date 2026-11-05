shader_type canvas_item;
render_mode unshaded;

// A silhouette layer (bg1/bg2): the art's dark luma is stretched by grade_gain and looked up in a
// bright gradient, so the painted shading survives as saturated tones instead of near-black.
#include "res://game/battle/background/bg_common.gdshaderinc"

uniform sampler2D layer_tex : repeat_enable, filter_nearest;
uniform sampler2D grade : filter_linear;
uniform float grade_gain = 4.0;
uniform float opacity = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec2 uv = art_uv(UV);
	vec4 s = texture(layer_tex, uv);
	// Horizontal wrap tiles the layer; vertical must not, or a second ridge would hang in the sky.
	float inside = step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 col = texture(grade, vec2(clamp(dot(s.rgb, LUMA) * grade_gain, 0.0, 1.0), 0.5)).rgb;
	COLOR = vec4(col, s.a * inside * opacity);
}
