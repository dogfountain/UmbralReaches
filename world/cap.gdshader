shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Mushroom parts from UV2.x: stem, gills, cap, geometric spots.

uniform vec3 stem_color : source_color = vec3(0.86, 0.78, 0.62);
uniform vec3 gill_color : source_color = vec3(0.72, 0.52, 0.32);
uniform vec3 spot_color : source_color = vec3(0.96, 0.9, 0.72);
uniform float glow = 0.35;
uniform float violet_amount : hint_range(0.0, 1.0) = 0.0;   // pulls red/orange caps toward violet (vale)

varying vec3 wpos;
varying vec4 inst;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst = INSTANCE_CUSTOM;
}

void fragment() {
	float part = UV2.x;
	float is_stem = 1.0 - smoothstep(0.18, 0.32, part);
	float is_gill = smoothstep(0.22, 0.38, part) * (1.0 - smoothstep(0.55, 0.72, part));
	float is_spot = smoothstep(1.05, 1.18, part);
	float is_cap = (1.0 - is_stem - is_gill) * (1.0 - is_spot);
	vec3 cap_col = COLOR.rgb;
	if (length(cap_col) < 0.04) {
		cap_col = vec3(0.72, 0.16, 0.18);
	}
	if (violet_amount > 0.0) {
		float mx = max(cap_col.r, max(cap_col.g, cap_col.b));
		float redness = smoothstep(0.35, 0.8, cap_col.r / max(mx, 1e-4)) * (1.0 - smoothstep(0.3, 0.7, cap_col.b / max(mx, 1e-4)));
		vec3 violet = vec3(0.55, 0.22, 1.0) * max(mx, 0.35);
		cap_col = mix(cap_col, violet, violet_amount * redness);
	}
	vec3 spots = inst.a > 0.001 ? inst.rgb : spot_color;
	float emit = inst.a > 0.001 ? inst.a : glow;
	vec3 alb = stem_color;
	alb = mix(alb, gill_color, is_gill);
	alb = mix(alb, cap_col, is_cap);
	alb = mix(alb, spots, is_spot);
	float grain = 0.9 + 0.1 * sin(wpos.x * 18.0 + wpos.z * 14.0 + wpos.y * 9.0);
	float gill_stripe = 0.82 + 0.18 * sin(UV.x * 48.0);
	ALBEDO = alb * mix(1.0, grain, is_cap) * mix(1.0, gill_stripe, is_gill);
	ROUGHNESS = mix(0.86, 0.32, is_cap);
	ROUGHNESS = mix(ROUGHNESS, 0.62, is_gill);
	float pulse = 0.82 + 0.18 * sin(TIME * 2.4 + wpos.x * 0.7 + wpos.z * 0.4);
	vec3 lit = mix(cap_col, spots, is_spot);
	EMISSION = lit * emit * (0.7 + is_cap * 2.1 + is_gill * 0.35 + is_spot * 0.8) * pulse;
}
