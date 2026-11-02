shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Crossed fire card. Always draws from both sides so a glance does not eat the flame.

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
	float waist = 1.0 - abs(uv.x * 2.0 - 1.0);
	float n = noise(vec2(uv.x * 4.2, uv.y * 3.4 - TIME * 2.4));
	n += noise(vec2(uv.x * 8.0 + 2.1, uv.y * 6.0 - TIME * 3.6)) * 0.45;
	float body = smoothstep(0.08, 0.42, waist * (0.55 + n * 0.55));
	body *= smoothstep(0.0, 0.18, rise) * smoothstep(1.05, 0.42, rise + n * 0.2);
	vec3 col = mix(fire_cool, fire_mid, smoothstep(0.15, 0.55, rise));
	col = mix(col, fire_hot, smoothstep(0.55, 0.95, rise + n * 0.25) * waist);
	EMISSION = col * body * intensity;
	ALPHA = clamp(body * 1.4, 0.0, 1.0);
}
