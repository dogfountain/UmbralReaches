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

// --- models pass: realism without new textures ---------------------------------------------------
// Fragment-only, object-space, no tangents: a height field from cl_noise turned into a normal with the
// screen-space surface gradient (Mikkelsen 2010), so it works on every mesh (generated or baked).
// Every octave fades out by its own screen footprint (fwidth): no shimmer at 960 rows, and nothing
// is computed past where it would read. Characters cover little of the screen: the cost is small.

// One octave's weight at this pixel: 1 while its cells span several pixels, 0 once sub-pixel.
float cl_fade(vec3 p_scaled) {
	float w = length(fwidth(p_scaled));
	return 1.0 - smoothstep(0.35, 0.9, w);
}

// Perturb view-space normal `n` by height `h` (a scalar the caller built from noise at this pixel),
// `amt` metres-ish of relief. `v` is VERTEX.
vec3 cl_bump(vec3 n, vec3 v, float h, float amt) {
	vec3 sx = dFdx(v);
	vec3 sy = dFdy(v);
	vec3 r1 = cross(sy, n);
	vec3 r2 = cross(n, sx);
	float det = dot(sx, r1);
	float hx = dFdx(h);
	float hy = dFdy(h);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	return normalize(abs(det) * n - grad * amt);
}

// Skin height: soft wrinkles and creases (two octaves) and pores (a third), each faded by footprint.
// `s` scales with the body (1 for a human; larger creatures pass less).
float cl_skin_height(vec3 p, float s) {
	// fine lines that run across the body (a crease is a narrow valley: 1 - |n|) and pores; no
	// coarse octave: at a face's scale anything bigger than a few millimetres reads as lumps
	vec3 b = vec3(p.x * 22.0, p.y * 260.0, p.z * 22.0) * s;   // stretched: lines across, not a crackle net
	vec3 c = p * 320.0 * s;
	float crease = 1.0 - abs(cl_noise(b) - 0.5) * 2.0;
	float h = -pow(crease, 8.0) * 0.0 * cl_fade(b);   // creases off: at 960 rows they read as scanlines (the face sculpt carries the lines)
	h -= cl_noise(c) * 0.4 * cl_fade(c);
	return h;
}

// Skin colour: living skin is never one tone: blotches of warmer blood and cooler, sallow patches,
// darker freckling, a little desaturation; `dead` (0..1) drains it toward grey-green, bruised.
vec3 cl_skin_albedo(vec3 base, vec3 p, float dead) {
	float m1 = cl_noise(p * 7.0);
	float m2 = cl_noise(p * 19.0 + 4.1);
	float fr = cl_noise(p * 95.0 + 1.7);
	vec3 warm = base * vec3(1.08, 0.94, 0.9);
	vec3 cool = base * vec3(0.93, 0.98, 1.0);
	vec3 c = mix(cool, warm, smoothstep(0.3, 0.7, m1));
	c *= 0.9 + 0.2 * m2;
	c *= 1.0 - smoothstep(0.72, 0.9, fr) * 0.18 * cl_fade(p * 95.0);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.88);
	vec3 corpse = mix(vec3(l) * vec3(0.92, 1.0, 0.86), vec3(l) * vec3(0.75, 0.6, 0.72), smoothstep(0.55, 0.8, m2));
	return mix(c, corpse, dead);
}

// Skin roughness: oilier (shinier) in patches, drier elsewhere.
float cl_skin_rough(float r, vec3 p) {
	return clamp(r + (cl_noise(p * 11.0 + 9.0) - 0.5) * 0.22, 0.25, 0.95);
}

// Cloth height: folds hang (long vertically, narrow across) and a few creases where it gathers.
float cl_cloth_height(vec3 p) {
	vec3 a = vec3(p.x * 9.0, p.y * 2.2, p.z * 9.0);
	vec3 b = vec3(p.x * 26.0, p.y * 7.0, p.z * 26.0);
	float h = (cl_noise(a) - 0.5) * cl_fade(a);
	h += (cl_noise(b) - 0.5) * 0.35 * cl_fade(b);
	return h;
}
