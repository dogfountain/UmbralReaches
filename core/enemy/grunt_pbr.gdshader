shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
#include "res://core/vfx/char_look.gdshaderinc"
// Modelled grunts (r30, tools/blender/grunt_*.py; a copy of boss_pbr.gdshader, which stays the
// bosses'). One baked atlas per kind -- albedo, tangent-space
// normal (OpenGL, as Blender bakes it), ORM (ambient occlusion, roughness, metallic) and emission --
// with the same per-instance channels as flesh.gdshader so Enemy.gd drives them unchanged:
//   hit_flash  white-hot pop on damage     glint  eyes and flames flare on a windup
//   dissolve   0..1 death burn-away (alpha scissor, so the depth prepass is kept)

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float emit_energy = 1.35;
uniform float normal_depth = 1.35;
uniform vec3 rim_col : source_color = vec3(0.55, 0.36, 0.22);
uniform float rim_amount = 0.18;
uniform vec3 burn_col : source_color = vec3(2.6, 1.3, 0.3);
// glands, sacs and seams breathe: emission swells and sinks, out of phase from one body to the next
// (pulse_phase is set once per body, so a swarm never pulses in step)
uniform float emit_pulse = 0.0;
uniform float pulse_rate = 2.2;
// glow through a membrane: the thin edge of a glowing part lights, its thick middle stays darker
uniform float membrane = 0.0;

// Family finish (one material language per family): `wet` lacquers the low-roughness parts (the hollowed
// people's slick dead skin, a cold sheen at grazing angles); `dust` lays a matte grey coat on the surfaces
// that face up (the Ossuary dead, grave dust); `heat` warms the baked emission cracks in step with a slow
// flicker (the rift-born). All 0 = the pre-r37 look. Emission stays under the 1.15 HDR threshold.
uniform float wet = 0.0;
uniform float dust = 0.0;
uniform vec3 dust_col : source_color = vec3(0.42, 0.4, 0.36);
uniform float heat = 0.0;

instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;
instance uniform float pulse_phase = 0.0;   // set once per body (GruntModel), so a swarm is out of step

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	vec2 wear = cl_wear_mask(NORMAL, VERTEX, orm.r);   // r36: edges worn, cavities matte
	ALBEDO = cl_wear_albedo(cl_albedo(texture(albedo_tex, UV).rgb, orm.r, opos), wear);   // r35: the shared character finish
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = cl_wear_rough(cl_rough(orm.g, opos), wear);
	SPECULAR = cl_wear_spec(0.5, wear);
	METALLIC = orm.b;
	// baked atlas carries normals: skip procedural cl_bump (was a multi-noise hit on every grunt)
	ALBEDO = mix(ALBEDO, cl_skin_albedo(ALBEDO, opos, 0.7), 0.55 * (1.0 - orm.b));
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = cl_skin_rough(ROUGHNESS, opos);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// family finish: wet sheen on the smooth parts, dust on the up-facing ones
	float smooth_part = (1.0 - smoothstep(0.35, 0.7, ROUGHNESS)) * (1.0 - METALLIC);
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.72, wet * smooth_part);
	SPECULAR += wet * smooth_part * 0.25 * (0.4 + 0.6 * pow(1.0 - ndv, 2.0));
	float up_f = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	float dust_m = dust * smoothstep(0.25, 0.9, up_f) * (0.55 + 0.45 * cl_noise(opos * 31.0)) * smoothstep(0.1, 0.5, orm.r) * (1.0 - METALLIC);
	ALBEDO = mix(ALBEDO, dust_col, dust_m);
	ROUGHNESS = mix(ROUGHNESS, 0.92, dust_m);
	SPECULAR *= 1.0 - dust_m * 0.6;

	float d = cl_noise(opos * 9.0) * 0.7 + cl_noise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);

	float breathe = 1.0 + emit_pulse * sin(TIME * pulse_rate + pulse_phase + opos.y * 3.0);
	float skin_t = mix(1.0, 0.35 + 0.9 * pow(1.0 - ndv, 1.5), membrane);
	EMISSION = texture(emit_tex, UV).rgb * emit_energy * breathe * (1.0 + heat * (cl_noise(opos * 7.0 + vec3(0.0, TIME * 0.8, 0.0)) - 0.5)) * skin_t * (1.0 + glint * 2.5)
		+ cl_rim(NORMAL, VIEW, VIEW_MATRIX)
		+ vec3(1.4, 1.25, 1.2) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}
