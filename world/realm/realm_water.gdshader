shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Hollow Fen pools (core/world/realm/realm_land.gd): black, still, peaty water. Reflection comes
// from the sky radiance plus a fake moonlit-sky fresnel term, so it reads without SSR. Edges fade
// into the mud by water depth (depth texture), slow wind ripples move the highlights.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 deep_color : source_color = vec3(0.006, 0.009, 0.012);
uniform vec3 shallow_color : source_color = vec3(0.03, 0.035, 0.03);
uniform vec3 sky_color = vec3(0.10, 0.15, 0.32);   // moonlit sky seen in the water at grazing angles
uniform float sky_strength = 0.12;
uniform float ripple = 0.22;
uniform float fade_depth = 0.35;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	return vnoise(p * 0.9 + vec2(t * 0.11, t * 0.05)) * 0.6 + vnoise(p * 2.3 - vec2(t * 0.07, -t * 0.13)) * 0.3 + vnoise(p * 5.1 + vec2(-t * 0.2, t * 0.17)) * 0.1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float e = 0.15;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3(-(hx - h0) / e * ripple, 1.0, -(hz - h0) / e * ripple));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float thick = max(VERTEX.z - vp.z, 0.0);     // view-ray length through the water (approx)
	float k = smoothstep(0.0, fade_depth, thick);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow_color, deep_color, k);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	EMISSION = sky_color * sky_strength * fres;
	ALPHA = mix(0.0, mix(0.82, 0.97, fres), smoothstep(0.0, 0.06, thick));
}
