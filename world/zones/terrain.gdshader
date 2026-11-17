shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Slope-blended terrain: mossy ground on flats, striated rock on cliffs (triplanar).

global uniform float wetness;
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
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

// RGTC / BC5 stores only RG. Reconstruct Z so cavity isn't reading a junk blue channel.
vec3 unpack_n(sampler2D t, vec2 uv) {
	vec2 xy = texture(t, uv).rg * 2.0 - 1.0;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

vec3 triplanar_normal(sampler2D t, float s, vec3 w) {
	vec3 nx = unpack_n(t, wpos.zy * s);
	vec3 ny = unpack_n(t, wpos.xz * s);
	vec3 nz = unpack_n(t, wpos.xy * s);
	nx = vec3(nx.xy + wnrm.zy, abs(nx.z) * wnrm.x);
	ny = vec3(ny.xy + wnrm.xz, abs(ny.z) * wnrm.y);
	nz = vec3(nz.xy + wnrm.xy, abs(nz.z) * wnrm.z);
	return normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(5.0));
	w /= (w.x + w.y + w.z);
	float flatness = smoothstep(slope_lo, slope_hi, wnrm.y);

	vec3 rock = vec3(0.0);
	vec3 rock_n = wnrm;
	if (flatness < 0.999) {
		vec3 rock_x = w.x > 0.01 ? texture(rock_albedo, wpos.zy * rock_scale).rgb : vec3(0.0);
		vec3 rock_y = w.y > 0.01 ? texture(rock_albedo, wpos.xz * rock_scale).rgb : vec3(0.0);
		vec3 rock_z = w.z > 0.01 ? texture(rock_albedo, wpos.xy * rock_scale).rgb : vec3(0.0);
		rock = rock_x * w.x + rock_y * w.y + rock_z * w.z;
		rock_n = triplanar_normal(rock_normal, rock_scale, w);
		if (detail > 0.5) {
			vec3 rock_hi = texture(rock_albedo, wpos.xz * rock_scale * 3.6).rgb;
			rock = mix(rock, rock * rock_hi * 1.45, 0.28);
			rock_n = normalize(mix(rock_n, triplanar_normal(rock_normal, rock_scale * 3.2, w), 0.4));
		}
	}

	vec3 ground = vec3(0.0);
	vec3 gn_ts = vec3(0.0, 0.0, 1.0);
	vec3 ground_n = wnrm;
	if (flatness > 0.001) {
		ground = texture(ground_albedo, wpos.xz * ground_scale).rgb;
		ground = mix(ground, texture(ground_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wpos.xz * ground_scale * 0.37).rgb, 0.35);
		gn_ts = unpack_n(ground_normal, wpos.xz * ground_scale);
		if (detail > 0.5) {
			vec3 grit = texture(ground_albedo, wpos.xz * ground_scale * 3.8).rgb;
			ground = mix(ground, ground * grit * 1.4, 0.22);
			gn_ts = mix(gn_ts, unpack_n(ground_normal, wpos.xz * ground_scale * 3.4), 0.45);
			gn_ts = normalize(gn_ts);
		}
		ground_n = vec3(gn_ts.xy + wnrm.xz, abs(gn_ts.z) * wnrm.y);
		ground_n = normalize(ground_n.xzy);
	}
	ALBEDO = mix(rock, ground, flatness) * tint;

	vec3 n_ws = normalize(mix(rock_n, ground_n, flatness));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_ws, 0.0)).xyz);

	float cavity = 1.0 - smoothstep(0.22, 0.78, gn_ts.z);
	ALBEDO *= (1.0 - cavity * 0.32) * (1.0 - wetness * 0.14);
	float wet = smoothstep(0.72, 0.96, flatness) * (1.0 - cavity);
	ROUGHNESS = mix(mix(0.88, 0.42, wet), 0.22, wetness * 0.7);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION = rim_color * rim_strength * fres;
}
