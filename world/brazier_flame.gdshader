shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Crossed fire card. Always draws from both sides so a glance does not eat the flame.
// Unshaded + additive: the colour is ALBEDO * ALPHA. (Until r29 only EMISSION was written, so
// ALBEDO stayed its default white and every lit brazier showed a soft white sheet.) Hot, pale core
// low and central, orange body, the deep-red tips fading out before they go dim enough for the
// grade to pull them blue; the tongue narrows as it rises.

uniform vec3 fire_hot : source_color = vec3(1.0, 0.82, 0.35);
uniform vec3 fire_mid : source_color = vec3(1.0, 0.32, 0.06);
uniform vec3 fire_cool : source_color = vec3(0.45, 0.04, 0.01);
uniform float intensity = 1.15;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float rise = 1.0 - uv.y;
	float n = noise(vec2(uv.x * 4.2, uv.y * 3.4 - TIME * 2.4));
	n += noise(vec2(uv.x * 8.0 + 2.1, uv.y * 6.0 - TIME * 3.6)) * 0.45;
	// the tongue narrows with height and sways a little with the noise
	float x = abs((uv.x - 0.5 + (n - 0.7) * 0.08 * rise) * 2.0);
	float waist = 1.0 - x / mix(1.0, 0.42, rise);
	float body = smoothstep(0.0, 0.5, waist * (0.6 + n * 0.5));
	body *= smoothstep(0.0, 0.16, rise) * (1.0 - smoothstep(0.4, 0.88, rise + n * 0.22));
	float core = clamp(waist, 0.0, 1.0) * (1.0 - smoothstep(0.15, 0.7, rise + n * 0.15));
	vec3 col = mix(fire_mid, fire_cool, smoothstep(0.5, 1.05, rise + n * 0.15));
	col = mix(col, fire_hot, smoothstep(0.3, 0.85, core));
	ALBEDO = col * intensity;
	ALPHA = clamp(body * 1.3, 0.0, 1.0);
}
