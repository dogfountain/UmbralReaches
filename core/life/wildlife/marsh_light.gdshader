shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Marsh lights, barrow lights and the Lanternwood's cold lights (core/life/wildlife/life_signs.gd): pale flames
// hanging over still water, old graves and the fungus-lit wood. Each instance's origin is its home;
// INSTANCE_CUSTOM: x = drift radius (m), y = drift speed, z = hover height (m), w = phase.
// They are only ever seen from a little way off: inside near_start metres of the camera they are gone, and they
// come back as you leave (always a little further off). Each swells in and dies away on its own slow period, with a faint
// flicker. Zero CPU: the director only sets `activity` (the Gloom tide puts them out) and `field_on`.

uniform vec3 glow_col : source_color = vec3(0.55, 0.95, 0.82);
uniform float energy = 1.5;
uniform float size = 0.2;
uniform float near_start = 10.0;
uniform float near_end = 22.0;
uniform float far_start = 120.0;
uniform float far_end = 175.0;
uniform float activity = 1.0;
instance uniform float field_on = 1.0;

varying float v_glow;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float seed = fract(float(INSTANCE_ID) * 0.61803 + c.w * 0.37);
	float t = TIME * c.y + c.w;
	vec3 pos = vec3(sin(t * 0.37 + seed * 6.0) * c.x, c.z + sin(t * 0.9 + seed * 3.0) * 0.22, cos(t * 0.29 + seed * 9.0) * c.x * 0.8);
	// each light swells and dies on its own period (9-20 s): lit about half of it
	float per = 9.0 + seed * 11.0;
	float ph = fract(TIME / per + seed * 2.7);
	float swell = smoothstep(0.0, 0.2, ph) * (1.0 - smoothstep(0.5, 0.78, ph));
	float flick = 0.86 + 0.14 * sin(TIME * 7.3 + seed * 50.0) * sin(TIME * 3.1 + seed * 20.0);
	vec3 wpos = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;
	float d = distance(wpos, CAMERA_POSITION_WORLD);
	float vis = smoothstep(near_start, near_end, d) * (1.0 - smoothstep(far_start, far_end, d));
	v_glow = swell * flick * vis * step(seed, activity) * field_on;
	// billboard, a little larger with distance so a far light still reads as a point of flame
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float s = size * (0.75 + 0.25 * swell) * (1.0 + d * 0.012);
	VERTEX = pos + to_local * (cam_r * VERTEX.x + cam_u * VERTEX.y * 1.25) * s;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q.y *= 0.85;
	float r = dot(q, q);
	float core = exp(-r * 14.0);
	float halo = exp(-r * 3.0) * 0.32;
	ALBEDO = glow_col * (core + halo) * energy * v_glow;
}
