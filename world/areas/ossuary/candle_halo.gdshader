shader_type spatial;
// Soft warm glow round each candle flame: camera-facing quad, additive radial falloff, dim
// enough that hundreds stay under the glow threshold but the air around a cluster warms.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint = vec3(1.0, 0.5, 0.18);
uniform float strength = 0.16;

varying float seed;
varying float near_fade;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.7548776);
	// billboard: keep the instance origin, orient the quad to the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	// a flame close to the eye must not bloom into a floating disc: the halo fades out inside 9 m and is gone inside 2.5 m
	near_fade = smoothstep(2.5, 9.0, length(MODELVIEW_MATRIX[3].xyz));
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.4);
	float flick = 0.8 + 0.2 * sin(TIME * (9.0 + seed * 7.0) + seed * 50.0);
	ALBEDO = tint * g * strength * flick * near_fade;
	ALPHA = 1.0;
}
