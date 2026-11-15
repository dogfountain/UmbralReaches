// A beacon's fire, seen near and far (realm_vistas.gd, beacon_fire.gd): a quad turned to the camera about the vertical
// (flames stand up), a teardrop of rising noise, white-gold at the root to red at the licking tips. Far off it is drawn a
// little larger than it is (up to ~3x at 400 m), so a lit beacon still reads as a point of fire across the Realm, and
// it dims with the depth fog by hand (an additive quad would otherwise add the fog's colour). Kept near the glow
// threshold: a beacon is the brightest fire on the land, but it must not turn into a fog bank (umbral-donts).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 1.0;          // 0 cold .. 1 burning (beacon_fire.gd eases it; a flare goes over 1)
uniform float halo = 0.0;            // 1: this quad is the soft halo round the fire, not the flame
instance uniform float seed = 0.0;
varying float v_far;
varying float v_near;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	float dist = length(to_cam);
	vec3 fwd = normalize(vec3(to_cam.x, 0.0, to_cam.z) + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	vec3 up = vec3(0.0, 1.0, 0.0);
	if (halo > 0.5) {
		fwd = normalize(to_cam);
		right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
		up = cross(fwd, right);
	}
	float grow = clamp(pow(max(dist / 70.0, 1.0), 0.62), 1.0, 3.2);
	v_far = smoothstep(60.0, 380.0, dist);
	// from right over the fire a camera-turned quad is a plate: fade it there (the lamp's own flame stays)
	v_near = smoothstep(2.5, 6.0, dist) * (1.0 - smoothstep(0.55, 0.85, abs(to_cam.y) / max(dist, 0.01)) * (1.0 - smoothstep(6.0, 14.0, dist)));
	vec3 w = origin + (right * VERTEX.x + up * VERTEX.y) * grow;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 13.7;
	if (halo > 0.5) {
		float d = length(uv - 0.5) * 2.0;
		float g = exp(-d * d * 4.5) * (0.85 + 0.15 * sin(t * 7.0 + seed));
		vec3 c = vec3(1.0, 0.5, 0.18) * g * (0.32 + 0.38 * v_far);
		ALBEDO = c * energy * v_near;
		ALPHA = 1.0;
	} else {
		float y = 1.0 - uv.y;                                  // 0 at the root, 1 at the top
		float x = (uv.x - 0.5) * 2.0;
		// the flame leans and licks: rising noise displaces it sideways and breaks up its top
		float wob = (n2(vec2(y * 3.0 - t * 2.6, seed)) - 0.5) * 0.5 * y;
		float w = mix(0.95, 0.06, pow(y, 0.8)) * (0.78 + 0.35 * n2(vec2(y * 5.0 - t * 4.0, seed + 3.0)));
		float body = smoothstep(w, w * 0.35, abs(x - wob));
		float tongues = n2(vec2(x * 4.0 + seed, y * 6.0 - t * 5.5)) * n2(vec2(x * 9.0, y * 11.0 - t * 8.0) + seed);
		float a = body * smoothstep(1.0, 0.45, y + tongues * 0.5) * smoothstep(0.0, 0.08, y);
		vec3 root = vec3(1.0, 0.86, 0.55);
		vec3 mid = vec3(1.0, 0.5, 0.14);
		vec3 tip = vec3(0.7, 0.16, 0.04);
		vec3 c = mix(root, mid, smoothstep(0.05, 0.45, y));
		c = mix(c, tip, smoothstep(0.45, 0.95, y));
		float core = smoothstep(0.55, 0.0, abs(x - wob)) * smoothstep(0.6, 0.0, y);
		ALBEDO = c * a * (0.75 + 0.45 * core) * energy * mix(1.0, 0.8, v_far) * v_near;
		ALPHA = 1.0;
	}
}
