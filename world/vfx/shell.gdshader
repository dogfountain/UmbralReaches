shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
// Expanding energy dome (Nova burst, Lance blast, rift-step arrival). Bright at the silhouette,
// rippled by scrolling noise, fades as it grows.

uniform vec3 color : source_color = vec3(1.2, 0.5, 2.8);
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
	float m = (fres * 1.6 + rip * 0.25 * fres) * fade;
	ALBEDO = color * m;
	ALPHA = clamp(m, 0.0, 1.0);
}
