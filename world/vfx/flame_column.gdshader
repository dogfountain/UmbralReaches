shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Rising column of fire on an open cylinder (Ember Lance impact). UV.y runs bottom (1) → top (0).

uniform vec3 color : source_color = vec3(2.6, 0.9, 0.3);
uniform vec3 hot : source_color = vec3(3.0, 2.2, 1.2);
instance uniform float progress = 0.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
// value noise whose x lattice repeats every `per` cells, so the cylinder's seam (UV.x 0 = 1) is not a visible line
float n2(vec2 p, float per) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = vec2(mod(i.x, per), i.y), b = vec2(mod(i.x + 1.0, per), i.y);
	return mix(mix(h2(a), h2(b), f.x), mix(h2(a + vec2(0.0, 1.0)), h2(b + vec2(0.0, 1.0)), f.x), f.y);
}

void fragment() {
	float y = 1.0 - UV.y;
	vec2 q = vec2(UV.x * 10.0, y * 3.0 - TIME * 3.5);
	float f = n2(q, 10.0) * 0.6 + n2(vec2(q.x * 2.0, q.y * 2.3 + 4.0), 20.0) * 0.4;
	float shape = (1.0 - smoothstep(0.15, 1.0, y + progress * 0.6)) * smoothstep(0.0, 0.08, y);
	float flame = smoothstep(0.35, 0.75, f + (1.0 - y) * 0.35) * shape * (1.0 - progress);
	ALBEDO = mix(color, hot, smoothstep(0.6, 1.0, f) * (1.0 - y)) * flame * 1.6;
	// r38: the silhouette of an open cylinder is a hard vertical edge (it read as a flat orange slab beside the caster):
	// the flame thins toward the edges the camera sees edge-on, so it is a column of fire, not a board
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = smoothstep(0.0, 0.55, face);
	ALBEDO *= soft;
	ALPHA = clamp(flame * soft, 0.0, 1.0);
}
