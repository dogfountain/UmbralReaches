shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Rings on the fen pools (core/life/wildlife): a fish rising, a frog going in, a raindrop. One flat
// quad per ring, at the water line; each instance re-fires every `period` seconds at a new spot
// within `spread` of its origin. INSTANCE_CUSTOM: x period (s), y phase, z ring size (m),
// w = 1 for drizzle rings (shown only while it rains, scaled by `rain`), 0 for fish.

uniform vec3 ring_col : source_color = vec3(0.32, 0.4, 0.58);   // unshaded at night: a faint catch of sky, not a lit marker
uniform float strength = 0.22;
uniform float rain = 0.0;
uniform float spread = 1.6;
uniform float fish = 1.0;                // director: fish go deep when something wades in
instance uniform float splash_age = -1.0; // a one-off ring (a frog going in) on a plain MeshInstance3D

varying float v_t;
varying float v_on;
varying float v_grow;   // 0 as the ring fires, 1 at its widest: it thins and fades as it spreads

float h1(float n) { return fract(sin(n * 91.345) * 47453.5453); }

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float cyc = (TIME + c.y) / max(c.x, 0.1);
	float k = floor(cyc);
	v_t = fract(cyc) * max(c.x, 0.1);             // seconds since this ring fired
	float id = float(INSTANCE_ID) * 1.37 + k * 7.13;
	vec2 jit = (vec2(h1(id), h1(id + 3.1)) * 2.0 - 1.0) * spread * (c.w > 0.5 ? 1.0 : 0.6);
	float life = c.w > 0.5 ? 0.9 : 2.6;
	float show = c.w > 0.5 ? step(h1(id + 9.0), rain) : step(0.35, h1(id + 5.0)) * fish;
	v_on = show * (1.0 - smoothstep(life * 0.6, life, v_t));
	if (splash_age >= 0.0) {
		v_t = splash_age;
		life = 2.4;
		jit = vec2(0.0);
		v_on = 1.0 - smoothstep(life * 0.5, life, v_t);
		c.z = 0.9;
	}
	v_grow = clamp(v_t / life, 0.0, 1.0);
	float sz = c.z * (0.35 + v_t / life);
	VERTEX = vec3(jit.x, 0.0, jit.y) + VERTEX * sz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float w = mix(0.07, 0.025, v_grow);           // a fine line that thins as it spreads
	float ring = smoothstep(0.92 - w, 0.92, r) * (1.0 - smoothstep(0.92, 0.92 + w, r));
	float inner = smoothstep(0.55 - w, 0.55, r) * (1.0 - smoothstep(0.55, 0.55 + w, r)) * 0.35 * (1.0 - v_grow);
	ALBEDO = ring_col;
	ALPHA = (ring + inner) * strength * v_on * (1.0 - v_grow * 0.7);
}
