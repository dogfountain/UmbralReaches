// r35 character pass (docs/critique/r35_full.md): one finish for every character -- the tavern
// dwarves and villagers (core/npc/dwarf.gdshader), the procedural enemies (core/enemy/flesh.gdshader),
// the modelled enemies (grunt_pbr) and the bosses (boss_pbr). Each was tuned in a different round and
// they read as four games: warm leather, pale plastic, muddy clay. Three shared moves:
//   cavity   the baked occlusion also darkens the albedo itself, a little: painted depth in creases,
//            so forms read under flat night light (Godot's AO only touches ambient)
//   breakup  low-frequency value and roughness variation over the body: no surface is one even tone
//            (the bosses' bakes read as clay, the husk's as plastic)
//   rim      one warm back-rim for everyone, facing up (moonlit edges), the r30 colour
// A shader may set CL_CAVITY, CL_BREAKUP, CL_RIM before including this to tune its own share.

#ifndef CL_CAVITY
#define CL_CAVITY 0.35
#endif
#ifndef CL_BREAKUP
#define CL_BREAKUP 0.12
#endif
#ifndef CL_RIM
#define CL_RIM 0.28
#endif

float cl_hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

float cl_noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cl_hash(i), cl_hash(i + vec3(1, 0, 0)), f.x), mix(cl_hash(i + vec3(0, 1, 0)), cl_hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(cl_hash(i + vec3(0, 0, 1)), cl_hash(i + vec3(1, 0, 1)), f.x), mix(cl_hash(i + vec3(0, 1, 1)), cl_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The body's albedo with painted cavity (ao: 1 open .. 0 deep crease) and breakup over object space.
vec3 cl_albedo(vec3 albedo, float ao, vec3 opos) {
	float n = cl_noise(opos * 6.0) * 0.6 + cl_noise(opos * 17.0) * 0.4;
	albedo *= mix(1.0 - CL_CAVITY, 1.0, clamp(ao, 0.0, 1.0));
	albedo *= 1.0 + (n - 0.5) * 2.0 * CL_BREAKUP;
	return albedo;
}

float cl_rough(float r, vec3 opos) {
	return clamp(r + (cl_noise(opos * 11.0 + 3.7) - 0.5) * CL_BREAKUP * 1.6, 0.05, 1.0);
}

// r36 wear: the surface's own curvature, from the interpolated geometry normal (view space) and
// position. How fast the normal turns per metre of surface, signed: a sphere of radius r gives +1/r,
// a groove -1/r. Screen-space derivatives (one value a 2x2 quad), but a ratio of two derivatives,
// so it does not change with distance or resolution. A handful of ALU, no texture.
float cl_curv(vec3 n, vec3 p) {
	vec3 px = dFdx(p), py = dFdy(p);
	float num = dot(dFdx(n), px) + dot(dFdy(n), py);
	return num / max(dot(px, px) + dot(py, py), 1e-9);
}

// What turns baked clay into a worn, handled surface: convex edges (ridges, knuckles, horn tips,
// plate rims) catch light -- a little lighter and polished smoother; the deep cavities the bake
// knows (AO) stay matte and lose their specular (specular occlusion: Godot's AO only touches
// ambient, so crevices still shone like the open surface). Returns x = edge 0..1, y = cavity 0..1.
#ifndef CL_WEAR
#define CL_WEAR 1.0
#endif
vec2 cl_wear_mask(vec3 n, vec3 p, float ao) {
	float k = cl_curv(n, p);
	float edge = smoothstep(2.0, 12.0, k) * smoothstep(0.35, 0.8, ao);
	float cav = max(smoothstep(-2.0, -12.0, k) * 0.6, smoothstep(0.8, 0.25, ao));
	return vec2(edge, cav) * CL_WEAR;
}
vec3 cl_wear_albedo(vec3 albedo, vec2 w) {
	float l = dot(albedo, vec3(0.299, 0.587, 0.114));
	vec3 worn = mix(albedo, vec3(l), 0.25) * 1.45 + 0.012;   // rubbed: lighter, a touch less saturated
	return mix(albedo, worn, w.x * 0.7) * (1.0 - w.y * 0.2);
}
float cl_wear_rough(float r, vec2 w) {
	return clamp(mix(r, r * 0.68, w.x) + w.y * 0.18, 0.05, 1.0);
}
float cl_wear_spec(float spec, vec2 w) {
	return spec * (1.0 - w.y * 0.75) * (1.0 + w.x * 0.4);
}

// The warm back-rim, only where the surface faces up a little (moonlit edges, not a body in shadow).
vec3 cl_rim(vec3 normal, vec3 view, mat4 view_matrix) {
	float ndv = clamp(dot(normal, view), 0.0, 1.0);
	float up = clamp(dot(normal, (view_matrix * vec4(0.0, 1.0, 0.0, 0.0)).xyz) * 0.5 + 0.5, 0.0, 1.0);
	return vec3(0.55, 0.36, 0.22) * pow(1.0 - ndv, 3.0) * CL_RIM * up;
}
