shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Eyes in the wood's edge (core/life/wildlife/life_signs.gd): a pair of small glints at a fox's or a badger's
// height, the wanderer's lantern caught in them. Each instance is one pair; its origin is where the animal sits.
// INSTANCE_CUSTOM: x = phase, y = look-away period (s), z = hue (0 green-gold .. 1 amber), w = how far it shifts (m).
// It watches from the dark: it blinks, looks away for a while, shifts a step, and is gone when you come within
// near_start (it slipped off) or a hollowed thing comes near (`pair_on`). Zero CPU.

uniform float energy = 0.9;
uniform float size = 0.16;
uniform float near_start = 13.0;
uniform float near_end = 19.0;
uniform float far_start = 48.0;
uniform float far_end = 64.0;
uniform float activity = 1.0;
instance uniform float pair_on = 1.0;

varying float v_glow;
varying vec3 v_col;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float seed = fract(float(INSTANCE_ID) * 0.61803 + c.x * 0.37);
	// watching for a while, then looking away (off) for a while
	float per = max(c.y, 4.0);
	float ph = fract(TIME / per + c.x);
	float watch = smoothstep(0.0, 0.04, ph) * (1.0 - smoothstep(0.58, 0.62, ph));
	// a blink every 2.5-5 s while it watches
	float bp = fract(TIME / (2.5 + seed * 2.5) + seed * 7.0);
	float blink = 1.0 - step(bp, 0.035);
	// it shifts a step each time it looks back
	float hop = floor(TIME / per + c.x);
	vec3 shift = vec3(sin(hop * 2.3 + seed * 11.0), 0.0, cos(hop * 1.7 + seed * 5.0)) * c.w;
	vec3 wpos = (MODEL_MATRIX * vec4(shift, 1.0)).xyz;
	float d = distance(wpos, CAMERA_POSITION_WORLD);
	float vis = smoothstep(near_start, near_end, d) * (1.0 - smoothstep(far_start, far_end, d));
	v_glow = watch * blink * vis * step(seed * 0.5, activity) * pair_on;
	v_col = mix(vec3(0.62, 0.9, 0.38), vec3(1.0, 0.62, 0.24), c.z);
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float s = size * (1.0 + max(d - 20.0, 0.0) * 0.02);
	VERTEX = shift + to_local * (cam_r * VERTEX.x * 1.0 + cam_u * VERTEX.y * 0.36) * s;
}

void fragment() {
	// two small glints side by side across the quad
	vec2 q = UV * 2.0 - 1.0;
	vec2 a = (q - vec2(-0.42, 0.0)) * vec2(3.2, 1.2);
	vec2 b = (q - vec2(0.42, 0.0)) * vec2(3.2, 1.2);
	float e = exp(-dot(a, a) * 2.2) + exp(-dot(b, b) * 2.2);
	ALBEDO = v_col * e * energy * v_glow;
}
