shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// A boss's surface the way the wanderer's is made: clean modelled geometry wearing a TILING material (the
// wanderer's own twill wool, embroidered band, leather, iron, wood: wanderer_tex.gd), tinted by the vertex
// colour, with glow painted into the mesh (COLOR.a). One material per surface of the model (boss_look.gd).
// The bosses wore one baked atlas each before: every fold, stain and crack was a blurred picture of noise.
//   COLOR.rgb = tint          COLOR.a = 1 - glow (so an unpainted mesh does not shine)          UV = metres

#define CL_LIFT 1.1
#define CL_CAVITY 0.55
#define CL_BREAKUP 0.12
#include "res://core/vfx/char_look.gdshaderinc"
uniform sampler2D tile : source_color, filter_linear_mipmap_anisotropic, repeat_enable;      // a = roughness
uniform sampler2D tile_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// atlas mode: the whole model is one surface; UV2.x picks its layer, and the layer its tile and finish
uniform bool atlas = false;
uniform sampler2DArray tiles : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tiles_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float l_tile[11];
uniform vec2 l_uv[11];
uniform float l_metal[11];
uniform float l_rough[11];
uniform float l_ndepth[11];
uniform float l_sheen[11];
uniform float l_mean[11];
uniform float l_rune[11];
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float tile_mean = 0.0;                // > 0: the tile gives only its WEAVE (luminance about this mean); the colour is the tint's
uniform float rune_glow = 0.0;                // the embroidered band: its alpha is the rune mask, which glows
uniform float normal_depth = 1.0;
uniform float metallic = 0.0;
uniform float rough_k = 1.0;
uniform float sheen = 0.0;                    // cloth: a soft light-driven edge, as the wanderer's wool has
uniform vec3 emit_col : source_color = vec3(1.0, 0.7, 0.35);
uniform float emit_energy = 2.0;
uniform float emit_pulse = 0.0;
uniform float pulse_rate = 2.0;
uniform vec3 rim_col : source_color = vec3(0.5, 0.4, 0.3);
uniform float rim_amount = 0.0;
uniform float skin_dead = 0.55;               // skin: 0 living blotch .. 1 corpse-grey
uniform float grime = 0.32;                   // darker toward the ground: dust and dirt up the hem and the boots
uniform vec3 burn_col : source_color = vec3(2.6, 1.3, 0.3);
instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;
instance uniform float pulse_phase = 0.0;

varying vec3 opos;
varying flat int layer;
varying float ao_v;

void vertex() {
	opos = VERTEX;
	layer = clamp(int(UV2.x), 0, 10);
	ao_v = 1.0 - UV2.y;                       // baked occlusion (boss_build.bake_ao; glTF flips v)
}

void fragment() {
	float mean_k = tile_mean;
	float rune_k = rune_glow;
	vec4 t;
	if (atlas) {
		vec3 uvw = vec3(UV * l_uv[layer], l_tile[layer]);
		t = texture(tiles, uvw);
		mean_k = l_mean[layer];
		rune_k = l_rune[layer];
		METALLIC = l_metal[layer];
		ROUGHNESS = clamp((rune_k > 0.0 ? 0.62 : t.a) * l_rough[layer], 0.04, 1.0);
		NORMAL_MAP = texture(tiles_n, uvw).rgb;
		NORMAL_MAP_DEPTH = l_ndepth[layer];
		RIM = l_sheen[layer];
	} else {
		t = texture(tile, UV * uv_scale);
		METALLIC = metallic;
		ROUGHNESS = clamp((rune_k > 0.0 ? 0.62 : t.a) * rough_k, 0.04, 1.0);
		NORMAL_MAP = texture(tile_n, UV * uv_scale).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
		RIM = sheen;
	}
	vec3 base = t.rgb * COLOR.rgb;
	if (mean_k > 0.0) {
		base = COLOR.rgb * clamp(dot(t.rgb, vec3(0.3, 0.59, 0.11)) / mean_k, 0.45, 1.7);
	}
	// DEPTH (what the baked atlases had and the clean tiles lost): the baked occlusion paints the creases dark,
	// value breaks up over the body, dirt rises from the ground, hard surfaces rub bright on their edges
	float ao = atlas ? clamp(ao_v, 0.0, 1.0) : 1.0;
	bool skin = atlas && layer == 10;
	bool hard = atlas && (layer == 4 || layer == 5 || layer == 6 || layer == 8);
	vec2 w = cl_wear_mask(NORMAL, VERTEX, ao) * (hard ? 1.0 : 0.0);
	w.y = max(w.y, smoothstep(0.75, 0.2, ao));         // every surface: its creases go matte and lose their shine
	if (skin) {
		// skin wears the leather's grain over MakeHuman's own unwrap: its weave in value, its pits in the normal
		base = cl_skin_albedo(base, opos, skin_dead);
		ROUGHNESS = cl_skin_rough(ROUGHNESS, opos);
	}
	base = cl_albedo(base, ao, opos);
	base *= mix(1.0 - grime, 1.0, smoothstep(0.04, 0.75, opos.y));
	base = cl_wear_albedo(base, w);
	ROUGHNESS = cl_wear_rough(ROUGHNESS, w);
	ALBEDO = cl_lift(base);
	SPECULAR = cl_wear_spec(skin ? 0.28 : 0.5, w);
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	if (!FRONT_FACING) {
		ALBEDO *= 0.6;                    // linings: the inside of a cope or a sleeve, a shade darker (the engine turns its normal)
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	RIM_TINT = 0.6;
	float d = cl_noise(opos * 9.0) * 0.7 + cl_noise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);
	float glow = 1.0 - COLOR.a;
	float breathe = 1.0 + emit_pulse * sin(TIME * pulse_rate + pulse_phase + opos.y * 2.0);
	EMISSION = emit_col * (glow * emit_energy + t.a * rune_k) * breathe * (1.0 + glint * 2.5)
		+ cl_accent(NORMAL, VIEW, rim_col, rim_amount) * (1.0 - glint * 0.6)
		+ vec3(1.4, 1.25, 1.2) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}
