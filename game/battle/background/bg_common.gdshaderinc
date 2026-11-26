// The art-space mapping both background shaders share. ChBackground.art_uv is its GDScript twin and
// the tests pin that twin, so a change here changes there too.
const vec2 ART_SIZE = vec2(320.0, 180.0);

uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float view_zoom = 4.0;  // screen px per art texel: one texel is one world cell
uniform vec2 pan = vec2(0.0);   // whole texels, snapped by ChBackground so layers never shimmer

vec2 art_uv(vec2 screen_uv) {
	vec2 p = (screen_uv - 0.5) * view_size / view_zoom + ART_SIZE * 0.5 + pan;
	return p / ART_SIZE;
}
