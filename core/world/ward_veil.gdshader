shader_type spatial;
// A seal's light veil (ward_seal.gd look "light"): threads of light pouring down the opening, three bands of broken runes
// across it, every edge soft. Additive, unshaded.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.5, 0.3, 1.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x) * smoothstep(0.0, 0.08, uv.y) * smoothstep(1.0, 0.9, uv.y);
	float flow = n(vec2(uv.x * 9.0, uv.y * 3.0 - TIME * 0.35)) * 0.6 + n(vec2(uv.x * 23.0, uv.y * 7.0 - TIME * 0.8)) * 0.4;
	float threads = smoothstep(0.45, 0.85, flow);
	float runes = 0.0;
	for (int i = 0; i < 3; i++) {
		float y = 0.3 + 0.2 * float(i);
		float glyph = step(0.42, h(vec2(floor(uv.x * 13.0 + float(i) * 3.7), float(i))));
		float cell = fract(uv.x * 13.0 + float(i) * 3.7);
		runes += (1.0 - smoothstep(0.006, 0.016, abs(uv.y - y))) * glyph * step(0.15, cell) * step(cell, 0.85);
	}
	float pulse = 0.85 + 0.15 * sin(TIME * 1.3 + uv.y * 4.0);
	ALBEDO = tint * (0.06 + 0.32 * threads + 0.5 * runes) * edge * pulse;
}
