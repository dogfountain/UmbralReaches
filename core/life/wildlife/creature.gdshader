shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
// Wildlife bodies (core/life/wildlife/life_kit.gd). One MultiMesh per species group; every limb is
// animated here from per-instance custom data, so the CPU writes one transform + one vec4 per
// creature and nothing per bone. Mesh channels (CreatureMesh):
//   UV2.x  part id: 0 body, 1 head (+neck), 2 wing +x, 3 wing -x, 4 leg front +x, 5 leg front -x,
//          6 leg back +x, 7 leg back -x, 8 tail, 9 throat sac (frogs)
//   UV2.y  1 = eye (eyeshine / blink)        COLOR.rgb tint     COLOR.a 0 = horn/beak/hoof
// INSTANCE_CUSTOM: x flight blend (wings fold at 0, flap at 1) or throat pulse, y head yaw,
//                  z gait phase (radians), w head pitch.
// Creatures face -Z, +Y up.
// Perf: one detail sample (+ optional coarse when mottle/fur_bump need it). No vane / fine stacks.

#include "res://core/life/wildlife/creature_rig.gdshaderinc"

uniform float warm = 0.0;
// coat modelling (deer, fox, hare; all 0 = off). body_tone: mesh-space y where the belly is full pale
// (x) and gone (y), and where the back starts to darken (z) and is fullest (w); tone_amt: belly, back;
// mottle: broad dappling in mesh space; vary: per-animal brightness; fur_bump: fur-grain normal wobble;
// rim_lit: a sheen from the scene's lights on grazing edges.
uniform vec4 body_tone = vec4(0.0);
uniform vec2 tone_amt = vec2(0.0);
uniform float mottle = 0.0;
uniform float vary = 0.0;
uniform float fur_bump = 0.0;
uniform float rim_lit = 0.0;

varying vec3 v_local;
varying float v_seed;

void vertex() {
	v_local = VERTEX;
	v_seed = fract(float(INSTANCE_ID) * 0.61803);
	float eye;
	float blink;
	rig_vertex(VERTEX, NORMAL, INSTANCE_CUSTOM, UV2, INSTANCE_ID, TIME, eye, blink);
	v_eye = eye;
	v_blink = blink;
}

void fragment() {
	float d = texture(detail_tex, vec2(UV.x * detail_scale, UV.y * detail_scale / max(streak, 0.1))).r;
	vec3 base = COLOR.rgb * mix(1.0, 0.55 + 0.9 * d, detail);
	float horn = 1.0 - COLOR.a;
	float is_body = step(abs(UV2.x), 0.5);
	float coat = max(mottle, fur_bump);
	float coarse = 0.5;
	if (coat > 0.001) {
		coarse = texture(detail_tex, v_local.xz * 1.7 + v_local.y * vec2(1.1, 0.7)).r;
	}
	// a pale belly and a darker saddle, only on the trunk
	float belly = (1.0 - smoothstep(body_tone.x, body_tone.y, v_local.y)) * tone_amt.x * is_body;
	float back = smoothstep(body_tone.z, body_tone.w, v_local.y) * tone_amt.y * is_body;
	base = mix(base, base * vec3(1.45, 1.3, 1.1) + vec3(0.04, 0.035, 0.025), clamp(belly, 0.0, 1.0));
	base *= 1.0 - 0.5 * clamp(back, 0.0, 1.0);
	base *= 1.0 + mottle * (coarse - 0.5) * 1.4 * (1.0 - horn);
	base *= 1.0 + vary * (v_seed - 0.5) * 1.5 * (1.0 - horn);
	base *= 1.0 - wet * 0.35 * (1.0 - horn);
	base *= 1.0 + (d - 0.5) * 0.28 * detail * (1.0 - horn);
	ALBEDO = base;
	EMISSION = base * vec3(1.0, 0.62, 0.36) * warm;
	ROUGHNESS = mix(roughness, 0.62, max(horn * 0.8, wet * 0.6));
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.85, (1.0 - horn) * d * 0.35);
	SPECULAR = 0.34 - horn * 0.12;
	RIM = rim_lit;
	RIM_TINT = 0.45;
	NORMAL = normalize(NORMAL + vec3((d - 0.5) * 1.2, (coarse - 0.5) * 0.8, 0.0) * fur_bump * (1.0 - horn));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION += rim_col * fres * rim_amount * 0.18;
	if (v_eye > 0.5) {
		ALBEDO = vec3(0.02);
		ROUGHNESS = 0.08;
		SPECULAR = 1.0;
		EMISSION += eye_col * eye_energy * v_blink;
	}
}
