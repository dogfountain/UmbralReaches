extends RefCounted
## The Star-Fall Crater's surfaces, all procedural: the fused glass ground (cracks lit from the star, plates of
## slightly different tint, the star mirrored in it, a ragged edge where it gives out to salt), the quartz (milky and
## lit from within at the root, clear and deep towards the point, every facet its own value, the star and the moon
## caught in the facets), the star itself (a white-gold gem, turning, its facets shimmering), its threads, corona and
## rays, and the halo that makes it a point of light from far off. Everything moves in the shaders: no per-frame
## script.
## Nothing here takes the lights' direct specular (specular_disabled): a lantern or the star's own light on a
## mirror-flat facet near the eye is a blown-out white blob, so every highlight is drawn here, from the star and
## the moon, at a size that stays a glint.

const GLASS := """shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec3 centre = vec3(0.0);
uniform vec3 heart = vec3(0.0);
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
	ROUGHNESS = mix(0.08, 0.62, crust) + 0.04 * vnoise(q * 3.0);
	METALLIC = 0.0;
	SPECULAR = mix(0.6, 0.3, crust);
	// the star lights the cracks from beneath: bright near the centre, dying out
	float lit = exp(-rr * 0.09) * (0.8 + 0.2 * sin(TIME * 1.2 - rr * 0.25));
	vec3 cyan = vec3(0.3, 0.72, 1.0);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(wn, vw), 0.0, 1.0), 4.0);
	vec3 em = cyan * crack * lit * 0.95 * (1.0 - crust * 0.8);
	em += vec3(0.04, 0.1, 0.2) * fres * (1.0 - crust);
	// the star mirrored in the glass, each plate tilted a hair so the image breaks at the cracks
	vec2 tilt = (h22(big.zw) - 0.5) * 0.05;
	vec3 pn = normalize(wn + vec3(tilt.x, 0.0, tilt.y));
	vec3 R = reflect(-vw, pn);
	float sr = max(dot(R, normalize(heart - wp)), 0.0);
	em += vec3(1.0, 0.86, 0.66) * (pow(sr, 900.0) * 2.4 + pow(sr, 40.0) * 0.16) * (1.0 - crust) * (1.0 - crack);
	// glints: small points of the star's light caught in the facets
	vec2 sp = floor(q * 3.2);
	vec2 so = fract(q * 3.2) - 0.5 - (h22(sp + 5.0) - 0.5) * 0.6;
	float dotm = 1.0 - smoothstep(0.02, 0.07, length(so));
	float tw = step(0.93, h21(sp)) * dotm * (0.5 + 0.5 * sin(TIME * 1.8 + h21(sp + 3.0) * 30.0));
	em += vec3(0.7, 0.9, 1.0) * tw * 2.4 * (1.0 - crust);
	EMISSION = em;
}"""

## Quartz. UV.x: 0 at a crystal's root, 1 at its point. UV.y: the face's kind (0 a crystal face, 0.5 the fused
## glass skirt round a root, 1 a fracture: a snapped top or a walking top). UV2.x: the crystal's own random number;
## UV2.y: 1 at the middle of a face, 0 on its edges.
## Milky and lit from within at the root, clear and deep to the point; a thick face is darkest in its middle and
## brightens to its edges, where the faces meet in a fine line of light; every facet its own value, the facets that
## face the star lit by it, the star and the moon caught as glints; fractures frosted, walking tops rippled glass
## with the star shimmering in them.
const CRYSTAL := """shader_type spatial;
render_mode cull_back, specular_disabled;
uniform vec3 heart = vec3(0.0);
uniform vec3 moon = vec3(0.3, 0.75, 0.4);
uniform float strength = 1.0;
uniform float ripple = 0.0;
uniform float edge_field = 1.0;           // 0 on the far meshes (their LODs fold the fan points away)
varying vec3 wp;
varying float cr;
float h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cr = UV2.x;
}
void fragment() {
	float up = clamp(UV.x, 0.0, 1.0);
	float kind = UV.y;
	float e = mix(0.55, UV2.y, edge_field);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fk = h31(floor(wn * 6.0 + 0.5) + cr * 13.0);
	float dist = length(VERTEX);
	// walking tops are fused and rippled
	if (ripple > 0.5 && wn.y > 0.75) {
		vec3 bump = vec3(cos(wp.x * 3.1 + sin(wp.z * 1.7) * 1.6), 0.0, cos(wp.z * 2.9 + sin(wp.x * 1.3) * 1.6)) * 0.18;
		wn = normalize(wn + bump);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	float ndv = clamp(dot(wn, vw), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec3 tl = heart - wp;
	float d = length(tl);
	vec3 L = tl / max(d, 0.001);
	float reach = 1.0 / (1.0 + d * d * 0.003);
	float pulse = 0.9 + 0.1 * sin(TIME * 0.9 - d * 0.12);
	vec3 milk = mix(vec3(0.58, 0.86, 1.0), vec3(0.82, 0.7, 1.0), cr);
	vec3 tint = mix(vec3(0.16, 0.48, 1.0), vec3(0.5, 0.26, 1.0), cr);
	vec3 deep = tint * 0.2;
	float m = 1.0 - smoothstep(0.0, 0.38, up);
	m *= m * mix(1.0, 0.55, ripple);
	float core = smoothstep(0.02, 0.4, e);
	float px = max(fwidth(e), 1e-4);
	// a fine line where faces meet: a pixel or two wide, gone with distance and on a face seen edge-on (where the
	// whole face would fall inside two pixels of its edge)
	float line = (1.0 - smoothstep(px * 0.7, px * 2.0, e)) * (1.0 - smoothstep(14.0, 45.0, dist)) * (1.0 - smoothstep(0.03, 0.1, px));
	float band = 1.0 - smoothstep(0.0, 0.22, e);
	float lam = max(dot(wn, L), 0.0);
	vec3 R = reflect(-vw, wn);
	float gs = max(dot(R, L), 0.0);
	float gm = max(dot(R, normalize(moon)), 0.0);
	// (AgX lifts the low end a long way: 0.03 already reads as a mid blue, so the clear glass sits near 0.01 and
	// only the root, the edges and the glints climb towards 1)
	// the body lit from within: the crystal's own colour, every facet its own value, darkest in the thick middle
	// of a face (AgX lifts the low end a long way: 0.05 already reads as a clear mid blue)
	vec3 em = tint * (0.045 + 0.07 * fk) * mix(1.45, 0.55, smoothstep(0.0, 0.9, e)) * mix(0.85, 1.4, fres) * mix(1.0, 1.9, (1.0 - up) * (1.0 - up));
	em += milk * (m * (0.3 + 0.25 * fk) * mix(0.8, 1.15, core) + 0.006 * mix(1.0, 0.6, core));
	em += milk * (band * (0.02 + 0.1 * m) + line * (0.2 + 0.35 * fk)) * (0.6 + 0.4 * (1.0 - up));
	em += milk * fres * 0.025;
	em += vec3(1.0, 0.86, 0.66) * lam * reach * (0.025 + 0.07 * fk);
	// the star in a facet: the facet warms as it turns to it (its mirrored image, the star being close and large,
	// was a soft white blob on the glass); the moon, far and small, is a crisp image with a little sheen
	em += vec3(1.0, 0.86, 0.66) * pow(gs, 24.0) * reach * 0.07;
	em += vec3(0.7, 0.78, 1.0) * (pow(gm, 2400.0) * 2.0 + pow(gm, 160.0) * 0.08);
	// from afar the facets merge: the cluster reads as luminous glass, not black
	float far = smoothstep(18.0, 60.0, dist);
	em += far * (tint * (0.04 + 0.05 * fk) + milk * m * 0.12);
	em += milk * smoothstep(0.88, 1.0, up) * 0.14;
	if (kind > 0.75) {
		// a fracture: glass gone frosted at its broken face; a walking top is dark fused glass with flow lines frozen
		// in it, the star's image broken up in its ripples
		em = deep * (0.12 + 0.14 * fk) + milk * (0.012 + 0.016 * fk + 0.3 * m) * mix(1.0, 0.7, core) + milk * band * 0.025;
		em += vec3(1.0, 0.86, 0.66) * (lam * reach * 0.015 + pow(gs, 10.0) * reach * 0.06);
		if (ripple > 0.5) {
			// fused glass: dark bands where it flowed and set, paler ones between, a few cracks lit cold from inside
			float flow = sin((wp.x * 0.8 + wp.z * 0.6) * 4.0 + 1.8 * sin(wp.z * 1.1) + 1.5 * sin(wp.x * 0.7));
			float band = smoothstep(-0.2, 0.9, flow);
			em = mix(em * 0.55, em * 1.25 + milk * 0.025, band);
			em += milk * smoothstep(0.86, 1.0, flow) * 0.06;
			// a crack or two: the borders between a few big cells, only those of the cells picked to have split
			vec2 cq = wp.xz * 0.32 + 3.1;
			vec2 ci = floor(cq);
			float d1 = 9.0; float d2 = 9.0; vec2 id1 = vec2(0.0); vec2 id2 = vec2(0.0);
			for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
				vec2 g = vec2(float(x), float(y));
				vec2 o = fract(sin(vec2(dot(ci + g, vec2(127.1, 311.7)), dot(ci + g, vec2(269.5, 183.3)))) * 43758.5453);
				float dd = length(g + o - fract(cq));
				if (dd < d1) { d2 = d1; id2 = id1; d1 = dd; id1 = ci + g; } else if (dd < d2) { d2 = dd; id2 = ci + g; }
			}
			float pick = fract(sin(dot(id1 + id2, vec2(41.3, 17.9))) * 43758.5453);
			float crack = (1.0 - smoothstep(0.0, 0.012, d2 - d1)) * step(0.62, pick);
			float halo = (1.0 - smoothstep(0.0, 0.06, d2 - d1)) * step(0.62, pick);
			em = mix(em, vec3(0.4, 0.62, 1.0) * 0.7, crack * 0.8) + vec3(0.04, 0.07, 0.14) * halo;
		}
	} else if (kind > 0.25) {
		// the fused skirt round a root: dark glass, the root's light bleeding into it
		em = deep * (0.15 + 0.15 * fk) + milk * pow(1.0 - up, 2.5) * 0.28 + vec3(1.0, 0.9, 0.75) * pow(gs, 24.0) * reach * 0.07;
	}
	ALBEDO = deep * 0.3;
	ROUGHNESS = 0.2;
	// the sky in the facets, faint; a walking top keeps a little of it in its ripples (its form)
	SPECULAR = kind > 0.75 ? (ripple > 0.5 ? 0.18 : 0.02) : 0.12;
	if (kind > 0.75 && ripple > 0.5) {
		ALBEDO = deep * 0.12;
		ROUGHNESS = 0.14;
	}
	EMISSION = em * pulse * strength;
}"""

## The star: a dense core of many small facets (UV2.y: 1 in the middle of a facet, 0 at its edges; UV2.x: the
## facet's own random number), hot white-gold in the middle of each and violet-blue where they meet, violet at the
## limb; every facet shimmers on its own slow beat and the whole star breathes. It turns slowly. Close to, it is
## dimmed so the facets read; from afar the halo carries the glow.
const HEART := """shader_type spatial;
render_mode cull_back, specular_disabled;
varying float fr;
void vertex() {
	float t = TIME * 0.1;
	float c = cos(t); float s = sin(t);
	VERTEX = vec3(VERTEX.x * c - VERTEX.z * s, VERTEX.y, VERTEX.x * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x * c - NORMAL.z * s, NORMAL.y, NORMAL.x * s + NORMAL.z * c);
	fr = UV2.x;
}
void fragment() {
	float breathe = 0.5 + 0.5 * sin(TIME * 0.7);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float shimmer = 0.5 + 0.5 * sin(TIME * (0.5 + 1.1 * fr) + fr * 61.0);
	shimmer = shimmer * shimmer;
	float near = mix(0.6, 1.0, smoothstep(8.0, 40.0, length(VERTEX)));
	ALBEDO = vec3(0.02, 0.018, 0.016);
	ROUGHNESS = 0.4;
	SPECULAR = 0.2;
	float mid = smoothstep(0.0, 0.14, UV2.y);
	vec3 white = mix(vec3(2.1, 1.55, 0.85), vec3(4.8, 4.4, 3.7), fr * fr) * (0.72 + 0.5 * shimmer);
	vec3 c = mix(white * vec3(0.45, 0.42, 0.95) + vec3(0.1, 0.05, 0.35), white, mid);
	c *= mix(0.55, 1.0, pow(ndv, 0.8));
	c = mix(c, vec3(0.5, 0.36, 1.7), pow(1.0 - ndv, 1.6) * 0.85);
	EMISSION = c * near * (0.82 + 0.25 * breathe);
}"""

## Threads of molten glass under the star (UV.x: 1 at the root, 0 at the tip): additive light, white-gold at the
## root, fading to nothing down the thread.
const THREAD := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
varying float k;
void vertex() {
	float t = TIME * 0.1;
	float c = cos(t); float s = sin(t);
	VERTEX = vec3(VERTEX.x * c - VERTEX.z * s, VERTEX.y, VERTEX.x * s + VERTEX.z * c);
	k = UV.x;
}
void fragment() {
	float breathe = 0.85 + 0.15 * sin(TIME * 0.7 - (1.0 - k) * 3.0);
	ALBEDO = mix(vec3(1.0, 0.62, 0.3), vec3(1.0, 0.92, 0.75), k) * 1.6 * breathe;
	ALPHA = pow(k, 1.6);
}"""

## The corona: a sphere a little larger than the star, additive, lit only at its rim (fresnel), violet-blue,
## breathing with the star.
const CORONA := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.2);
	float breathe = 0.85 + 0.15 * sin(TIME * 0.7);
	ALBEDO = mix(vec3(0.55, 0.5, 1.0), vec3(0.75, 0.62, 1.0), rim) * 1.3 * breathe;
	ALPHA = rim * (1.0 - smoothstep(0.92, 1.0, 1.0 - ndv) * 0.6);
}"""

## The rays: long thin quads round the star, always facing the eye, turning very slowly (UV.x 0 at the star to 1 at
## the tip, UV.y across; UV2.x the ray's own turn rate, UV2.y its phase). Additive light, gone into the halo by
## 160 m.
const RAYS := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
varying vec2 ray;
void vertex() {
	float a = TIME * UV2.x;
	float c = cos(a); float s = sin(a);
	vec2 v = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX = vec3(v, 0.0);
	ray = UV2;
}
void fragment() {
	float t = UV.x;
	float across = UV.y;
	float flick = 0.7 + 0.3 * sin(TIME * (0.4 + ray.x * 4.0) + ray.y * 6.28);
	float body = pow(1.0 - t, 1.7) * smoothstep(0.0, 0.08, t) * exp(-across * across * 4.0);
	float dist = length(VERTEX);
	ALBEDO = mix(vec3(1.0, 0.82, 0.6), vec3(0.72, 0.62, 1.0), t) * 1.1;
	ALPHA = body * flick * 0.3 * (1.0 - smoothstep(90.0, 160.0, dist));
}"""

## A soft additive disc that always faces the eye and thins out when you are close: the star as a point of light.
const HALO := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint = vec3(1.0, 0.8, 0.58);
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
	// (19 Nov, the visual pass: no cross streak. With the rays it bloomed into a white eight-pointed lens star over every view
	// of the pans, vista_realm_from_se; umbral-donts: no anamorphic streaks. A warm point with a soft body.)
	float pulse = 0.9 + 0.1 * sin(TIME * 0.8);
	float dist = length(VERTEX);
	float near = smoothstep(22.0, 80.0, dist);
	ALBEDO = tint * (core * 1.25 + body * 0.45) * pulse * amount;
	ALPHA = clamp((core + body * 0.5) * near, 0.0, 1.0);
}"""
