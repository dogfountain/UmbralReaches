shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, blend_add, depth_draw_opaque, cull_disabled;
// Soft additive mote. Billboarded so it reads as a glow from any angle.

uniform vec4 color : source_color = vec4(0.4, 2.2, 1.6, 1.0);
uniform float pulse_hz = 1.35;
uniform float size = 1.0;

varying float pulse;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * size, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * size, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * size, 0.0),
		MODEL_MATRIX[3]);
	pulse = 0.72 + 0.28 * sin(TIME * pulse_hz * TAU + world_pos.x * 1.7 + world_pos.z * 0.9);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float core = smoothstep(0.38, 0.0, r);
	float halo = exp(-r * r * 2.2);
	float a = (core * 1.6 + halo * 0.7) * pulse;
	ALBEDO = color.rgb * a;
	EMISSION = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
