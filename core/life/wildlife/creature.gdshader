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

#include "res://core/life/wildlife/creature_rig.gdshaderinc"

uniform float warm = 0.0;

void vertex() {
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
	base *= 1.0 - wet * 0.35 * (1.0 - horn);
	ALBEDO = base;
	// r36 horses: a little warm fill so a coat keeps its colour under the moon's blue key
	EMISSION = base * vec3(1.0, 0.62, 0.36) * warm;
	ROUGHNESS = mix(roughness, 0.38, max(horn * 0.8, wet * 0.6));
	SPECULAR = 0.35 + horn * 0.2;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += rim_col * fres * rim_amount * 0.12;
	if (v_eye > 0.5) {
		ALBEDO = vec3(0.02);
		ROUGHNESS = 0.15;
		EMISSION += eye_col * eye_energy * v_blink;
	}
}
