shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
// Heat shimmer shell around the Ember Lance: refracts the opaque scene behind it.
// Strongest at the silhouette (fresnel), animated by scrolling noise.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 0.012;
uniform vec3 tint : source_color = vec3(1.0, 0.55, 0.25);
uniform float tint_amount = 0.12;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	vec2 o = vec2(n2(UV * 9.0 + TIME * 3.0), n2(UV * 9.0 - TIME * 2.7)) - 0.5;
	vec3 scene = texture(screen_tex, SCREEN_UV + o * strength * (0.4 + fres)).rgb;
	ALBEDO = mix(scene, scene + tint, tint_amount * fres);
}
