shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// A glimmer wisp: a billboarded soft core and radial glow, no geometry to show an edge. Fades out
// inside ~1.5 m of the eye (like the candle halo) and softens where it meets a surface.

uniform vec3 tint = vec3(0.4, 2.2, 1.6);
uniform float core_strength = 1.5;
uniform float halo_strength = 0.55;
uniform float flicker_hz = 1.6;
uniform float near_begin = 0.6;
uniform float near_end = 1.8;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying float seed;
varying float near_fade;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	seed = fract(o.x * 0.173 + o.z * 0.311);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	near_fade = smoothstep(near_begin, near_end, length(MODELVIEW_MATRIX[3].xyz));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float core = pow(clamp(1.0 - r * 3.2, 0.0, 1.0), 1.5);
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 2.6);
	float f = 0.82 + 0.18 * sin(TIME * flicker_hz * 6.2831 + seed * 40.0) * sin(TIME * 2.3 + seed * 9.0);
	// soft intersection with whatever is behind the quad
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).x;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -up.z / up.w;
	float soft = clamp((scene_z + VERTEX.z) * 2.0, 0.0, 1.0);
	float a = (core * core_strength + halo * halo_strength) * f * near_fade * soft;
	ALBEDO = tint * a;
	ALPHA = 1.0;
}
