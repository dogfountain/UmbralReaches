shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
// The Upward Falls' rising water: a sheet that stands up out of the basin and climbs the night. Streaked,
// translucent, foam at its foot, breaking into spray and sparks the higher it goes. The main sheet turns to face
// the camera about the vertical axis (a column from every side); the two fins are fixed, for parallax.

uniform float height = 64.0;
uniform float base_w = 1.5;               // half width at the foot
uniform float billboard = 1.0;
uniform float seed = 0.0;
uniform float speed = 7.0;                // metres a second
uniform float strength = 1.0;
uniform vec3 lean = vec3(6.0, 0.0, 15.0);  // where the top has drifted to, metres from the foot
uniform vec3 deep : source_color = vec3(0.10, 0.30, 0.46);
uniform vec3 pale : source_color = vec3(0.68, 0.88, 1.0);

varying vec2 v_uv;
varying float v_dist;
varying float v_far;

float hs(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ns(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float h = VERTEX.y;
	float t = clamp(h / height, 0.0, 1.0);
	vec3 axis = (MODEL_MATRIX * vec4(0.0, h, 0.0, 1.0)).xyz + lean * t * t;
	axis += vec3(sin(TIME * 0.5 + h * 0.09 + seed), 0.0, cos(TIME * 0.4 + h * 0.07 + seed)) * 1.1 * t;
	float dd = length(CAMERA_POSITION_WORLD - axis);
	v_far = smoothstep(70.0, 260.0, length(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz));
	float w = base_w * (1.0 + 0.7 * smoothstep(0.0, 16.0, h)) * (1.0 - 0.6 * smoothstep(0.4, 1.0, t)) * (1.0 + 0.9 * v_far);
	vec3 right;
	if (billboard > 0.5) {
		vec3 to_cam = CAMERA_POSITION_WORLD - axis;
		to_cam.y = 0.0;
		to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0001));
		right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	} else {
		right = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	}
	vec3 wp = axis + right * VERTEX.x * w;
	v_dist = length(CAMERA_POSITION_WORLD - wp);
	v_uv = vec2(VERTEX.x * 0.5 + 0.5, h);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float u = v_uv.x;
	float h = v_uv.y;
	float t = clamp(h / height, 0.0, 1.0);
	float up = TIME * speed;
	float side = abs(u - 0.5) * 2.0;
	// long thin streaks running up the sheet, two scales
	float s1 = ns(vec2(u * 15.0 + seed * 7.0, (h - up) * 0.26));
	float s2 = ns(vec2(u * 33.0 - seed * 5.0, (h - up * 1.5) * 0.45));
	float streak = smoothstep(0.42, 0.92, s1 * 0.6 + s2 * 0.5);
	// a ragged edge that moves up with the flow
	float en = ns(vec2(h * 0.32 - up * 0.35, seed * 3.0 + u * 2.0));
	float edge = 1.0 - smoothstep(0.50 + 0.28 * en, 1.0, side);
	// the sheet comes apart into spray as it climbs
	float dis = ns(vec2(u * 8.0 + seed, (h - up * 1.1) * 0.55));
	float thr = smoothstep(0.28, 1.0, t) * 0.92 * (1.0 - 0.7 * v_far);
	float keep = smoothstep(thr, thr + 0.16, dis);
	float fade = smoothstep(0.0, 1.2, h) * (1.0 - smoothstep(0.86, 1.0, t));
	// foam churning at the foot
	float zone = 1.0 - smoothstep(0.0, 6.0, h);
	float foam = ns(vec2(u * 9.0 + seed, h * 1.8 - TIME * 3.2)) * zone;
	// sparks on the climbing drops
	vec2 g = vec2(u * 18.0 + seed * 11.0, (h - up * 1.4) * 2.6);
	vec2 cell = floor(g);
	float r = hs(cell);
	float dotm = smoothstep(0.42, 0.08, length(fract(g) - 0.5));
	float spark = step(0.965, r) * dotm * (0.55 + 0.45 * sin(TIME * 13.0 + r * 80.0));
	vec3 col = mix(deep, pale, streak * 0.85 + 0.1);
	col = mix(col, vec3(0.92, 0.98, 1.0), clamp(foam * 0.85, 0.0, 1.0));
	col *= 0.85 + spark * 2.4;
	float a = edge * keep * fade * (0.22 + 0.5 * streak + 0.38 * foam);
	a += spark * edge * fade * 0.8;
	a *= smoothstep(1.2, 5.0, v_dist);                         // never a wall across the eyes
	a *= 1.0 - smoothstep(370.0, 430.0, v_dist);
	a *= 1.0 + 1.4 * v_far;
	ALBEDO = col * (1.0 + 0.25 * v_far);
	ALPHA = clamp(a * strength, 0.0, 0.92);
}
