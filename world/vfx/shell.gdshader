shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
// Expanding energy dome (Nova burst, Lance blast, rift-step arrival, bolt impact). Bright at the
// silhouette, rippled by scrolling noise, fades as it grows.
// r36: soft where it meets the world. The dome used to cut the ground and walls with a hard line;
// it now fades over the last `soft` metres before the opaque surface behind it, and a thin hot
// contact ring is drawn where it touches -- the blast's true reach on the ground reads at a glance.
// One depth read (the Forward+ prepass depth, no screen copy); no extra pixels drawn.

uniform vec3 color : source_color = vec3(1.2, 0.5, 2.8);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft = 0.45;
uniform float contact = 0.9;
instance uniform float progress = 0.0;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float rip = n2(UV * vec2(24.0, 12.0) + vec2(TIME * 2.0, -TIME * 3.0));
	float fade = (1.0 - progress) * (1.0 - progress);
	// metres between this fragment and the opaque surface behind it (reverse-z, Godot 4.3+)
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).r, 1.0);
	float gap = max(-sv.z / sv.w + VERTEX.z, 0.0);
	float s = smoothstep(0.0, soft, gap);
	float ring = (1.0 - smoothstep(0.0, 0.12, gap)) * contact;
	float m = ((fres * 1.6 + rip * 0.25 * fres) * s + ring * (0.6 + 0.4 * rip)) * fade;
	ALBEDO = color * m;
	ALPHA = clamp(m, 0.0, 1.0);
}
