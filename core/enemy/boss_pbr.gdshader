shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
// r35: the shared character finish; bosses take more cavity and breakup (their bakes read as clay)
#define CL_CAVITY 0.5
#define CL_BREAKUP 0.2
#define CL_WEAR 1.3
#include "res://core/vfx/char_look.gdshaderinc"
// Modelled bosses (r30, tools/blender/boss_*.py): one baked atlas per boss -- albedo, tangent-space
// normal (OpenGL, as Blender bakes it), ORM (ambient occlusion, roughness, metallic) and emission --
// with the same per-instance channels as flesh.gdshader so Enemy.gd drives them unchanged:
//   hit_flash  white-hot pop on damage     glint  eyes and flames flare on a windup
//   dissolve   0..1 death burn-away (alpha scissor, so the depth prepass is kept)

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float emit_energy = 6.0;
uniform float normal_depth = 1.0;
uniform vec3 rim_col : source_color = vec3(0.55, 0.36, 0.22);
uniform float rim_amount = 0.12;
uniform vec3 burn_col : source_color = vec3(2.6, 1.3, 0.3);

instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	vec2 wear = cl_wear_mask(NORMAL, VERTEX, orm.r);   // r36: edges worn, cavities matte
	ALBEDO = cl_wear_albedo(cl_albedo(texture(albedo_tex, UV).rgb, orm.r, opos), wear);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = cl_wear_rough(cl_rough(orm.g, opos), wear);
	SPECULAR = cl_wear_spec(0.5, wear);
	METALLIC = orm.b;
	// models pass: fine creases over the baked normals, and the baked colour broken up a little more
	NORMAL = cl_bump(NORMAL, VERTEX, cl_skin_height(opos, 0.35), 0.0012);
	ALBEDO = mix(ALBEDO, cl_skin_albedo(ALBEDO, opos, 0.4), 0.5 * (1.0 - orm.b));
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);

	float d = cl_noise(opos * 9.0) * 0.7 + cl_noise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);

	EMISSION = texture(emit_tex, UV).rgb * emit_energy * (1.0 + glint * 2.5)
		+ cl_rim(NORMAL, VIEW, VIEW_MATRIX)
		+ vec3(1.4, 1.25, 1.2) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}
