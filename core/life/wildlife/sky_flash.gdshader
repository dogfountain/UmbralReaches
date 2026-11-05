shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A lit cloud behind a lightning flash (weather.gd). Sky layer: the quad is placed SKY_R metres from
// the camera in the flash's direction and pushed to the far end of the depth range, so it draws over
// the sky and behind every piece of geometry, whatever the camera's 82 m far plane.

uniform sampler2D cloud : filter_linear_mipmap, repeat_enable;
uniform float flash = 0.0;
uniform vec2 at = vec2(0.5, 0.4);

void vertex() {
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = POSITION.w * 0.000001;
}

void fragment() {
	float c = texture(cloud, UV * vec2(1.6, 1.0) + vec2(at.x * 0.7, 0.0)).r;
	float d = length((UV - at) * vec2(1.0, 1.6));
	float body = smoothstep(0.75, 0.0, d) * smoothstep(0.3, 0.75, c);
	float edge = smoothstep(1.0, 0.8, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
	ALBEDO = vec3(0.5, 0.62, 1.0) * body * edge * flash * 0.75;
}
