shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, blend_add, depth_draw_never, cull_disabled;
// Anamorphic moon flare: long streak, soft halo, a few ghosts. Stays modest so the glow budget holds.

uniform vec4 color : source_color = vec4(0.58, 0.78, 1.12, 1.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float halo = exp(-r * r * 8.0);
	float a = halo * 0.48;
	a *= 0.84 + 0.16 * sin(TIME * 1.35);
	float scene_d = texture(depth_tex, SCREEN_UV).r;
	float edge = smoothstep(0.0, 0.004, scene_d - FRAGCOORD.z);
	a *= edge;
	EMISSION = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
