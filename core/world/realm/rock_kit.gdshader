shader_type spatial;
// RockKit rock surface (core/world/realm/rock_kit.gd). World-space triplanar, so any mesh works
// (no UVs needed) and instances never show the same patch twice. Vertex colour (white = neutral,
// so meshes without colours are fine):
//   COLOR.r  cavity / contact AO (1 open, 0 deep crevice or buried foot)
//   COLOR.g  1 - extra moss (RockKit grows moss caps on up faces; the shader also adds world-up moss)
//   COLOR.b  1 - ember region (ash style: where the crack texture may glow)
// Night palette: cold blue-grey stone under moonlight. Emission is capped (glow budget: HDR
// threshold 1.15, so an ember crack peaks just over it and nothing else glows).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;   // r crack, g lichen, b macro tone
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 tint : source_color = vec3(0.55, 0.6, 0.72);
uniform vec3 tint_alt : source_color = vec3(0.46, 0.5, 0.6);   // macro variation partner
uniform float tex_scale = 0.32;          // texture repeats per metre
uniform float detail_scale = 2.2;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.15;
uniform float detail_strength : hint_range(0.0, 2.0) = 0.35;
uniform float sharpness = 5.0;
uniform float rough_base : hint_range(0.0, 1.0) = 0.86;
uniform float specular_amt : hint_range(0.0, 1.0) = 0.38;
uniform float cavity_strength : hint_range(0.0, 1.0) = 0.75;

uniform float lichen : hint_range(0.0, 1.0) = 0.3;
uniform vec3 lichen_tint : source_color = vec3(0.5, 0.56, 0.5);
uniform float moss_amount : hint_range(0.0, 1.5) = 0.0;   // world-up moss
uniform float moss_bias = 0.0;                            // + = moss reaches further down the sides
uniform vec3 moss_tint : source_color = vec3(0.42, 0.62, 0.42);
uniform float moss_scale = 0.45;

uniform float ember : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember_color : source_color = vec3(0.78, 0.17, 0.035);   // r37: dull ember red (was 1.0, 0.34, 0.07), geology not neon
uniform float ember_energy = 0.5;     // r37 (was 0.95): a banked glow, peak ~0.4 per channel
uniform float soot : hint_range(0.0, 1.0) = 0.0;          // ash: darkened, glassy-black near cracks

uniform float rim_amount : hint_range(0.0, 1.0) = 0.3;
uniform float rim_tint_amt : hint_range(0.0, 1.0) = 0.3;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(sharpness));
	return w / max(w.x + w.y + w.z, 1e-4);
}

// a macro, not a function: the samplers differ in hints (colour / roughness / mask)
#define TRI(t, p, w) (texture(t, (p).zy) * (w).x + texture(t, (p).xz) * (w).y + texture(t, (p).xy) * (w).z)

vec3 unpack_n(vec2 c, float strength) {
	vec2 xy = c * 2.0 - 1.0;
	return vec3(xy * strength, sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0)));
}

// Whiteout-blended triplanar normal map, returned in world space.
vec3 tri_normal(sampler2D t, vec3 p, vec3 n, vec3 w, float strength) {
	// z rebuilt from xy: works for RGB and RG-compressed (normal_map import) textures alike
	vec3 tx = unpack_n(texture(t, p.zy).xy, strength);
	vec3 ty = unpack_n(texture(t, p.xz).xy, strength);
	vec3 tz = unpack_n(texture(t, p.xy).xy, strength);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = tri_w(n);
	vec3 p = wpos * tex_scale;
	vec3 alb = TRI(albedo_tex, p, w).rgb;
	float rgh = TRI(rough_tex, p, w).r;
	vec4 msk = TRI(mask_tex, p, w);
	float macro = TRI(mask_tex, wpos * tex_scale * 0.13, w).b;

	vec3 col = alb * mix(tint_alt, tint, smoothstep(0.3, 0.7, macro)) * 1.6;
	col = mix(col, lichen_tint * (0.55 + alb.g * 0.6), smoothstep(0.55, 0.85, msk.g) * lichen);

	vec3 nw = tri_normal(normal_tex, p, n, w, normal_strength);
	nw = tri_normal(detail_normal, wpos * detail_scale, nw, w, detail_strength);

	float cav = mix(1.0, COLOR.r, cavity_strength);

	// moss: world-up faces (noise-broken edge) plus the mesh's own moss caps
	float mn = texture(moss_tex, wpos.xz * moss_scale * 0.37).g;
	float up = n.y + moss_bias + (mn - 0.45) * 0.7 + (msk.b - 0.5) * 0.3;
	float moss = smoothstep(0.42, 0.72, up) * moss_amount;
	moss = clamp(max(moss, (1.0 - COLOR.g) * min(moss_amount + 0.5, 1.0)), 0.0, 1.0);
	vec3 mt = texture(moss_tex, wpos.xz * moss_scale).rgb;
	vec3 mcol = mix(vec3(dot(mt, vec3(0.3, 0.5, 0.2))), mt, 0.45) * moss_tint * 1.3;
	col = mix(col, mcol, moss);
	vec3 mnrm = tri_normal(moss_normal, wpos * moss_scale, n, w, 0.8);
	nw = normalize(mix(nw, mnrm, moss * 0.85));

	// ash: soot and ember cracks
	float crack = smoothstep(0.55, 0.95, msk.r);
	// only some cracks are alive: the mesh's ember region, broken up by the macro tone
	float region = (1.0 - COLOR.b) * smoothstep(0.45, 0.75, macro);   // r37: fewer live cracks (was 0.35, 0.6)
	col *= 1.0 - soot * (0.35 + 0.4 * crack);
	float glow = crack * region * ember;
	col = mix(col, vec3(0.03, 0.02, 0.02), glow * 0.8);

	ALBEDO = col * (0.45 + 0.55 * cav);
	AO = cav;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = clamp(rough_base * (0.7 + 0.45 * rgh) + moss * 0.08 - glow * 0.3, 0.0, 1.0);
	SPECULAR = specular_amt * (1.0 - moss * 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	RIM = rim_amount * (1.0 - moss * 0.5);
	RIM_TINT = rim_tint_amt;
	float flick = 0.82 + 0.18 * sin(TIME * 1.3 + wpos.x * 1.7 + wpos.z * 1.1);
	EMISSION = ember_color * ember_energy * glow * glow * flick;   // r37: glow^2 keeps the heat in the crack middles, edges stay dark crust
}
