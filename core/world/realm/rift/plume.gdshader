shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
// The rift's breath (core/world/realm/rift/plume.gd): a column of smoke rising out of the lava at the rift's head and
// leaning away downwind. Nested shells of a bent tube; UV.x runs round it (0..1), UV.y up it (0 at the lava .. 1 at
// the top). Billows scroll upward through a domain-warped noise; the silhouette is soft (facing ratio) and every
// shell fades where it meets rock (depth). The moonlit side is a cold grey, the far side near black, and the lava
// lights the column's foot from below: the warmth sits low and fades into the night grade as it climbs.

uniform vec3 smoke_dark : source_color = vec3(0.075, 0.07, 0.085);
uniform vec3 smoke_lit : source_color = vec3(0.36, 0.38, 0.46);
uniform vec3 glow_color : source_color = vec3(1.0, 0.36, 0.11);
uniform float glow_energy = 1.9;
uniform float glow_reach = 0.34;           // how far up the column (UV.y) the lava's light carries
// its own haze (the engine's depth fog drowned a dark column against the night sky): far off it greys into the
// distance colour, but never all the way, so the column stands on the horizon
uniform vec3 haze_color : source_color = vec3(0.16, 0.18, 0.28);
uniform float haze_far = 520.0;
uniform vec3 moon_dir = vec3(0.5, 0.72, -0.5);
uniform float density = 0.8;
uniform float seed = 0.0;
uniform float rise = 0.05;                 // UV.y per second the billows climb
uniform float soft_depth = 5.0;            // metres over which a shell fades into the rock behind it
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 wnrm;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
// value noise that wraps every `per` cells along x (the column's girth)
float wnoise(vec2 p, float per) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, per);
	float x1 = mod(i.x + 1.0, per);
	float a = hash(vec2(x0, i.y));
	float b = hash(vec2(x1, i.y));
	float c = hash(vec2(x0, i.y + 1.0));
	float d = hash(vec2(x1, i.y + 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p, float per) {
	float v = wnoise(p, per) * 0.5;
	v += wnoise(p * 2.0, per * 2.0) * 0.27;
	v += wnoise(p * 4.0, per * 4.0) * 0.14;
	v += wnoise(p * 8.0, per * 8.0) * 0.07;
	return v / 0.98;
}

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// billows bulge the shell out and in as they climb (UV2.x is the ring's radius): a lumpy, moving silhouette
	float t = TIME * rise;
	float b = fbm(vec2(UV.x * 3.0, UV.y * 5.0 - t * 5.0 + seed * 0.7), 3.0);
	VERTEX += NORMAL * (b - 0.45) * UV2.x * 0.55 * smoothstep(0.0, 0.15, UV.y);
}

void fragment() {
	float h = UV.y;
	float t = TIME * rise;
	// billows: big puffs climbing, warped by a slower field so they roll rather than slide
	vec2 q = vec2(UV.x * 4.0, h * 6.5 - t * 6.5 + seed);
	vec2 w = vec2(fbm(q * 0.5 + vec2(seed * 3.1, -t * 2.0), 2.0), fbm(q * 0.5 + vec2(7.7, seed - t * 1.3), 2.0)) - 0.5;
	float n = fbm(q + w * 2.4, 4.0);
	// the same field a little towards the top: its difference shades each puff (lit crown, shadowed belly)
	float n_up = fbm(q + w * 2.4 + vec2(0.0, 0.22), 4.0);
	// thick and whole low, breaking up as it spreads and thins
	float body = mix(0.3, 0.55, smoothstep(0.1, 1.0, h));
	float a = smoothstep(body - 0.12, body + 0.18, n);
	// the silhouette is the puffs' own edge; only the very grazing rim of a shell is let go
	float face = abs(dot(NORMAL, VIEW));
	a *= smoothstep(0.0, 0.3, face + (n - 0.5) * 0.4);
	a *= smoothstep(0.0, 0.04, h) * (1.0 - smoothstep(0.8, 1.0, h));
	// fade where the shell meets the rock or the lava behind it
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = up.z / up.w;
	a *= clamp((VERTEX.z - scene_z) / soft_depth, 0.0, 1.0);
	// shading: the moon's side and the puff's crown lit, the lee and the belly dark, the lava's light from below
	float lit = clamp(dot(wnrm, normalize(moon_dir)) * 0.5 + 0.5, 0.0, 1.0);
	float puff = clamp((n - n_up) * 4.0 + 0.55, 0.0, 1.0);
	vec3 c = mix(smoke_dark, smoke_lit, lit * mix(0.35, 1.0, puff));
	float under = 1.0 - smoothstep(0.0, glow_reach, h);
	c += glow_color * glow_energy * under * under * mix(0.3, 1.0, 1.0 - puff) * (0.5 + 0.5 * n);
	c = mix(c, haze_color, smoothstep(40.0, haze_far, -VERTEX.z) * 0.6);
	ALBEDO = c;
	ALPHA = clamp(a * density, 0.0, 1.0);
}
