shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// A black void in the cowl. The centre stays solid; the rim and the chin break into mist.

varying vec3 obj;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float r = length(obj / vec3(0.10, 0.14, 0.09));
	float n = noise(obj * 7.0 + vec3(0.0, -TIME * 0.28, TIME * 0.05));
	float edge = smoothstep(0.38, 1.08, r + n * 0.52);
	float chin = smoothstep(0.04, -0.13, obj.y + n * 0.03);
	float alpha = (1.0 - edge) * (1.0 - chin * 0.95);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(alpha, 0.0, 0.94);
}
