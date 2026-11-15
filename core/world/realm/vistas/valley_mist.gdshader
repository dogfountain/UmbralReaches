// Valley mist (realm_vistas.gd): a sheet laid level over low ground. It shows only where the ground lies below it and
// thickens with the depth of air between the sheet and the ground seen through it, so it pools in the valley floors,
// the meres and the hollows by itself and thins out up their sides, with no hard edge on the land. It drifts in slow
// banks, fades near the eye (walking into it is the weather's job) and at the sheet's border. Unshaded, the colour of
// the moonlit haze; the fog's aerial perspective takes it further into the distance.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 tint = vec3(0.29, 0.34, 0.47);
uniform float density = 0.6;
uniform float depth_m = 3.0;           // metres of air under the sheet for the full density
uniform float scale = 0.022;
uniform float seed = 0.0;
varying vec3 wpos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * n2(p); p = p * 2.07 + 3.1; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	float scene_z = -v.z / v.w;
	float my_z = -VERTEX.z;
	// metres of air behind the sheet along the view, turned to a depth below it by the view's slope
	float behind = max(scene_z - my_z, 0.0);
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	float below = behind * clamp(abs(vdir.y), 0.04, 1.0);
	float thick = smoothstep(0.0, depth_m, below);
	float t = TIME * 0.006;
	vec2 p = wpos.xz * scale + seed;
	float banks = fbm(p + vec2(t, t * 0.6));
	float wisps = fbm(p * 3.1 - vec2(t * 2.2, -t));
	float m = smoothstep(0.36, 0.78, banks) * (0.45 + 0.55 * smoothstep(0.25, 0.75, wisps));
	float a = density * thick * m;
	// grazing views look through more of it
	a *= mix(1.0, 1.6, 1.0 - clamp(abs(vdir.y) * 3.0, 0.0, 1.0));
	a *= smoothstep(8.0, 34.0, my_z);
	vec2 e = min(UV, 1.0 - UV);
	a *= smoothstep(0.0, 0.18, min(e.x, e.y));
	ALBEDO = tint * (0.9 + 0.2 * wisps);
	ALPHA = clamp(a, 0.0, 0.85);
}
