shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// The wanderer's cloth, merged: every wool layer (coat, under-tunic, mantle, two-layer hood, tail,
// sleeves, bell cuffs, linings, embroidered bands) in ONE skinned surface (wanderer_body.gd).
// The same hem wave as robe_wave.gdshader, but the mesh is skinned before vertex() runs, so the
// wave is worked out in the part's own rest space (CUSTOM0.xyz) and turned into the model by the
// chest's rotation (chest_x / chest_y). Madder-wine wool, barely-there gold rune veins, amber-gold embroidered runes (r32 restyle:
// warm, painterly, no neon). Not silver. Not arcane_robe. Hem-only front cover; never yank the chest or trail the back.
//   CUSTOM0 = rest-local position, hem weight     CUSTOM1 = leg push, wave scale, trim, hem grime
//   COLOR   = layer tint x baked occlusion, a = rune-vein amount        UV = pre-scaled

#define CL_RIM 0.0
#include "res://core/vfx/char_look.gdshaderinc"
uniform vec3 rim_color : source_color = vec3(0.46, 0.34, 0.27);
uniform vec3 glow_color : source_color = vec3(0.8, 0.5, 0.22);
uniform vec3 glow_hot : source_color = vec3(1.0, 0.62, 0.32);
uniform vec3 glyph_color : source_color = vec3(1.0, 0.6, 0.24);
uniform float glow_energy = 0.06;
uniform float glyph_glow = 0.75;
uniform float fleck_scale = 8.4;
uniform float drift = 0.22;
uniform float magic_scale = 0.42;
// vein toning: only the bright cores of the veins glow, so the twill reads between them
uniform float vein_lo = 0.25;
uniform float vein_hi = 0.85;
// at game distance the veins glow as they always did (the wanderer's read at 4-10 m); only close up
// (camera nearer than read_near..read_far m) do they thin to their cores so the twill shows
uniform vec3 far_glow : source_color = vec3(0.8, 0.5, 0.22);
uniform vec3 far_hot : source_color = vec3(1.0, 0.6, 0.3);
uniform float far_energy = 0.07;      // 1.45 x 0.72, the old coat's glow x vein amount
uniform float read_near = 1.3;
uniform float read_far = 3.0;
uniform float albedo_gain = 1.3;
uniform float fold_relief = 0.014;     // models pass: the coat's hanging folds (metres)
uniform float weave_cells = 32.0;      // weave repeats across the wool texture (for the shimmer fade)
uniform float sheen = 0.6;           // r36: light-driven fibre sheen (RIM), see fragment()
uniform float sheen_tint = 0.5;
uniform sampler2D wool_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wool_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D magic_tex : source_color, filter_linear_mipmap, repeat_enable;

instance uniform vec3 cloth_lag : instance_index(0) = vec3(0.0);
instance uniform float walk_phase : instance_index(1) = 0.0;
instance uniform float stride : instance_index(2) = 0.0;
instance uniform vec3 foot_l : instance_index(3) = vec3(-0.11, -0.95, 0.0);
instance uniform vec3 foot_r : instance_index(4) = vec3(0.11, -0.95, 0.0);
instance uniform float foot_radius : instance_index(5) = 0.16;
instance uniform vec3 chest_x : instance_index(6) = vec3(1.0, 0.0, 0.0);
instance uniform vec3 chest_y : instance_index(7) = vec3(0.0, 1.0, 0.0);
// knees and hips in the same space as foot_l/foot_r (indices 8-10 are the gear and orb surfaces')
instance uniform vec3 knee_l : instance_index(11) = vec3(-0.11, -0.6, 0.0);
instance uniform vec3 knee_r : instance_index(12) = vec3(0.11, -0.6, 0.0);
instance uniform vec3 hip_l : instance_index(13) = vec3(-0.11, -0.2, 0.0);
instance uniform vec3 hip_r : instance_index(14) = vec3(0.11, -0.2, 0.0);
// r36 riding: the horse's barrel under the saddle, in this space: x half-width, y centre, z half-height,
// w on (0..1). The coat drapes over it instead of passing through the horse.
instance uniform vec4 saddle : instance_index(15) = vec4(0.0);

// instance_index: the body carries three shaders on one instance; each slot must be unique
// The wanderer's violet rim key (it used to be an OmniLight3D on the rig, see CharacterRig
// _add_rim_light): the same light worked out here, on the wanderer only, so it costs no clustered
// light over the ground round him. Rig-space position, colour x energy, range.
uniform vec3 rim_key_pos = vec3(0.5, 2.1, 1.4);
uniform vec3 rim_key_color = vec3(0.92, 0.8, 0.86);
uniform float rim_key_range = 3.0;

vec3 rim_key(vec3 albedo, vec3 n_view, vec3 p_view, mat4 view_m, mat4 model_m) {
	vec3 lp = (view_m * model_m * vec4(rim_key_pos, 1.0)).xyz;
	vec3 l = lp - p_view;
	float d = length(l);
	float a = clamp(1.0 - pow(d / rim_key_range, 4.0), 0.0, 1.0);
	a = a * a * pow(max(d, 0.05), -1.1);               // Godot omni falloff, attenuation 1.1
	return albedo * rim_key_color * max(dot(n_view, l / max(d, 1e-4)), 0.0) * a;
}

varying vec3 lpos;
varying vec4 attr;
varying float hem_w;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// r29: where the front panel may hang at height y, given one leg: never behind the line from the
// hip to a knee that came forward (plus the thigh and a little air), and under the knee it falls
// back toward its own hang. A sprinting stride used to push the thigh straight through the robe.
float drape_z(vec3 hip, vec3 knee, float y) {
	float kz = knee.z - 0.12;
	if (y >= knee.y) {
		float u = clamp((y - knee.y) / max(hip.y - knee.y, 0.05), 0.0, 1.0);
		return mix(kz, hip.z - 0.12, u * u);
	}
	return kz + (knee.y - y) * 0.45;
}

void vertex() {
	vec3 P = CUSTOM0.xyz;
	float w = CUSTOM0.w;
	float leg_push = CUSTOM1.x;
	float wave_scale = CUSTOM1.y;
	lpos = P;
	hem_w = w;
	attr = CUSTOM1;
	vec3 Q = P;
	float w2 = w * w;
	float w3 = w2 * w;
	float hem = w3 * w;
	vec2 radial = P.xz / max(length(P.xz), 1e-4);

	float side_l = 1.0 - smoothstep(-0.02, 0.18, P.x);
	float side_r = smoothstep(-0.18, 0.02, P.x);
	float kick_l = max(sin(walk_phase), 0.0);
	float kick_r = max(-sin(walk_phase), 0.0);
	float push = (kick_l * side_l + kick_r * side_r) * stride * leg_push;
	float front = clamp(-radial.y, 0.0, 1.0);
	float back = clamp(radial.y, 0.0, 1.0);

	bool left_leads = foot_l.z <= foot_r.z;
	vec3 lead = left_leads ? foot_l : foot_r;
	float lead_side = left_leads ? side_l : side_r;
	float reach = clamp(-lead.z - 0.12, 0.0, 0.20);

	// rest ease + lip drop (hem only)
	Q.z -= 0.04 * front * hem * leg_push;
	Q.y -= 0.07 * hem * leg_push;
	// lead-panel kick (hem only)
	Q.z -= push * 0.14 * front * hem;
	Q.y += push * 0.03 * front * hem;
	Q.x += radial.x * push * 0.02 * hem;
	// front hem advance to close the plant gap
	Q.z -= reach * stride * leg_push * front * hem * (0.7 + 0.3 * lead_side);
	// back hem life: body-local volume, never a long aft trail
	float back_hem = back * w3;
	float sway = sin(walk_phase + 1.2) * stride;
	Q.xz += radial * (0.035 + 0.02 * stride) * back_hem * leg_push * wave_scale;
	Q.z += (0.02 + abs(sway) * 0.025) * back_hem * leg_push;
	Q.x += sway * 0.03 * back_hem * leg_push;
	Q.y += sin(TIME * 1.6 + Q.x * 6.0) * 0.012 * back_hem * wave_scale;
	// stop / land only (the rig zeros cloth_lag in a steady stride)
	Q.xz += cloth_lag.xz * w2 * wave_scale * 0.3;
	Q.y += cloth_lag.y * w2 * 0.2 * wave_scale;

	float ang = atan(Q.z, Q.x);
	float ripple = sin(ang * 4.5 + TIME * 1.7 + Q.y * 3.5);
	float billow = sin(ang * 1.5 + TIME * 0.7) * 0.6 + sin(ang * 2.6 - TIME * 0.45) * 0.4;
	float flutter = sin(TIME * 2.1 + ang * 3.0) * (0.35 + stride * 0.45);
	float wave_amt = mix(0.012, 0.028, back);
	Q.xz += radial * (wave_amt + ripple * 0.01 + billow * 0.014) * w3 * wave_scale;
	Q.y += (flutter * 0.006 + billow * 0.008) * w3 * wave_scale;

	// r36 riding: anything of the coat inside the horse's barrel section is pushed out to its surface
	// (a little proud), so the coat lies over the horse's flanks
	if (saddle.w > 0.001) {
		// seated, the skirt is drawn up and spread: what hangs below the barrel's middle is shortened
		// (more toward the hem) and flared over the horse's flanks, not left hanging down past its belly
		float mid = saddle.y - saddle.z * 0.1;
		float below = max(mid - Q.y, 0.0);
		float gather = saddle.w * leg_push * w2;
		Q.y += below * 0.62 * gather;
		Q.x *= 1.0 + 0.5 * gather * smoothstep(0.0, 0.5, below);
		vec2 e = vec2(Q.x / saddle.x, (Q.y - saddle.y) / saddle.z);
		float d = length(e);
		if (d < 1.14) {
			// out to the surface and a little proud, more toward the hem (cloth over a flank stands off it)
			vec2 onto = e / max(d, 1e-3) * (1.08 + 0.08 * hem);
			vec3 R = vec3(onto.x * saddle.x, saddle.y + onto.y * saddle.z, Q.z);
			Q = mix(Q, R, saddle.w);
		}
	}
	// soft cover for the boots, front hem only
	if (leg_push > 0.01 && stride > 0.05) {
		for (int fi = 0; fi < 2; fi++) {
			vec3 foot = fi == 0 ? foot_l : foot_r;
			float side_w = fi == 0 ? side_l : side_r;
			float band = smoothstep(0.48, 0.03, abs(Q.y - foot.y)) * hem;
			float near = smoothstep(0.40, 0.02, abs(Q.x - foot.x));
			float cw = band * near * max(side_w, 0.35) * front;
			float tip = clamp(foot.z - (foot_radius * 0.5), -0.32, 0.0);
			Q.z -= max(Q.z - tip, 0.0) * cw * 0.7;
			Q.y -= max(Q.y - (foot.y + 0.015), 0.0) * cw * 0.55;
			Q.x += (foot.x - Q.x) * cw * 0.22;
		}
	}
	// the front panel drapes over a forward knee (both legs; the lateral falloff keeps it a tent)
	if (leg_push > 0.01) {
		float fw = smoothstep(0.1, 0.6, front);
		for (int li = 0; li < 2; li++) {
			vec3 hp = li == 0 ? hip_l : hip_r;
			vec3 kn = li == 0 ? knee_l : knee_r;
			float wy = smoothstep(hp.y + 0.14, hp.y - 0.02, Q.y);
			float wl = 1.0 - smoothstep(0.07, 0.24, abs(Q.x - kn.x));
			float w = fw * wy * wl;
			if (w > 0.0) {
				float need = drape_z(hp, kn, Q.y);
				Q.z -= max(Q.z - need, 0.0) * w;
			}
		}
	}
	vec3 cz = cross(chest_x, chest_y);
	VERTEX += mat3(chest_x, chest_y, cz) * (Q - P);
}

void fragment() {
	vec2 uv = UV;
	float trim = attr.z;
	// one texture pair per fragment: wool or the embroidered band (explicit gradients, so the
	// branch is safe; it only diverges along a band's edge)
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec4 a4;
	vec3 n;
	if (trim > 0.5) {
		a4 = textureGrad(trim_tex, uv, dx, dy);
		n = textureGrad(trim_n, uv, dx, dy).rgb;
	} else {
		a4 = textureGrad(wool_tex, uv, dx, dy);
		n = textureGrad(wool_n, uv, dx, dy).rgb;
	}
	vec3 col = a4.rgb * COLOR.rgb * albedo_gain;
	float occl = clamp(max(COLOR.r, max(COLOR.g, COLOR.b)), 0.0, 1.0);
	// dust and damp toward the hem, mottled
	if (hem_w > 0.7 && attr.w > 0.0) {
		float grime = attr.w * smoothstep(0.7, 1.0, hem_w) * (0.6 + 0.4 * noise(lpos * 23.0));
		col = mix(col, col * vec3(0.66, 0.62, 0.58) + vec3(0.016, 0.013, 0.01), grime);
	}
	float magic_amt = COLOR.a;
	vec3 veins = vec3(0.0);
	if (magic_amt > 0.0) {
		// rune veins: full at game distance, thinned to their cores close up (the twill reads)
		vec2 crawl = vec2(TIME * drift * 0.05, -TIME * drift * 0.12);
		vec2 muv = uv * magic_scale;
		vec2 mdx = dx * magic_scale;
		vec2 mdy = dy * magic_scale;
		vec3 magic = textureGrad(magic_tex, muv + crawl, mdx, mdy).rgb * 1.05
			+ textureGrad(magic_tex, muv * 1.37 + vec2(0.17, 0.41) - crawl * 0.6, mdx * 1.37, mdy * 1.37).rgb * 0.55;
		float mag = max(magic.r, magic.b);
		float far = smoothstep(read_near, read_far, -VERTEX.z);
		float sparks = mag > 0.45 ? step(0.975, noise(lpos * fleck_scale + vec3(0.0, -TIME * drift * 1.8, 0.0))) * smoothstep(0.45, 0.8, mag) : 0.0;
		float pulse = 0.82 + 0.18 * sin(TIME * 1.45 + mag * 10.0);
		vec3 near_v = mix(glow_color, glow_hot, sparks) * (smoothstep(vein_lo, vein_hi, mag) * 1.35 + sparks * 1.4) * glow_energy;
		vec3 far_v = mix(far_glow, far_hot, sparks) * (smoothstep(vein_lo, vein_hi, mag) * 1.35 + sparks * 1.6) * far_energy;
		veins = mix(near_v, far_v, far) * pulse * magic_amt * mix(0.4 + 0.6 * occl, 1.0, far);
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.6);
	ALBEDO = col;
	// models pass: the coat hangs in folds (object-space, faded by footprint; char_look), and the
	// weave's normal depth fades once a weave cell is under ~2 pixels: it aliased into scanlines
	NORMAL = cl_bump(NORMAL, VERTEX, cl_cloth_height(lpos), fold_relief * (1.0 - trim));
	float fp = max(length(dx), length(dy)) * float(textureSize(wool_tex, 0).x) / weave_cells;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = mix(mix(1.7, 0.35, smoothstep(0.5, 2.0, fp)), 2.2, trim);
	ROUGHNESS = mix(clamp(0.9 * mix(0.75, 1.08, a4.a), 0.0, 1.0), 0.72, trim);
	SPECULAR = mix(0.28, 0.4, trim);
	METALLIC = 0.0;
	// r36 wool sheen: Godot's rim term is lit by the scene's real lights (moon, lanterns, spells),
	// unlike the emissive rim below, so the cloth's grazing edges catch the moon in the open and
	// the lantern beside it -- a fibre sheen that reads the silhouette without glowing in the dark.
	// Half light colour, half the wool's own (the moon's blue edge stays wine, not silver).
	// Godot's own rim falloff is broad at wool roughness (exponent ~1.6): it lit the whole coat and
	// flattened it, so the term is held to the true grazing edge here (the shader's rim, ^2.6).
	RIM = sheen * rim * occl * (1.0 - trim * 0.5);
	RIM_TINT = sheen_tint;
	vec3 glyph = glyph_color * a4.a * glyph_glow * trim * (0.75 + 0.25 * sin(TIME * 1.3 + lpos.x * 9.0));
	EMISSION = veins + glyph + rim_color * rim * mix(0.25, 0.55, step(0.01, magic_amt)) * occl
		+ rim_key(col, NORMAL, VERTEX, VIEW_MATRIX, MODEL_MATRIX) * occl;
}
