shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
// The staff's orb: a violet shell with a slow inner swirl (two counter-turning bands of light
// round a hot core), worked out in the orb's own space (CUSTOM0) so it turns with the orb.
// orb_boost (instance) brightens it for casts and the lance's charge. Unshaded HDR, one draw.

uniform vec3 shell_color = vec3(0.55, 0.3, 2.0);
uniform vec3 swirl_color = vec3(0.8, 0.5, 2.6);
uniform vec3 core_color = vec3(1.0, 0.75, 3.0);
instance uniform float orb_boost : instance_index(10) = 0.0;

varying vec3 op;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	op = CUSTOM0.xyz / 0.07;
}

void fragment() {
	vec3 p = normalize(op);
	float t = TIME;
	float ang = atan(p.z, p.x);
	// two swirl bands: the angle twisted by height, turning opposite ways
	float s1 = sin(ang * 2.0 + p.y * 5.0 - t * 1.6 + 2.0 * noise(p * 3.0 + vec3(0.0, t * 0.4, 0.0)));
	float s2 = sin(ang * 3.0 - p.y * 4.0 + t * 1.1);
	float swirl = smoothstep(0.35, 1.0, s1) * 0.8 + smoothstep(0.55, 1.0, s2) * 0.5;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float depth = pow(ndv, 2.5);                       // the centre looks into the hot core
	float fres = pow(1.0 - ndv, 2.0);
	vec3 c = shell_color * (0.55 + 0.45 * fres) + swirl_color * swirl * (0.6 + 0.4 * depth) + core_color * depth * 0.45;
	c *= 0.9 + 0.1 * sin(t * 3.1) + orb_boost;
	ALBEDO = c;
}
