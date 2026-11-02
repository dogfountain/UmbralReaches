shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Aim circle for a charged AoE (Ember Lance): the exact blast radius at the predicted impact.
// Rim, rotating ticks, inward chevrons and a faint fill; white-hot at full charge. Clipped round.

uniform vec3 color : source_color = vec3(2.4, 0.8, 0.25);
uniform vec3 full : source_color = vec3(3.0, 2.6, 2.0);
instance uniform float charge = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x) + PI;
	float rim = smoothstep(0.93, 0.965, r) * (1.0 - smoothstep(0.985, 1.0, r));
	float ticks = step(abs(fract((a + TIME * 0.8) / TAU * 16.0) - 0.5), 0.12) * step(0.84, r) * step(r, 0.9);
	float sweep = fract((a - TIME * 2.5) / TAU);
	float chase = smoothstep(0.75, 1.0, sweep) * step(0.88, r) * step(r, 0.93);
	float fill = (1.0 - r) * 0.12 + smoothstep(0.6, 1.0, r) * 0.08;
	float core = (1.0 - smoothstep(0.0, 0.06, r)) * 0.8;
	float pulse = 0.8 + 0.2 * sin(TIME * (6.0 + charge * 10.0));
	vec3 c = mix(color, full, step(0.99, charge));
	float m = (rim * 1.3 + ticks * 0.9 + chase * 1.2 + fill + core) * pulse * (0.45 + 0.55 * charge);
	ALBEDO = c * m;
	ALPHA = clamp(m, 0.0, 1.0);
}
