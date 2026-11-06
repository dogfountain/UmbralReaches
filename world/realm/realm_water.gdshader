shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ambient_light_disabled;
// Hollow Fen pools (core/world/realm/realm_land.gd): black, still, peaty water. Edges fade into the
// mud by water depth (depth texture), slow wind ripples move the highlights.
//
// r35 (lane D): the reflection is ours, not the engine's. The sky radiance cubemap is a soft violet
// blur, and at grazing angles its Schlick fresnel turned whole pools milky white (they read as
// frost, not water). Now ambient_light_disabled drops the engine's ambient and radiance terms for
// this material (cheaper: no cubemap taps), and the water mirrors an analytic night sky along the
// rippled reflection vector instead: deep zenith, a pale horizon band and the vortex's violet glow
// on the side it hangs (a broad lobe plus a tight one the ripples break into a glinting path toward
// it), weighted by a real water fresnel (F0 0.02) with a stylised floor. Lights (the moon,
// lanterns) still glint through the GGX specular. No SSR, no extra texture reads; the ripple hash is
// sin-free. Full-screen bench (3200x2000, paired A/B): -0.67 ms against the old water.
// Stiller (ripple 0.22 -> 0.16): peat pools, not a lake in wind.
// Soft shores: alpha ramps over ~0.25 m of water instead of 6 cm, and the shallows go darker
// (wet peat) before they go clear, so the shore is a dark band rather than a cut line.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 deep_color : source_color = vec3(0.006, 0.009, 0.012);
uniform vec3 shallow_color : source_color = vec3(0.022, 0.026, 0.024);
uniform vec3 sky_zenith = vec3(0.016, 0.03, 0.11);    // night sky straight up, as the water sees it
uniform vec3 sky_horizon = vec3(0.08, 0.12, 0.27);    // the pale band at the horizon (fog-lit haze)
uniform vec3 vortex_tint = vec3(0.26, 0.2, 0.78);     // the vortex's glow on its side of the sky
uniform vec3 vortex_dir = vec3(0.0, 0.35, -1.0);      // = the sky material's vortex_dir
uniform float sky_strength = 0.5;
uniform float vortex_path = 1.4;     // the vortex's glint path broken up by the ripples
uniform float ripple = 0.16;
uniform float fade_depth = 0.35;
uniform float shore_soft = 0.25;     // m of water over which a pool fades in at its shore
// r34 flora: seen from high above (overviews, the map camera) the pools read as holes: fresnel is ~0
// looking straight down and the peat colour is near black. Water always mirrors some sky, and more
// of it with distance; inside the player's 82 m far plane the near look is unchanged but for the floor.
uniform float sky_floor = 0.14;      // share of the reflection kept looking straight down
uniform float far_sky = 0.55;        // extra sky sheen on far water (fades in 70..260 m)

varying vec3 wpos;

// sin-free hash (Hoskins)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return vnoise(p * 0.9 + vec2(t * 0.11, t * 0.05)) * 0.6 + vnoise(p * 2.3 - vec2(t * 0.07, -t * 0.13)) * 0.3 + vnoise(p * 5.1 + vec2(-t * 0.2, t * 0.17)) * 0.1;
}

vec3 night_sky(vec3 r) {
	float up = clamp(r.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon, sky_zenith, sqrt(up));
	float v = max(dot(r, normalize(vortex_dir)), 0.0);
	float v4 = v * v * v * v;
	float v16 = v4 * v4;
	col += vortex_tint * (v4 * 0.15 + v16 * v16 * vortex_path);
	return col;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float e = 0.15;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3(-(hx - h0) / e * ripple, 1.0, -(hz - h0) / e * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float thick = max(VERTEX.z - vp.z, 0.0);     // view-ray length through the water (approx)
	float k = smoothstep(0.0, fade_depth, thick);

	vec3 vw = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(n, vw), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 r = reflect(-vw, n);
	r.y = abs(r.y);                              // a ripple tipping the ray under still sees sky

	float far_k = smoothstep(70.0, 260.0, -VERTEX.z);
	ALBEDO = mix(shallow_color, deep_color, k);
	ALBEDO = mix(ALBEDO, vec3(0.05, 0.07, 0.1), far_k * 0.6);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	float shore = smoothstep(0.0, shore_soft, thick);
	EMISSION = night_sky(r) * sky_strength * mix(sky_floor, 1.0, fres) * mix(0.35, 1.0, shore)
		+ sky_horizon * far_sky * 0.3 * far_k;
	ALPHA = mix(0.0, mix(0.82, 0.97, fres), shore);
}
