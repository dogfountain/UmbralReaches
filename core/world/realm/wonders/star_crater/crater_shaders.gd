extends RefCounted
## The Star-Fall Crater's surfaces, all procedural: the fused glass ground (cracks lit from the star, plates of
## slightly different tint, a ragged edge where it gives out to salt), the crystals (facets catching light,
## glow rising to the tips, a pulse that travels out from the heart), the heart itself (turning), the ring of
## fragments (orbiting in the vertex stage: no per-frame script), and the halo that makes it a point of light
## from far off.

const GLASS := """shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
uniform vec3 centre = vec3(0.0);
uniform float glow_h = 12.0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.5 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.2; }
// x: distance to the nearest cell point, y: gap to the second nearest (zero on a crack), zw: the cell id
vec4 vor(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 9.0; float d2 = 9.0; vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = h22(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
	}
	return vec4(d1, d2 - d1, id);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = wp.xz;
	float rr = length(q - centre.xz);
	float edge = rr + (fbm(q * 0.31) - 0.5) * 9.0 + (vnoise(q * 1.7) - 0.5) * 1.6;
	ALPHA = 1.0 - smoothstep(19.0, 20.5, edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec4 big = vor(q * 0.17);
	vec4 mid = vor(q * 0.55 + 7.0);
	float plate = h21(big.zw);
	float crack = (1.0 - smoothstep(0.0, 0.05, big.y)) + 0.7 * (1.0 - smoothstep(0.0, 0.07, mid.y)) * smoothstep(0.1, 0.5, plate);
	crack = clamp(crack, 0.0, 1.0);
	// glass inside, crust (pale salt fused to a skin) out towards the edge
	float crust = smoothstep(10.5, 18.0, edge);
	vec3 deep = mix(vec3(0.015, 0.05, 0.075), vec3(0.04, 0.11, 0.15), plate);
	deep = mix(deep, vec3(0.05, 0.08, 0.17), h21(mid.zw) * 0.5);
	vec3 skin = mix(vec3(0.36, 0.42, 0.48), vec3(0.58, 0.64, 0.7), fbm(q * 0.8));
	ALBEDO = mix(deep, skin, crust);
	ROUGHNESS = mix(0.045, 0.62, crust) + 0.04 * vnoise(q * 3.0);
	METALLIC = mix(0.25, 0.0, crust);
	SPECULAR = mix(1.0, 0.4, crust);
	// the star lights the cracks from beneath: bright near the centre, dying out
	float lit = exp(-rr * 0.09) * (0.8 + 0.2 * sin(TIME * 1.2 - rr * 0.25));
	vec3 cyan = vec3(0.3, 0.72, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 em = cyan * crack * lit * 0.95 * (1.0 - crust * 0.8);
	em += vec3(0.04, 0.1, 0.2) * fres * (1.0 - crust);
	// glints: small points of the star's light caught in the facets
	vec2 sp = floor(q * 3.2);
	float tw = pow(h21(sp), 36.0) * (0.5 + 0.5 * sin(TIME * 1.8 + h21(sp + 3.0) * 30.0));
	em += vec3(0.7, 0.9, 1.0) * tw * 2.4 * (1.0 - crust);
	EMISSION = em;
}"""

const _GLASS_LIB := """
float h11(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }
float h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
// a few straight fracture sheets: three families of parallel planes, a third of them cracked, thin, flashing when the
// eye runs along them
float sheets(vec3 p, vec3 vw) {
	float acc = 0.0;
	vec3 n0 = normalize(vec3(0.62, 0.31, -0.72));
	vec3 n1 = normalize(vec3(-0.35, 0.81, 0.47));
	vec3 n2 = normalize(vec3(0.21, -0.55, 0.81));
	for (int i = 0; i < 3; i++) {
		vec3 n = i == 0 ? n0 : (i == 1 ? n1 : n2);
		float per = i == 0 ? 5.5 : (i == 1 ? 7.5 : 6.5);
		float t = dot(p, n) / per;
		float id = floor(t);
		float f = abs(fract(t) - 0.5);
		float keep = step(0.66, h11(id + float(i) * 17.0));
		float line = 1.0 - smoothstep(0.0, 0.012, abs(f - 0.0));
		float flash = 0.1 + 0.9 * pow(1.0 - abs(dot(vw, n)), 6.0);
		acc += keep * line * flash;
	}
	return acc;
}
"""

## Dark clear glass. Flat facets each a different value, strong fresnel and a bright reflection of the sky on the
## ones that face it, light rising from the root and fading to the tip, a few straight fracture sheets seen at two
## depths, sharp bright edges, a cold white cast with a faint violet. UV.x: 0 at a root, 1 at a tip.
const _CRYSTAL_FRAG := """
void fragment() {
	float up = UV.x;
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(N, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(V, 0.0)).xyz);
	vec3 q = wp - heart;
	float d = length(q);
	float pulse = 0.88 + 0.12 * sin(TIME * 1.0 - d * 0.15);
	// each flat facet a slightly different value
	float fk = h31(floor(wn * 7.0 + 0.5));
	// tops are fused and rippled: a soft bump on the near-horizontal faces
	if (wn.y > 0.8 && ripple > 0.5) {
		vec3 bump = vec3(cos(wp.x * 4.1 + sin(wp.z * 2.3) * 1.5) * 0.09, 0.0, cos(wp.z * 3.7 + sin(wp.x * 1.9) * 1.5) * 0.09);
		N = normalize(N + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	}
	float s = sheets(q - vw * 0.4, vw) + 0.55 * sheets(q * 0.93 - vw * 1.5 + 3.0, vw);
	float low = exp(-max(wp.y - base_y, 0.0) * 0.12);
	float rise = (pow(1.0 - up, 1.8) * 0.8 + 0.1) * mix(1.0, 0.5 + low, ripple);
	float near = clamp(3.0 / (1.0 + d * 0.05), 0.35, 1.0);
	float lit = rise * pulse * near;
	vec3 cold = mix(vec3(0.7, 0.88, 1.0), vec3(0.8, 0.72, 1.0), fk * 0.6);
	float edge = smoothstep(0.05, 0.4, length(fwidth(N)) * 6.0);
	ALBEDO = vec3(0.01, 0.014, 0.024) * (0.5 + 1.2 * fk);
	ROUGHNESS = 0.05 + 0.1 * fk + 0.14 * ripple;
	SPECULAR = 0.75 - 0.4 * ripple;
	METALLIC = 0.0;
	EMISSION = (cold * s * lit * 0.9 + cold * fres * 0.35 * (0.3 + lit) + cold * edge * 0.3 * (0.25 + lit) + cold * lit * 0.1 * (1.0 - fres) + cold * smoothstep(0.9, 1.0, up) * 0.1) * strength;
}"""

const _CRYSTAL_HEAD := """shader_type spatial;
render_mode cull_back;
uniform vec3 heart = vec3(0.0);
uniform float strength = 1.0;
uniform float base_y = 0.0;
uniform float ripple = 0.0;
varying vec3 wp;
""" + _GLASS_LIB

const CRYSTAL := _CRYSTAL_HEAD + """
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
""" + _CRYSTAL_FRAG

## Pieces of the star's shell adrift: INSTANCE_CUSTOM = (distance, phase, angular speed, height). They turn as they go.
## Dark glass; the fracture faces (alpha) burn.
const ORBIT := """shader_type spatial;
render_mode cull_back;
varying float k;
vec3 spin(vec3 v, float t) {
	float c = cos(t); float s = sin(t);
	v = vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
	float c2 = cos(t * 0.7); float s2 = sin(t * 0.7);
	return vec3(v.x, v.y * c2 - v.z * s2, v.y * s2 + v.z * c2);
}
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float ang = cd.y + TIME * cd.z;
	float sc = 0.7 + 0.8 * fract(cd.y * 7.31);
	float t = TIME * (0.12 + fract(cd.y * 3.1) * 0.25) + cd.y * 9.0;
	vec3 off = vec3(cos(ang) * cd.x, cd.w + 0.35 * sin(TIME * 0.4 + cd.y * 5.0), sin(ang) * cd.x);
	VERTEX = spin(VERTEX * sc, t) + off;
	NORMAL = spin(NORMAL, t);
	k = UV.x;
}
void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = vec3(0.03, 0.035, 0.05);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = vec3(1.1, 1.0, 0.92) * smoothstep(0.4, 0.9, k) * 1.4 + vec3(0.4, 0.6, 0.75) * fres * 0.45;
}"""

## The star: a dark shell cracked along planes (thin white-hot lines and a soft bloom round them, drawn here in object
## space), molten drips below (UV.y = 1), hottest at the root, orange-white fading through red to dark.
## The only thing here well over the bloom threshold.
const HEART := """shader_type spatial;
render_mode cull_back;
varying float k;
varying float warm;
varying vec3 op;
float crack(vec3 p, vec3 n, float d, float w) { return 1.0 - smoothstep(0.0, w, abs(dot(p, normalize(n)) - d)); }
void vertex() {
	op = VERTEX;
	float t = TIME * 0.12;
	float c = cos(t); float s = sin(t);
	VERTEX = vec3(VERTEX.x * c - VERTEX.z * s, VERTEX.y, VERTEX.x * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x * c - NORMAL.z * s, NORMAL.y, NORMAL.x * s + NORMAL.z * c);
	k = UV.x;
	warm = UV.y;
}
void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 0.9);
	vec3 N = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(N, normalize(VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = vec3(0.012, 0.014, 0.02);
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
	vec3 em = vec3(0.25, 0.4, 0.6) * fres * 0.18;
	if (warm > 0.5) {
		vec3 hot = mix(vec3(1.2, 0.3, 0.06), vec3(1.5, 0.95, 0.5), k * k);
		em += hot * smoothstep(0.05, 0.8, k) * (2.2 + 0.4 * pulse);
	} else if (length(op) < 1.75) {
		vec3 p = normalize(op);
		float line = 0.0;
		float glow = 0.0;
		for (int i = 0; i < 12; i++) {
			float fi = float(i);
			vec3 n = normalize(vec3(sin(fi * 2.399 + 0.7), cos(fi * 1.913 + 2.1), sin(fi * 3.17 + 1.3)));
			float d = 0.55 * sin(fi * 5.31 + 0.4);
			float dist = abs(dot(p, n) - d);
			line = max(line, 1.0 - smoothstep(0.0, 0.03, dist));
			glow = max(glow, 1.0 - smoothstep(0.0, 0.4, dist));
		}
		em += vec3(1.3, 1.2, 1.05) * line * (3.2 + 0.8 * pulse) + vec3(1.0, 0.8, 0.6) * glow * glow * 0.75 + vec3(0.7, 0.45, 0.3) * 0.3;
	}
	float far = smoothstep(14.0, 45.0, length(VERTEX));
	em += vec3(1.25, 1.05, 0.85) * far * 1.3;               // from afar the whole star burns: a body of light, not a black lump
	EMISSION = em;
}"""

## A soft additive disc that always faces the eye and thins out when you are close: the star as a point of light.
const HALO := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint = vec3(0.62, 0.8, 1.0);
uniform float amount = 0.7;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 26.0);
	float body = exp(-r * 4.2) * (1.0 - smoothstep(0.7, 1.0, r));
	float streak = exp(-abs(p.x) * 70.0) * exp(-abs(p.y) * 2.6) * 0.8 + exp(-abs(p.y) * 90.0) * exp(-abs(p.x) * 5.0) * 0.5;
	core += streak * (1.0 - smoothstep(0.55, 1.0, r));
	float pulse = 0.9 + 0.1 * sin(TIME * 1.3);
	float dist = length(VERTEX);
	float near = smoothstep(22.0, 80.0, dist);
	ALBEDO = tint * (core * 1.8 + body * 0.55) * pulse * amount;
	ALPHA = clamp((core + body * 0.5) * near, 0.0, 1.0);
}"""
