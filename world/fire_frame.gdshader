shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
// Rising fire along an arch. Colour comes from the zone: ember in the vale, rift-violet on the stair.

uniform vec3 fire_hot : source_color = vec3(1.0, 0.88, 0.45);
uniform vec3 fire_mid : source_color = vec3(1.0, 0.38, 0.08);
uniform vec3 fire_cool : source_color = vec3(0.55, 0.04, 0.02);
uniform float intensity = 1.25;
uniform float rise = 1.6;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.52; }
	return v;
}

void vertex() {
	float lick = sin(UV.x * 16.0 + TIME * 2.2) * 0.03 * UV.y;
	VERTEX += NORMAL * lick;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = UV.x * 8.0 + wpos.y * 0.35;
	float up = UV.y;
	vec2 q = vec2(along, up * 3.4 - TIME * rise);
	float n = fbm(q);
	float n2 = fbm(q * 2.2 + vec2(3.1, TIME * 0.4));
	float body = smoothstep(0.18, 0.55, n) * (1.0 - smoothstep(0.35, 1.0, up));
	float tip = smoothstep(0.45, 0.85, n2) * smoothstep(0.15, 0.55, up) * (1.0 - smoothstep(0.7, 1.02, up));
	float flame = max(body, tip * 0.85);
	flame *= 0.75 + 0.25 * sin(TIME * 11.0 + along * 6.0);
	if (flame < 0.04) {
		discard;
	}
	vec3 col = mix(fire_cool, fire_mid, smoothstep(0.05, 0.45, flame));
	col = mix(col, fire_hot, smoothstep(0.5, 0.95, flame + n2 * 0.2));
	ALBEDO = col * intensity * flame;
	ALPHA = clamp(flame * 1.4, 0.0, 1.0);
}
