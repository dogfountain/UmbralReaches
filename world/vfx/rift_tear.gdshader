shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A vertical tear in the world (Rift Step): black void inside a ragged, burning violet seam.
// Billboarded around Y. open 0→1→0 over its short life (per instance).

uniform vec3 edge_col : source_color = vec3(1.6, 0.6, 3.4);
instance uniform float open = 0.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// cylindrical billboard: face the camera around world Y, keep the tear upright
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 fwd = normalize(vec3(cam.x - o.x, 0.0, cam.z - o.z));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec3 world = o + right * VERTEX.x * sc.x + vec3(0.0, 1.0, 0.0) * VERTEX.y * sc.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float y = abs(p.y);
	float w = (1.0 - y * y) * 0.8 * open;                     // lens / eye shape
	float jag = (n2(vec2(p.y * 9.0, TIME * 6.0)) - 0.5) * 0.18 * open;
	float d = abs(p.x - jag) - w;
	float inside = 1.0 - smoothstep(-0.02, 0.0, d);
	float seam = (1.0 - smoothstep(0.0, 0.09, abs(d))) * step(y, 0.98);
	float sparks = step(0.93, h2(floor(vec2(p.x * 20.0, p.y * 40.0 - TIME * 30.0)))) * (1.0 - smoothstep(0.0, 0.3, abs(d))) * open;
	vec3 c = mix(vec3(0.004, 0.0, 0.012), edge_col * 2.0, clamp(seam + sparks, 0.0, 1.0));
	ALBEDO = c;
	// near the lens the tear is only its seam: the departure tear of a forward step stands ~3 m in front of the camera
	// and its black void covered a fifth of the frame for 0.3 s (19 Nov). The void thins from 7 m in and is gone by
	// 2 m; the burning seam thins to a third and goes at the lens.
	float dist = length(VERTEX);
	float void_k = smoothstep(2.0, 7.0, dist);
	float seam_k = mix(0.35, 1.0, smoothstep(2.0, 7.0, dist)) * smoothstep(0.6, 1.6, dist);
	ALPHA = clamp(inside * 0.95 * void_k + (seam + sparks) * seam_k, 0.0, 1.0) * step(0.001, open);
}
