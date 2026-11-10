shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
// The Well of Echoes' waterfall (r37 South): a sheet pouring over the rim and down the pit wall.
// UV.y runs from the lip (0) to the pool (1) in `fall_len` metres; UV.x across the sheet. Falling
// streaks (sin-free value noise stretched along the fall, scrolled down at the speed of water),
// brighter at the lip where it is thin and at the foot where it breaks into foam; edges feather out.
// Pale and cold, a little self-lit (0.12) so it reads in the dark without blooming (HDR threshold
// 1.15, the glow budget stays as it is).

uniform vec3 water_color : source_color = vec3(0.30, 0.42, 0.50);
uniform vec3 foam_color : source_color = vec3(0.78, 0.86, 0.9);
uniform float fall_len = 24.0;
uniform float speed = 7.5;
uniform float opacity = 0.62;
uniform float glow = 0.12;

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

void fragment() {
	float m = UV.y * fall_len;                       // metres down the fall
	float t = TIME * speed;
	vec2 p = vec2(UV.x * 7.0, m - t);
	float streak = vnoise(vec2(p.x * 1.0, p.y * 0.35)) * 0.6 + vnoise(vec2(p.x * 2.7 + 3.0, p.y * 0.9 + 11.0)) * 0.4;
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	float thin_top = smoothstep(0.0, 0.05, UV.y);
	float foot = smoothstep(0.84, 1.0, UV.y);
	float foam = clamp(foot * (0.5 + streak) + (1.0 - smoothstep(0.0, 0.06, UV.y)) * 0.6, 0.0, 1.0);
	float body = smoothstep(0.28, 0.75, streak);
	ALBEDO = mix(water_color, foam_color, clamp(foam + body * 0.35, 0.0, 1.0));
	ALPHA = clamp((opacity * (0.55 + 0.6 * body) + foam * 0.35) * edge * thin_top, 0.0, 0.92);
	ROUGHNESS = mix(0.12, 0.7, foam);
	SPECULAR = 0.6;
	EMISSION = ALBEDO * glow * (0.5 + foam);
}
