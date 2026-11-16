shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A wayfarer's lantern seen from far off (core/life/wayfarers/wayfarers.gd): one quad per party, at the lantern's
// height over the party's place on its way. Close by, the people themselves are drawn with their own lantern glass
// and light, so this one fades in only past near_end (and out again toward far_end): what you see across the
// valley is a warm point moving along a road, bobbing with the walker's stride, now and then hidden by a tree.
// INSTANCE_CUSTOM: x = lit (0/1), y = phase, z = walking (0/1), w = 0.

uniform vec3 glow_col : source_color = vec3(1.0, 0.66, 0.32);
uniform float energy = 2.6;
uniform float size = 0.2;
uniform float near_start = 70.0;
uniform float near_end = 92.0;
uniform float far_start = 260.0;
uniform float far_end = 340.0;

varying float v_glow;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(wpos, CAMERA_POSITION_WORLD);
	float vis = smoothstep(near_start, near_end, d) * (1.0 - smoothstep(far_start, far_end, d));
	float flick = 0.88 + 0.12 * sin(TIME * 9.1 + c.y * 7.0) * sin(TIME * 2.3 + c.y * 3.0);
	v_glow = c.x * vis * flick / (1.0 + d * 0.004);
	// the stride's bob and the lantern's swing
	vec3 bob = vec3(sin(TIME * 2.1 + c.y) * 0.05, abs(sin(TIME * 2.1 + c.y)) * 0.05, 0.0) * c.z;
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float s = size * (1.0 + d * 0.022);
	VERTEX = bob + to_local * (cam_r * VERTEX.x + cam_u * VERTEX.y) * s;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = dot(q, q);
	float core = exp(-r * 16.0);
	float halo = exp(-r * 3.2) * 0.3;
	ALBEDO = glow_col * (core + halo) * energy * v_glow;
}
