shader_type spatial;
render_mode diffuse_burley, specular_disabled, depth_prepass_alpha, cull_back, shadows_disabled;
// The white hart (phenomena.gd): a stag's body on the shared wildlife rig, pale and half there.
// A cold fresnel glow, mist drifting through the coat, and `fade` (instance) to come and go.

#include "res://core/life/wildlife/creature_rig.gdshaderinc"

uniform vec3 ghost_col : source_color = vec3(0.78, 0.86, 1.0);
uniform float glow = 0.35;
instance uniform float fade = 0.0;

varying vec3 v_wpos;

void vertex() {
	float eye;
	float blink;
	rig_vertex(VERTEX, NORMAL, INSTANCE_CUSTOM, UV2, INSTANCE_ID, TIME, eye, blink);
	v_eye = eye;
	v_blink = blink;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(detail_tex, vec2(UV.x * detail_scale, UV.y * detail_scale / max(streak, 0.1))).r;
	float mist = texture(detail_tex, v_wpos.xz * 0.35 + vec2(TIME * 0.05, -TIME * 0.03)).r;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 base = ghost_col * (0.75 + 0.35 * d);
	float horn = 1.0 - COLOR.a;
	// r29: mostly its own cold light, little diffuse: lit by a lantern or a window the near-white
	// coat turned orange and read as an untextured placeholder
	ALBEDO = base * mix(1.0, 0.85, horn) * 0.3;
	ROUGHNESS = 0.9;
	EMISSION = ghost_col * (glow * (0.75 + fres * 1.8)) * (0.7 + 0.6 * mist) * (0.8 + 0.4 * d);
	if (v_eye > 0.5) {
		EMISSION += vec3(0.6, 0.85, 1.2) * 1.2 * v_blink;
	}
	ALPHA = clamp(fade * (0.32 + 0.6 * fres + 0.25 * mist), 0.0, 1.0);
}
