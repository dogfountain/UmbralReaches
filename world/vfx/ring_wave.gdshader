shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Expanding shockwave ring on a flat quad (Nova, double jump, ward plant, lance impact).
// progress 0→1 drives radius and fade per instance, so one material serves every ring.

uniform vec3 color : source_color = vec3(1.2, 0.5, 2.6);
uniform float width = 0.08;          // ring thickness as a fraction of the quad radius
uniform float inner_glow = 0.25;     // faint disc filling the ring
instance uniform float progress = 0.0;
instance uniform float energy = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float wob = (h(vec2(floor(a * 9.0), 1.0)) - 0.5) * 0.04 * progress;
	float rad = progress * 0.96 + wob;
	float w = width * (1.0 - progress * 0.5);
	float ring = smoothstep(rad - w, rad, r) * (1.0 - smoothstep(rad, rad + w * 0.35, r));
	float disc = (1.0 - smoothstep(0.0, rad, r)) * inner_glow * (1.0 - progress);
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	vec3 c = color * (ring * 2.2 + disc) * fade * energy;
	ALBEDO = c;
	ALPHA = clamp((ring + disc) * fade, 0.0, 1.0);
}
