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

const _CRYSTAL_FRAG := """
void fragment() {
	float up = COLOR.a;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = distance(wp, heart);
	float pulse = 0.82 + 0.18 * sin(TIME * 1.2 - d * 0.18);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float facet = fract(sin(dot(floor(wn * 4.0 + 0.5), vec3(12.9, 78.2, 37.7))) * 43758.5);
	float band = 0.5 + 0.5 * sin(wp.y * 1.7 + facet * 5.0 + wp.x * 0.3);
	float grain = vnoise(vec2(wp.x + wp.z * 0.7, wp.y * 0.8) * 1.6) * 0.65 + vnoise(vec2(wp.x - wp.z, wp.y * 2.4) * 4.0) * 0.35;
	float vein = 1.0 - smoothstep(0.0, 0.03, abs(vnoise(vec2(wp.x * 0.5 + wp.z * 0.4, wp.y * 0.35) * 1.9) - 0.5));
	ALBEDO = COLOR.rgb * (0.3 + 1.1 * facet) * (0.65 + 0.35 * band) * (0.6 + 0.8 * grain);
	ROUGHNESS = 0.3 + 0.3 * facet;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	float near = clamp(3.0 / (1.0 + d * 0.06), 0.45, 1.0);
	float glow = (0.1 + 0.9 * smoothstep(0.25, 1.0, up)) * pulse * near;
	EMISSION = (mix(vec3(0.02, 0.08, 0.2), vec3(0.4, 0.78, 1.05), up * up) * glow * (0.5 + 0.5 * facet) * (0.7 + 0.5 * band) + vec3(0.12, 0.3, 0.7) * fres * 0.35 + vec3(0.12, 0.42, 0.8) * vein * (0.4 + 0.6 * pulse) * (0.3 + 0.7 * near)) * strength;
}"""

const _CRYSTAL_HEAD := """shader_type spatial;
render_mode cull_disabled;
uniform vec3 heart = vec3(0.0);
uniform float strength = 1.0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
"""

const CRYSTAL := _CRYSTAL_HEAD + """
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
""" + _CRYSTAL_FRAG

## The ring of fragments: INSTANCE_CUSTOM = (orbit radius, phase, angular speed, height). They turn as they go.
const ORBIT := _CRYSTAL_HEAD + """
vec3 spin(vec3 v, float t) {
	float c = cos(t); float s = sin(t);
	v = vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
	float c2 = cos(t * 0.7); float s2 = sin(t * 0.7);
	return vec3(v.x, v.y * c2 - v.z * s2, v.y * s2 + v.z * c2);
}
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float ang = cd.y + TIME * cd.z;
	float sc = 0.6 + 0.9 * fract(cd.y * 7.31);
	float t = TIME * (0.3 + fract(cd.y * 3.1) * 0.5) + cd.y * 9.0;
	vec3 off = vec3(cos(ang) * cd.x, cd.w + 0.35 * sin(TIME * 0.5 + cd.y * 5.0), sin(ang) * cd.x);
	VERTEX = spin(VERTEX * sc, t) + off;
	NORMAL = spin(NORMAL, t);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
""" + _CRYSTAL_FRAG

## The star's heart: bright, turning slowly, pulsing. The only thing here that goes over the bloom threshold.
const HEART := """shader_type spatial;
render_mode cull_disabled;
varying float k;
void vertex() {
	float t = TIME * 0.22;
	float c = cos(t); float s = sin(t);
	VERTEX = vec3(VERTEX.x * c - VERTEX.z * s, VERTEX.y, VERTEX.x * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x * c - NORMAL.z * s, NORMAL.y, NORMAL.x * s + NORMAL.z * c);
	k = COLOR.a;
}
void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 1.3);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.35, 0.55, 0.8) * 0.25;
	ROUGHNESS = 0.2;
	float facet = 0.55 + 0.45 * abs(dot(NORMAL, normalize(vec3(0.3, 0.6, 0.75))));
	vec3 core = mix(vec3(0.18, 0.45, 0.85), vec3(1.2, 1.32, 1.5), k * k);
	EMISSION = core * (0.8 + 0.3 * pulse) * facet + vec3(0.3, 0.6, 1.0) * fres * 0.5;
}"""

## A soft additive disc that always faces the eye and thins out when you are close: the star as a point of light.
const HALO := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint = vec3(0.45, 0.72, 1.0);
uniform float amount = 0.55;
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
