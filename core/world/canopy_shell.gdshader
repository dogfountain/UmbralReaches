shader_type spatial;
render_mode cull_back, specular_disabled;
// The far canopy shell (far_detail.gd): vertex colour carries the crown's value; leaf masses are added here in
// world space (two octaves of value noise: lumps a few metres across and a finer grain), as albedo mottling and a
// small normal tilt, so a crown reads as foliage and not as a smooth moulded dome. No texture, no screen reads.

varying vec3 wpos;

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = vn(wpos * vec3(0.55, 0.9, 0.55));
	float b = vn(wpos * 1.7 + 11.0);
	float m = 0.68 + 0.6 * (0.62 * a + 0.38 * b);
	ALBEDO = COLOR.rgb * m;
	vec3 tilt = vec3(a - 0.5, 0.0, b - 0.5) * 0.9;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
