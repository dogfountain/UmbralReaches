shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Dark wool albedo. Magic in the 1k emission map. Not silver. Not arcane_robe.
// Hem-only front cover. Never yank upper front verts (that ballooned the chest).
// Never displace the back panel aft (that trailed the whole coat).

uniform vec3 base_color : source_color = vec3(0.055, 0.062, 0.12);
uniform vec3 rim_color : source_color = vec3(0.46, 0.34, 0.27);
uniform vec3 glow_color : source_color = vec3(0.8, 0.5, 0.22);
uniform vec3 glow_hot : source_color = vec3(1.0, 0.6, 0.3);
uniform float glow_energy = 1.45;
uniform float fleck_scale = 8.4;
uniform float drift = 0.22;
uniform float roughness_amt = 0.88;
uniform float anchor_y = 0.28;
uniform float cloth_len = 1.42;
uniform float wave_scale = 1.0;
uniform float leg_push = 1.0;
uniform float use_world_y = 0.0;
instance uniform vec3 cloth_lag = vec3(0.0);
instance uniform float walk_phase = 0.0;
instance uniform float stride = 0.0;
uniform vec2 uv_scale = vec2(2.0, 2.4);
instance uniform vec3 foot_l = vec3(-0.11, -0.95, 0.0);
instance uniform vec3 foot_r = vec3(0.11, -0.95, 0.0);
instance uniform float foot_radius = 0.16;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D magic_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// Generated gear (wanderer_piece.gd): a tint per layer (coat, lining, under-tunic), how much of the
// magic veins show, embroidered runes that glow (trim: albedo alpha = rune mask), roughness from
// the albedo alpha (wool), and dust/wet darkening toward the hem. Defaults = the old look.
uniform vec3 tint : source_color = vec3(1.0);
uniform float magic_amt = 1.0;
uniform float glyph_glow = 0.0;
uniform vec3 glyph_color : source_color = vec3(1.0, 0.6, 0.24);
uniform float alpha_rough = 0.0;
uniform float hem_grime = 0.0;
uniform float magic_scale = 1.0;     // the veins' own tiling relative to the cloth (bigger, calmer < 1)
uniform float rim_amt = 0.62;

varying vec3 lpos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lpos = VERTEX;
	float y = VERTEX.y;
	if (use_world_y > 0.5) {
		y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	}
	float w = clamp((anchor_y - y) / max(cloth_len, 0.001), 0.0, 1.0);
	float w2 = w * w;
	float w3 = w2 * w;
	// Hem mask — cover/drop only live below the knee. Chest stays put.
	float hem = w3 * w;
	vec2 radial = VERTEX.xz / max(length(VERTEX.xz), 1e-4);

	float side_l = 1.0 - smoothstep(-0.02, 0.18, VERTEX.x);
	float side_r = smoothstep(-0.18, 0.02, VERTEX.x);
	float kick_l = max(sin(walk_phase), 0.0);
	float kick_r = max(-sin(walk_phase), 0.0);
	float push = (kick_l * side_l + kick_r * side_r) * stride * leg_push;
	float front = clamp(-radial.y, 0.0, 1.0);
	float back = clamp(radial.y, 0.0, 1.0);

	bool left_leads = foot_l.z <= foot_r.z;
	vec3 lead = left_leads ? foot_l : foot_r;
	float lead_side = left_leads ? side_l : side_r;
	// Plant toe past rest hem (~-0.19). Cap nose length.
	float reach = clamp(-lead.z - 0.12, 0.0, 0.20);

	// Rest ease + lip drop — hem only.
	VERTEX.z -= 0.04 * front * hem * leg_push;
	VERTEX.y -= 0.07 * hem * leg_push;

	// Lead-panel kick — hem only (light; reach does the cover).
	VERTEX.z -= push * 0.14 * front * hem;
	VERTEX.y += push * 0.03 * front * hem;
	VERTEX.x += radial.x * push * 0.02 * hem;

	// Front hem advance to close the plant gap. No mid/chest displacement.
	VERTEX.z -= reach * stride * leg_push * front * hem * (0.7 + 0.3 * lead_side);

	// Back hem life — body-local folds that stay with the torso.
	// Not walk-velocity lag, not a long aft trail — just volume so it isn't a flat sheet.
	float back_hem = back * w3;
	float sway = sin(walk_phase + 1.2) * stride;
	VERTEX.xz += radial * (0.035 + 0.02 * stride) * back_hem * leg_push * wave_scale;
	VERTEX.z += (0.02 + abs(sway) * 0.025) * back_hem * leg_push; // tiny rest depth, capped
	VERTEX.x += sway * 0.03 * back_hem * leg_push;
	VERTEX.y += sin(TIME * 1.6 + VERTEX.x * 6.0) * 0.012 * back_hem * wave_scale;

	// Stop/land only (rig zeros cloth_lag while walking).
	VERTEX.xz += cloth_lag.xz * w2 * wave_scale * 0.3;
	VERTEX.y += cloth_lag.y * w2 * 0.2 * wave_scale;

	float ang = atan(VERTEX.z, VERTEX.x);
	float ripple = sin(ang * 4.5 + TIME * 1.7 + VERTEX.y * 3.5);
	float billow = sin(ang * 1.5 + TIME * 0.7) * 0.6 + sin(ang * 2.6 - TIME * 0.45) * 0.4;
	float flutter = sin(TIME * 2.1 + ang * 3.0) * (0.35 + stride * 0.45);
	// Hem wave — stronger on the back so folds read; front stays tight for cover.
	float wave_amt = mix(0.012, 0.028, back);
	VERTEX.xz += radial * (wave_amt + ripple * 0.01 + billow * 0.014) * w3 * wave_scale;
	VERTEX.y += (flutter * 0.006 + billow * 0.008) * w3 * wave_scale;

	// Soft cover for boots at the FRONT hem only. Never yank the back panel flat
	// against the legs (that erased back volume).
	if (leg_push > 0.01 && stride > 0.05) {
		for (int fi = 0; fi < 2; fi++) {
			vec3 foot = fi == 0 ? foot_l : foot_r;
			float side_w = fi == 0 ? side_l : side_r;
			float band = smoothstep(0.48, 0.03, abs(VERTEX.y - foot.y)) * hem;
			float near = smoothstep(0.40, 0.02, abs(VERTEX.x - foot.x));
			float cw = band * near * max(side_w, 0.35) * front;
			float tip = clamp(foot.z - (foot_radius * 0.5), -0.32, 0.0);
			VERTEX.z -= max(VERTEX.z - tip, 0.0) * cw * 0.7;
			VERTEX.y -= max(VERTEX.y - (foot.y + 0.015), 0.0) * cw * 0.55;
			VERTEX.x += (foot.x - VERTEX.x) * cw * 0.22;
		}
	}
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec2 crawl = vec2(TIME * drift * 0.05, -TIME * drift * 0.12);
	vec4 a4 = texture(albedo_tex, uv);
	vec3 wool = a4.rgb * tint;
	float hem_w = clamp((anchor_y - lpos.y) / max(cloth_len, 0.001), 0.0, 1.0);
	float grime = hem_grime * smoothstep(0.72, 1.0, hem_w) * (0.7 + 0.3 * noise(lpos * 23.0));
	wool = mix(wool, wool * vec3(0.72, 0.68, 0.64) + vec3(0.014, 0.012, 0.01), grime);
	vec3 ntex = texture(normal_tex, uv).rgb;
	vec2 muv = uv * magic_scale;
	vec3 magic_a = texture(magic_tex, muv + crawl).rgb;
	vec3 magic_b = texture(magic_tex, muv * 1.37 + vec2(0.17, 0.41) - crawl * 0.6).rgb;
	vec3 magic = magic_a * 1.05 + magic_b * 0.55;
	float mag = max(magic.r, magic.b);
	float fine = noise(lpos * fleck_scale + vec3(0.0, -TIME * drift * 1.8, 0.0));
	float sparks = step(0.97, fine) * smoothstep(0.35, 0.7, mag);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.6);
	float pulse = 0.82 + 0.18 * sin(TIME * 1.45 + mag * 10.0);
	vec3 g = mix(glow_color, glow_hot, sparks);
	// one nap sample (was three): baked normal map does the weave
	float nap = fine;
	wool *= 0.92 + 0.12 * nap;
	ALBEDO = wool * (0.85 + 0.15 * base_color / vec3(0.055, 0.062, 0.12));
	NORMAL_MAP = ntex;
	NORMAL_MAP_DEPTH = 1.35;
	ROUGHNESS = alpha_rough > 0.5 ? clamp(roughness_amt * mix(0.75, 1.08, a4.a), 0.0, 1.0) : roughness_amt * (0.9 + 0.1 * nap);
	SPECULAR = 0.32 - grime * 0.12;
	METALLIC = 0.0;
	float glyph = alpha_rough > 0.5 ? 0.0 : a4.a;
	EMISSION = g * (mag * 1.35 + sparks * 1.6) * glow_energy * pulse * magic_amt
		+ glyph_color * glyph * glyph_glow * (0.75 + 0.25 * sin(TIME * 1.3 + lpos.x * 9.0))
		+ rim_color * rim * rim_amt;
}
