shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
// r35: the shared character finish (its own creases already darken: a lighter cavity share)
#define CL_CAVITY 0.15
#define CL_LIFT 1.15
#include "res://core/vfx/char_look.gdshaderinc"
// Enemy skin for CreatureMesh bodies. Pale corpse-flesh with dark veins that flow along limbs,
// wet sheen in the folds, bone that reads as bone, glowing eyes/glands, a violet rim so bodies
// separate from the blue night, and three per-instance channels driven by Enemy.gd:
//   hit_flash  white-hot pop on damage     glint  eyes flare on a strike windup
//   dissolve   0..1 death burn-away (alpha scissor, so the depth prepass is kept)

uniform vec3 skin : source_color = vec3(0.62, 0.58, 0.6);
uniform vec3 skin_deep : source_color = vec3(0.24, 0.16, 0.22);   // folds, cavities
uniform vec3 vein : source_color = vec3(0.16, 0.05, 0.12);
uniform vec3 bone_col : source_color = vec3(0.82, 0.78, 0.66);
uniform vec3 rag_col : source_color = vec3(0.1, 0.08, 0.09);
uniform vec3 linen_col : source_color = vec3(0.5, 0.45, 0.37);   // rag + bone channel: bandages, robes
uniform vec3 eye_col : source_color = vec3(1.0, 0.36, 0.12);
uniform float eye_energy = 1.3;
// r30: a low warm back-rim (it was violet emission, a hologram outline the grade then turned blue)
uniform vec3 rim_col : source_color = vec3(0.55, 0.36, 0.22);
// r30: 0 = the old wet sheen everywhere; up to ~0.5 = dry hide, bark, chitin (roughness up, specular down)
uniform float matte = 0.15;
uniform float rim_amount = 0.55;
uniform float vein_amount = 0.45;
uniform float vein_scale = 7.0;
uniform vec3 burn_col : source_color = vec3(1.2, 0.45, 2.2);
// skin detail (core/enemy/skin_tex.gd): tiled over CreatureMesh's metric UVs, one repeat per
// detail_tile metres. Height darkens the creases and roughens the raised skin.
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_height : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_tile = 0.14;
uniform float detail_depth = 1.15;
uniform float crease = 0.72;

instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	float flesh = COLOR.a;
	float rag = UV2.y;
	// veins: ridged noise stretched along the tube (UV.y = metres along)
	vec2 duv = UV / detail_tile;
	float hgt = texture(detail_height, duv).r;
	float n = cl_noise(vec3(UV.x * 40.0, UV.y * vein_scale * 1.6, 0.0) + opos * 5.0);
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float veins = smoothstep(0.93, 0.995, ridge) * vein_amount * flesh * (1.0 - rag);
	float mottle = cl_noise(opos * 11.0);
	vec3 base = mix(skin_deep, skin, smoothstep(0.15, 0.85, mottle * 0.6 + 0.4)) * COLOR.rgb;
	base *= mix(1.0, 0.45 + 0.75 * hgt, crease * (1.0 - rag * 0.5));
	base = mix(base, vein, veins);
	vec3 albedo = mix(bone_col * COLOR.rgb, base, flesh);
	albedo = mix(albedo, mix(linen_col, rag_col, flesh) * COLOR.rgb * mix(0.75, 1.15, hgt), rag);

	albedo = mix(albedo, albedo * (0.7 + 0.45 * hgt), (1.0 - flesh) * 0.6);   // pitted bone
	// models pass: dead skin is not one tone (sallow, bruised), and it creases; rags hang in folds
	albedo = mix(albedo, cl_skin_albedo(albedo, opos, 0.65), flesh * (1.0 - rag) * 0.7);
	// detail maps already bump; one cheap crease only on rag cloth (skin uses the height map)
	if (rag > 0.5) {
		NORMAL = cl_bump(NORMAL, VERTEX, cl_cloth_height(opos), 0.01);
	}
	vec2 wear = cl_wear_mask(NORMAL, VERTEX, mix(0.5, 1.0, hgt));   // r36: edges worn, creases matte
	ALBEDO = cl_wear_albedo(cl_albedo(albedo, mix(0.5, 1.0, hgt), opos), wear);
	ALBEDO = cl_lift(ALBEDO);   // r38: skin, bone and cloth read under moonlight
	NORMAL_MAP = texture(detail_normal, duv).rgb;
	NORMAL_MAP_DEPTH = detail_depth * (1.0 - rag * 0.55);
	ROUGHNESS = cl_wear_rough(cl_skin_rough(clamp(mix(mix(0.28, 0.46, flesh) + matte * 0.9, 0.95, rag) - veins * 0.18 + (hgt - 0.5) * 0.28, 0.05, 1.0), opos), wear);
	SPECULAR = cl_wear_spec(mix(0.62, 0.48, flesh) * (1.0 - rag) * (1.0 - matte * 1.2), wear);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);

	// death: burn away from the noise field, with a hot violet edge
	float d = cl_noise(opos * 9.0) * 0.7 + cl_noise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);

	// (17 Nov) the rims are lit now, not emitted (they glowed grey in the dark: see grunt_pbr.gdshader)
	RIM = 0.45 * (1.0 - rag * 0.6);
	RIM_TINT = 0.55;
	EMISSION = eye_col * UV2.x * eye_energy * (1.0 + glint * 2.5)
		+ cl_accent(NORMAL, VIEW, rim_col, rim_amount) * (1.0 - glint * 0.6) * 0.35
		+ vec3(1.4, 1.25, 1.6) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}
