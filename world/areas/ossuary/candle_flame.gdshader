shader_type spatial;
// Candle flame: camera-facing (Y-locked) teardrop, additive, per-instance flicker.
// Cheap enough for hundreds in one MultiMesh; emission tuned under the 1.15 glow threshold
// for most of the body so only the hot core blooms.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core = vec3(2.4, 1.5, 0.7);
uniform vec3 outer = vec3(1.0, 0.32, 0.06);

varying float seed;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 fwd = normalize(vec3(cam.x, 0.0, cam.z));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	float t = TIME * (6.0 + seed * 5.0) + seed * 40.0;
	float sway = sin(t) * 0.12 + sin(t * 2.3) * 0.06;
	float stretch = 1.0 + 0.18 * sin(t * 1.7 + 1.0);
	vec2 v = VERTEX.xy;
	float h = v.y / 0.2 + 0.5;
	VERTEX = right * (v.x + sway * h * 0.08) + vec3(0.0, 1.0, 0.0) * (v.y * stretch) + fwd * 0.0;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // x -1..1, y -1 (top) .. 1 (bottom)
	float y = -p.y;                    // 1 at top
	float width = mix(0.95, 0.05, smoothstep(-0.6, 1.0, y)) * smoothstep(-1.0, -0.55, y);
	float d = abs(p.x) / max(width, 0.001);
	float body = 1.0 - smoothstep(0.55, 1.0, d);
	float hot = (1.0 - smoothstep(0.0, 0.6, d)) * (1.0 - smoothstep(-0.2, 0.5, y));
	float flick = 0.85 + 0.15 * sin(TIME * 23.0 + seed * 91.0);
	ALBEDO = (outer * body + core * hot) * flick;
	ALPHA = body;
}
