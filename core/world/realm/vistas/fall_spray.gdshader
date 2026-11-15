// Spray at the foot of a fall (vista_places.gd): a cloud turned to the camera, puffs boiling up and drifting off,
// pale and cold, soft against whatever it stands in (no hard line where it meets the rock).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 tint = vec3(0.52, 0.6, 0.72);
uniform float density = 0.55;
instance uniform float seed = 0.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * n2(p); p = p * 2.03 + 1.3; a *= 0.5; }
	return v;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 fwd = normalize(vec3(to_cam.x, 0.0, to_cam.z) + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 w = origin + right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.3 + seed * 5.0;
	float d = length((uv - vec2(0.5, 0.62)) * vec2(1.0, 1.25)) * 2.0;
	float puffs = fbm(vec2(uv.x * 3.0 + seed, uv.y * 3.0 + t * 1.4)) * 0.7 + fbm(vec2(uv.x * 6.5 - t * 0.4, uv.y * 6.0 + t * 2.2)) * 0.3;
	float a = smoothstep(1.0, 0.25, d) * smoothstep(0.3, 0.75, puffs) * density;
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_z = -v.z / v.w;
	a *= smoothstep(0.0, 3.0, scene_z + VERTEX.z);
	ALBEDO = tint * (0.85 + 0.3 * puffs);
	ALPHA = clamp(a, 0.0, 0.8);
}
