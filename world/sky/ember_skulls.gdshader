shader_type sky;
render_mode use_half_res_pass;
// Violet night for the vale: bruised-purple clouds, a cold lilac moon,
// and a handful of distant skulls drifting in the haze. Kept sparse.
// (Uniform names col_blood/col_ember are historical: blood = body colour, ember = rift glow.)

uniform vec3 col_abyss = vec3(0.018, 0.008, 0.048);
uniform vec3 col_blood = vec3(0.13, 0.04, 0.30);
uniform vec3 col_ember = vec3(0.42, 0.17, 0.85);
uniform vec3 col_ash   = vec3(0.08, 0.055, 0.20);
uniform vec3 moon_dir  = vec3(-0.32, 0.48, 0.62);
uniform float intensity = 1.2;
uniform float skull_count = 7.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

float skull_mask(vec2 p) {
	// Stylized skull in local 2D: cranium, jaw, sockets, nose. Soft edges.
	float cranium = 1.0 - smoothstep(0.34, 0.42, length(p - vec2(0.0, 0.16)));
	vec2 jp = (p - vec2(0.0, -0.26)) * vec2(1.15, 1.55);
	float jaw = 1.0 - smoothstep(0.20, 0.27, length(jp));
	float head = max(cranium, jaw);
	float eye_l = 1.0 - smoothstep(0.07, 0.11, length(p - vec2(-0.13, 0.17)));
	float eye_r = 1.0 - smoothstep(0.07, 0.11, length(p - vec2( 0.13, 0.17)));
	float nose = 1.0 - smoothstep(0.03, 0.065, length((p - vec2(0.0, 0.03)) * vec2(1.5, 2.1)));
	float teeth = step(abs(p.x), 0.12) * step(p.y, -0.22) * step(-0.38, p.y)
		* step(0.55, fract(p.x * 14.0));
	return clamp(head - eye_l * 0.95 - eye_r * 0.95 - nose * 0.7 - teeth * 0.35, 0.0, 1.0);
}

vec3 haze(vec3 d) {
	float up = smoothstep(-0.04, 0.62, d.y);
	float n = fbm(d.xz * 2.1 + vec2(TIME * 0.01, 0.15));
	float n2 = fbm(d.xy * 3.4 - vec2(0.0, TIME * 0.008));
	float band = smoothstep(0.22, 0.78, n) * up;
	float rift = smoothstep(0.45, 0.9, n2) * pow(max(d.y, 0.0), 0.8);
	vec3 col = mix(col_abyss, col_blood, band);
	col = mix(col, col_ash, band * n2 * 0.55);
	col += col_ember * rift * 0.28;
	col += col_ember * pow(max(d.y, 0.0), 2.2) * 0.18;
	return col * intensity;
}

float skull_field(vec3 d) {
	float acc = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float ang = fi * 0.93 + 0.4;
		float elev = 0.22 + fract(fi * 0.37) * 0.38;
		vec3 dir = normalize(vec3(sin(ang) * (0.7 + fract(fi * 0.17) * 0.5), elev, cos(ang)));
		// Slow, heavy drift — not a carnival.
		dir = normalize(dir + vec3(sin(TIME * 0.018 + fi) * 0.04, sin(TIME * 0.011 + fi * 1.7) * 0.02, 0.0));
		float facing = dot(d, dir);
		if (facing < 0.86) {
			continue;
		}
		vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), dir));
		vec3 u = cross(dir, r);
		vec2 p = vec2(dot(d, r), dot(d, u)) / max(facing, 0.2);
		float sz = 0.11 + fract(fi * 0.61) * 0.07;
		float m = skull_mask(p / sz);
		float fade = smoothstep(0.86, 0.97, facing);
		acc = max(acc, m * fade);
	}
	return acc;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		float k = smoothstep(-0.05, 0.7, EYEDIR.y);
		// Directional term: ambient light and reflections get a bright side facing the moon.
		float toward = pow(max(dot(EYEDIR, normalize(moon_dir)), 0.0), 3.0);
		COLOR = mix(col_abyss, col_blood * 0.55, k) + col_ember * toward * 0.16;
	} else if (AT_HALF_RES_PASS) {
		COLOR = haze(EYEDIR);
		ALPHA = skull_field(EYEDIR);
	} else {
		vec3 col = HALF_RES_COLOR.rgb;
		float sh = hash(floor(EYEDIR.xy * 480.0) + floor(EYEDIR.z * 480.0));
		col += step(0.9978, sh) * vec3(0.62, 0.58, 1.0) * 0.55;
		vec3 mdv = normalize(moon_dir);
		float mu = max(dot(EYEDIR, mdv), 0.0);
		vec3 right = normalize(cross(mdv, vec3(0.0, 1.0, 0.0)));
		vec3 bitan = normalize(cross(right, mdv));
		vec3 off = EYEDIR - mdv * dot(EYEDIR, mdv);
		float hx = dot(off, right);
		float hy = dot(off, bitan);
		float disc = smoothstep(0.9984, 0.9996, mu);
		float streak = exp(-abs(hx) * 48.0) * exp(-abs(hy) * 5.5) * pow(mu, 10.0);
		float cross = exp(-abs(hx) * 6.0) * exp(-abs(hy) * 48.0) * pow(mu, 10.0);
		col += vec3(0.62, 0.48, 1.05) * (disc * 2.0 + pow(mu, 160.0) * 0.45);
		col += vec3(0.48, 0.38, 1.0) * (streak * 0.85 + cross * 0.38);
		float sk = HALF_RES_COLOR.a;
		col = mix(col, col_abyss * 0.55, sk * 0.9);
		col += col_ember * sk * 0.16;
		col = mix(col_abyss * 0.65, col, smoothstep(-0.04, 0.14, EYEDIR.y));
		COLOR = col;
	}
}
