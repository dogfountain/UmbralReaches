shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// The pane inside the stone arch: a slow purple vortex, dim enough to stay under the bloom.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.8;
uniform vec3 vortex_deep = vec3(0.04, 0.015, 0.10);
uniform vec3 vortex_rift = vec3(0.28, 0.10, 0.62);
uniform vec3 vortex_hot = vec3(0.50, 0.38, 0.90);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float spin = ang + 2.2 * log(r + 0.08) - TIME * 0.5;
	vec2 q = vec2(cos(spin), sin(spin)) * r;
	float clouds = fbm(q * 3.2 + 2.0);
	float fil = 1.0 - abs(2.0 * fbm(q * 7.0 - TIME * 0.12) - 1.0);
	float arms = clamp(clouds * 0.7 + fil * fil * 0.35, 0.0, 1.0);
	float pull = smoothstep(0.62, 0.02, r);
	vec3 deep = vortex_deep;
	vec3 rift = vortex_rift;
	vec3 lilac = vortex_hot;
	vec3 vortex = mix(deep, rift, arms);
	vortex = mix(vortex, lilac, pull * arms);
	vec2 ruv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
	ruv += vec2(cos(spin), sin(spin)) * 0.015 * (0.35 + r);
	vec3 refl = texture(screen_tex, clamp(ruv, vec2(0.001), vec2(0.999))).rgb;
	vec3 tinted = refl * mix(vec3(0.72, 0.62, 0.95), vec3(1.0), 0.35);
	vec3 col = mix(tinted, vortex, 0.28 + pull * 0.22);
	ALBEDO = col;
	EMISSION = vortex * (0.22 + pull * 0.16) * intensity;
	ROUGHNESS = 0.06;
	METALLIC = 0.55;
	ALPHA = 0.96;
}
