shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Deep violet robe threaded with slowly drifting arcane flecks that glow (and bloom).

uniform vec3 base_color : source_color = vec3(0.24, 0.09, 0.58);
uniform vec3 glow_color : source_color = vec3(0.62, 0.30, 1.0);
uniform vec3 glow_hot : source_color = vec3(0.95, 0.40, 1.0);
uniform float glow_energy = 4.5;
uniform float fleck_scale = 6.5;
uniform float drift = 0.12;
uniform vec3 rim_color = vec3(0.7, 0.5, 1.0);
uniform float rim_strength = 0.45;

varying vec3 lpos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	lpos = VERTEX;   // object space, so the pattern travels with the character
}

void fragment() {
	vec3 p = lpos * fleck_scale + vec3(0.0, -TIME * drift, 0.0);
	float n = fbm(p);
	float fine = noise(p * 4.0);
	float flecks = smoothstep(0.55, 0.66, n) * (0.55 + 0.45 * fine);
	float sparks = step(0.93, fine) * smoothstep(0.45, 0.6, n);
	float veins = smoothstep(0.47, 0.5, n) - smoothstep(0.5, 0.53, n);
	ALBEDO = base_color * (0.55 + 0.6 * n);
	ROUGHNESS = 0.85;
	vec3 g = mix(glow_color, glow_hot, smoothstep(0.66, 0.8, n));
	float pulse = 0.75 + 0.25 * sin(TIME * 1.6 + n * 14.0);
	EMISSION = g * (flecks + sparks * 1.5 + veins * 0.25) * glow_energy * pulse
	         + rim_color * rim_strength * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
}
