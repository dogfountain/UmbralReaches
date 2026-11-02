shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Slope-blended terrain: mossy ground on flats, striated rock on cliffs (triplanar).

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ground_scale = 0.11;   // tiles per metre
uniform float rock_scale = 0.05;
uniform float slope_lo = 0.62;       // world normal.y where rock starts
uniform float slope_hi = 0.82;       // world normal.y where it is all ground
uniform vec3 rim_color = vec3(0.45, 0.72, 1.0);
uniform float rim_strength = 0.22;
uniform vec3 tint = vec3(0.62, 0.72, 1.05);   // cooler crushed night ground
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(5.0));
	w /= (w.x + w.y + w.z);
	float flatness = smoothstep(slope_lo, slope_hi, wnrm.y);

	vec3 rock_x = texture(rock_albedo, wpos.zy * rock_scale).rgb;
	vec3 rock_y = texture(rock_albedo, wpos.xz * rock_scale).rgb;
	vec3 rock_z = texture(rock_albedo, wpos.xy * rock_scale).rgb;
	vec3 rock = rock_x * w.x + rock_y * w.y + rock_z * w.z;
	vec3 ground = texture(ground_albedo, wpos.xz * ground_scale).rgb;
	ground = mix(ground, texture(ground_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wpos.xz * ground_scale * 0.37).rgb, 0.35);
	if (detail > 0.5) {
		vec3 rock_hi = texture(rock_albedo, wpos.xz * rock_scale * 3.6).rgb;
		rock = mix(rock, rock * rock_hi * 1.45, 0.28);
		vec3 grit = texture(ground_albedo, wpos.xz * ground_scale * 3.8).rgb;
		ground = mix(ground, ground * grit * 1.4, 0.22);
	}
	ALBEDO = mix(rock, ground, flatness) * tint;

	vec2 side_uv = (abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy) * rock_scale;
	vec3 rn = texture(rock_normal, side_uv).rgb;
	vec3 gn = texture(ground_normal, wpos.xz * ground_scale).rgb;
	if (detail > 0.5) {
		rn = mix(rn, texture(rock_normal, side_uv * 3.2).rgb, 0.4);
		gn = mix(gn, texture(ground_normal, wpos.xz * ground_scale * 3.4).rgb, 0.45);
	}
	NORMAL_MAP = mix(rn, gn, flatness);
	NORMAL_MAP_DEPTH = 2.35;

	float cavity = 1.0 - smoothstep(0.22, 0.78, NORMAL_MAP.b);
	ALBEDO *= 1.0 - cavity * 0.32;
	float wet = smoothstep(0.72, 0.96, flatness) * (1.0 - cavity);
	ROUGHNESS = mix(0.88, 0.42, wet);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION = rim_color * rim_strength * fres;
}
