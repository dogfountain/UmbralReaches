shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, blend_add, depth_draw_never, cull_disabled;
// Four-point starburst + soft halo. Billboarded. Emission only so brightness is not a^2.

uniform vec4 color : source_color = vec4(0.5, 2.4, 2.2, 1.0);
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
	float spike_x = exp(-abs(p.x) * 18.0) * exp(-abs(p.y) * 2.4);
	float spike_y = exp(-abs(p.y) * 18.0) * exp(-abs(p.x) * 2.4);
	float halo = exp(-r * r * 3.6);
	float a = (spike_x + spike_y) * 1.15 + halo * 0.55;
	a *= 0.75 + 0.25 * sin(TIME * 2.1);
	float scene_d = texture(depth_tex, SCREEN_UV).r;
	float edge = smoothstep(0.0, 0.004, scene_d - FRAGCOORD.z);
	a *= mix(0.15, 1.0, edge);
	EMISSION = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
