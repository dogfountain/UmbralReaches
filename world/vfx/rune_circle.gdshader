shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Lantern Ward ground sigil: two rotating rings of procedural glyphs, spokes and a soft inner
// glow, all from polar coordinates (no texture). Hard-edged on purpose (no AA in this project).

uniform vec3 color : source_color = vec3(1.6, 0.85, 0.3);
instance uniform float life = 1.0;        // 1 → 0 as the ward expires
instance uniform float bloom_in = 0.0;    // 0 → 1 on plant

float h(float x) { return fract(sin(x * 91.7) * 43758.5453); }

float glyph_band(float r, float a, float r0, float r1, float cells, float spin, float seed) {
	float band = step(r0, r) * step(r, r1);
	float aa = a + spin;
	float cell = floor(aa / TAU * cells);
	float u = fract(aa / TAU * cells);
	float v = (r - r0) / (r1 - r0);
	float k = h(cell + seed);
	// each cell draws one of four strokes: vertical bar, two bars, a chevron, or a dot
	float g = 0.0;
	if (k < 0.3) {
		g = step(abs(u - 0.5), 0.09);
	} else if (k < 0.55) {
		g = step(abs(u - 0.3), 0.06) + step(abs(u - 0.7), 0.06);
	} else if (k < 0.8) {
		g = step(abs(abs(u - 0.5) * 2.0 - v), 0.14);
	} else {
		g = step(length(vec2(u - 0.5, v - 0.5)), 0.2);
	}
	return band * clamp(g, 0.0, 1.0) * step(0.12, v) * step(v, 0.88);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + PI;
	float t = TIME;
	float edge = step(0.955, r) * step(r, 0.985);
	float ring2 = step(0.76, r) * step(r, 0.775);
	float ring3 = step(0.52, r) * step(r, 0.535);
	float g1 = glyph_band(r, a, 0.80, 0.94, 36.0, t * 0.25, 3.0);
	float g2 = glyph_band(r, a, 0.56, 0.74, 24.0, -t * 0.4, 11.0);
	float spokes = step(abs(fract((a + t * 0.1) / TAU * 8.0) - 0.5), 0.012) * step(0.12, r) * step(r, 0.52);
	float core = (1.0 - smoothstep(0.0, 0.5, r)) * 0.18;
	float reveal = step(r, bloom_in * 1.02);
	float pulse = 0.85 + 0.15 * sin(t * 3.0 + r * 9.0);
	float m = (edge * 1.4 + ring2 + ring3 + g1 * 1.2 + g2 + spokes * 0.7 + core) * reveal * pulse;
	float fade = smoothstep(0.0, 0.18, life);
	ALBEDO = color * m * fade;
	ALPHA = clamp(m * fade, 0.0, 1.0);
}
