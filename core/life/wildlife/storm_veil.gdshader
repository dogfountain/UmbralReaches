shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Rain clouds rolling over the sky (weather.gd, r29). A sphere round the camera in the sky layer
// (pushed to the far end of the depth range like the cloud flash: over the sky, behind everything):
// dark slate cloud masses that thicken with the rain, drift with the wind and light up from within
// when lightning flashes. Draws nothing in clear weather (the node is hidden).

uniform sampler2D cloud : filter_linear_mipmap, repeat_enable;
uniform float cover = 0.0;          // 0 clear .. 1 a full storm
uniform float flash = 0.0;
uniform vec2 drift = vec2(0.0);
varying vec3 dir;

void vertex() {
	dir = VERTEX;
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = POSITION.w * 0.000001;
}

void fragment() {
	vec3 d = normalize(dir);
	// a cloud deck overhead: project the view direction onto a plane, so masses shrink toward the horizon
	vec2 uv = d.xz / (max(d.y, 0.0) + 0.22) * 0.3 + drift;
	float n = texture(cloud, uv).r * 0.65 + texture(cloud, uv * 2.3 - drift * 0.7).r * 0.35;
	float dens = smoothstep(0.6 - cover * 0.5, 0.92 - cover * 0.35, n);
	float horizon = smoothstep(-0.05, 0.25, d.y);
	ALPHA = clamp(cover * (0.45 + 0.55 * dens) * mix(0.85, 1.0, horizon), 0.0, 0.9);
	// lit from within by a flash: the thick masses most, never brighter than a dim blue-grey
	ALBEDO = mix(vec3(0.03, 0.04, 0.065), vec3(0.2, 0.25, 0.42), clamp(flash * (0.1 + dens * 0.6), 0.0, 1.0));
}
