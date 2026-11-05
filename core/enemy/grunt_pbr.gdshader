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
uniform float emit_energy = 6.0;
uniform float normal_depth = 1.0;
uniform vec3 rim_col : source_color = vec3(0.55, 0.36, 0.22);
uniform float rim_amount = 0.12;
uniform vec3 burn_col : source_color = vec3(2.6, 1.3, 0.3);
// glands, sacs and seams breathe: emission swells and sinks, out of phase from one body to the next
// (pulse_phase is set once per body, so a swarm never pulses in step)
uniform float emit_pulse = 0.0;
uniform float pulse_rate = 2.2;
// glow through a membrane: the thin edge of a glowing part lights, its thick middle stays darker
uniform float membrane = 0.0;

instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;
instance uniform float pulse_phase = 0.0;   // set once per body (GruntModel), so a swarm is out of step

varying vec3 opos;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = cl_albedo(texture(albedo_tex, UV).rgb, orm.r, opos);   // r35: the shared character finish
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = cl_rough(orm.g, opos);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) * 0.5 + 0.5, 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.0) * rim_amount * up;

	float d = vnoise(opos * 9.0) * 0.7 + vnoise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);

	float breathe = 1.0 + emit_pulse * sin(TIME * pulse_rate + pulse_phase + opos.y * 3.0);
	float skin_t = mix(1.0, 0.35 + 0.9 * pow(1.0 - ndv, 1.5), membrane);
	EMISSION = texture(emit_tex, UV).rgb * emit_energy * breathe * skin_t * (1.0 + glint * 2.5)
		+ cl_rim(NORMAL, VIEW, VIEW_MATRIX)
		+ vec3(1.4, 1.25, 1.2) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}
