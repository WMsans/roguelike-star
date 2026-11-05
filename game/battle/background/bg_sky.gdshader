shader_type canvas_item;
render_mode unshaded;

// The far sky: a screen-space gradient (so it never slides with the camera) with bg0's cloud bands
// lifted toward cloud_color, plus a soft sun. bg0's five reds only carry shape, never colour.
#include "res://game/battle/background/bg_common.gdshaderinc"

uniform sampler2D cloud_tex : repeat_enable, filter_nearest;
uniform sampler2D sky_gradient : source_color, filter_linear;

// bg0's palette spans luma ~0.36-0.49; mask_lo/hi stretch that span to 0..1.
uniform float mask_lo = 0.36;
uniform float mask_hi = 0.49;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.94);
uniform float cloud_strength = 0.75;

uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.62);
uniform vec2 sun_uv = vec2(0.78, 0.22);
uniform float sun_radius = 0.45;
uniform float sun_strength = 0.35;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 col = texture(sky_gradient, vec2(clamp(UV.y, 0.0, 1.0), 0.5)).rgb;
	vec2 uv = art_uv(UV);
	uv.y = clamp(uv.y, 0.0, 1.0);
	float m = smoothstep(mask_lo, mask_hi, dot(texture(cloud_tex, uv).rgb, LUMA));
	col = mix(col, cloud_color, m * cloud_strength);
	vec2 d = (UV - sun_uv) * vec2(view_size.x / view_size.y, 1.0);
	col += sun_color * smoothstep(sun_radius, 0.0, length(d)) * sun_strength;
	COLOR = vec4(col, 1.0);
}
