shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Fireflies (core/life/wildlife): a small quad per insect, camera-facing, drifting on a slow
// Lissajous path round its cluster centre (instance origin) and blinking in its own rhythm.
// INSTANCE_CUSTOM: x = drift radius, y = drift speed, z = hover height, w = phase. Zero CPU.

uniform vec3 glow_col : source_color = vec3(0.75, 1.0, 0.35);
uniform float energy = 1.25;
uniform float size = 0.05;
uniform float activity = 1.0;            // director: rain and wind send them down into the grass
instance uniform float cluster_on = 1.0;      // per cluster: a hollowed thing close by puts it out

varying float v_glow;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float seed = fract(float(INSTANCE_ID) * 0.61803 + c.w * 0.37);
	float t = TIME * c.y + c.w;
	vec3 pos = vec3(sin(t * 0.71 + seed * 6.0) * c.x, c.z + sin(t * 1.3 + seed * 3.0) * 0.35 * c.z, cos(t * 0.53 + seed * 9.0) * c.x);
	pos += vec3(sin(TIME * 2.3 + seed * 40.0), sin(TIME * 1.9 + seed * 20.0), cos(TIME * 2.1 + seed * 30.0)) * 0.06;
	// blink: ~1.2 s glow every 3-6 s, soft rise and fall
	float per = 3.0 + seed * 3.0;
	float ph = fract(TIME / per + seed * 3.1);
	float glow = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.12, 0.3, ph));
	v_glow = glow * step(seed, activity * cluster_on);
	// billboard
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 off = to_local * (cam_r * VERTEX.x + cam_u * VERTEX.y) * size * (0.6 + 0.6 * glow);
	VERTEX = pos + off;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = dot(q, q);
	float core = exp(-r * 9.0);
	float halo = exp(-r * 2.5) * 0.25;
	ALBEDO = glow_col * (core + halo) * energy * v_glow;
}
