// A high fall off the Crowns (vista_places.gd): a ribbon laid down the face, UV.y from the lip (0) to the foot (1)
// over `fall_len` metres, UV.x across. Water in free fall: long streaks stretched along the drop and pulled down at
// the speed of falling water (faster as it falls), dark glassy ribbons between white ones, ragged edges that fray
// into spray lower down, the whole sheet thinning to mist toward the foot. Pale and cold, a little self-lit (glow) so
// it reads against the dark rock at night without blooming (the glow budget stays as it is).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.26, 0.36, 0.46);
uniform vec3 white_color : source_color = vec3(0.8, 0.86, 0.92);
uniform float fall_len = 40.0;
uniform float opacity = 0.7;
uniform float glow = 0.16;

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
	float m = UV.y * fall_len;
	// falling water speeds up: the pattern's phase runs on sqrt(depth) so streaks stretch as they drop
	float fallen = sqrt(max(m, 0.0) * 2.0 / 9.8);
	float t = TIME;
	vec2 p = vec2(UV.x * 9.0, fallen * 3.2 - t * 1.6);
	float streak = vnoise(vec2(p.x, p.y)) * 0.55 + vnoise(vec2(p.x * 2.3 + 4.0, p.y * 1.7 + 9.0)) * 0.3 + vnoise(vec2(p.x * 5.1, p.y * 3.0)) * 0.15;
	float white = smoothstep(0.42, 0.85, streak);
	// the edges fray more as it falls
	float fray = mix(0.1, 0.32, UV.y) + 0.1 * (vnoise(vec2(UV.y * 14.0 - t * 2.0, UV.x * 3.0)) - 0.5);
	float edge = smoothstep(0.0, fray, UV.x) * smoothstep(1.0, 1.0 - fray, UV.x);
	float lip = smoothstep(0.0, 0.03, UV.y);
	float mist = smoothstep(0.55, 1.0, UV.y);
	vec3 c = mix(water_color, white_color, clamp(white * 0.8 + mist * 0.6, 0.0, 1.0));
	ALBEDO = c;
	float a = opacity * (0.45 + 0.55 * white) * edge * lip * (1.0 - 0.75 * mist * (1.0 - white));
	ALPHA = clamp(a * mix(1.0, 0.6, mist), 0.0, 0.9);
	ROUGHNESS = mix(0.15, 0.75, white);
	SPECULAR = 0.55;
	EMISSION = c * glow * (0.55 + 0.6 * white);
}
