// A beacon's smoke (beacon_fire.gd): a tall quad turned to the camera about the vertical, a column of rising, curling
// smoke that leans downwind, lit warm from the fire at its root and going cold and thin as it climbs. Alpha, not added:
// it darkens the stars behind it as much as it glows. Drawn from far off (the column is the beacon's mark by day too).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 1.0;
instance uniform float seed = 0.0;
uniform vec2 wind = vec2(0.6, 0.25);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * n2(p); p = p * 2.03 + 1.7; a *= 0.5; }
	return v;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 fwd = normalize(vec3(to_cam.x, 0.0, to_cam.z) + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	float h = VERTEX.y;
	// the column leans downwind and widens as it rises
	vec3 lean = vec3(wind.x, 0.0, wind.y) * h * h * 0.018;
	float widen = 1.0 + h * 0.07;
	vec3 w = origin + right * VERTEX.x * widen + vec3(0.0, h, 0.0) + lean;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	float y = 1.0 - UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float t = TIME * 0.35 + seed * 9.1;
	float curl = fbm(vec2(x * 1.4 + y * 2.0, y * 5.0 - t * 1.6) + seed);
	float sheet = smoothstep(0.95, 0.15, abs(x + (curl - 0.5) * 0.9));
	float puffs = fbm(vec2(x * 2.6, y * 9.0 - t * 2.4) + seed * 3.0);
	float a = sheet * smoothstep(0.25, 0.7, puffs + 0.25 * (1.0 - y)) * smoothstep(0.0, 0.06, y) * smoothstep(1.0, 0.55, y);
	a *= mix(0.62, 0.22, y) * energy;
	vec3 lit = vec3(0.78, 0.36, 0.14) * 0.85;
	vec3 cold = vec3(0.075, 0.08, 0.1);
	ALBEDO = mix(lit, cold, smoothstep(0.0, 0.3, y));
	ALPHA = clamp(a, 0.0, 1.0);
}
