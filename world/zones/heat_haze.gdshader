shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// Heat shimmer over the lava pit: one flat sheet above the hottest reaches that bends what is seen through it (the screen under it, rippled
// by two slow noises). The strength fades to nothing at the sheet's edge and with the camera's distance, so the bowl wavers and the rim does
// not. A screen-space effect: no CPU work, one extra backbuffer read while the sheet is on screen.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0065;
uniform vec2 half_size = vec2(34.0, 42.0);
varying vec3 wp;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 c = (wp.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz) / half_size;
	float edge = 1.0 - smoothstep(0.55, 1.0, length(c));
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(70.0, 150.0, dist);
	vec2 n = vec2(vn(wp.xz * 0.35 + vec2(0.0, TIME * 0.9)) - 0.5, vn(wp.xz * 0.35 + vec2(7.3, -TIME * 0.7)) - 0.5);
	vec2 uv = SCREEN_UV + n * strength * edge * near;
	ALBEDO = textureLod(screen_tex, uv, 0.0).rgb;
	ALPHA = clamp(edge * near * 3.0, 0.0, 1.0);
}
