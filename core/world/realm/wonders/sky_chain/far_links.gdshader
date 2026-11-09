shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// The Sky Chain's high links, seen from the village against the vortex: dark iron that takes the sky's violet at its
// edges, drifts a little in the turning air, and thins out into the sky above fade_end (no cut, no pop).
// Every link carries its own height in its model matrix, so the fade is in world space.
uniform vec3 iron : source_color = vec3(0.2, 0.2, 0.25);
uniform vec3 sky_tint : source_color = vec3(0.34, 0.24, 0.62);
uniform float fade_start = 150.0;
uniform float fade_end = 470.0;
uniform float sway = 1.6;
varying float v_h;
varying float v_up;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = smoothstep(30.0, 300.0, w.y);
	// a slow, tall wave: neighbours move together, so the links do not tear apart
	vec3 off = vec3(sin(TIME * 0.21 + w.y * 0.011), 0.0, cos(TIME * 0.17 + w.y * 0.013)) * sway * k;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	v_h = w.y;
	v_up = clamp((MODEL_NORMAL_MATRIX * NORMAL).y, -1.0, 1.0);
}

void fragment() {
	float f = 1.0 - smoothstep(fade_start, fade_end, v_h);
	vec3 base = COLOR.rgb * iron * 2.6;
	// the higher, the more of the vortex's colour: it is lit from behind by the sky
	float sky = smoothstep(40.0, 420.0, v_h);
	ALBEDO = mix(base, sky_tint * 0.5, sky * 0.5);
	METALLIC = 0.55;
	ROUGHNESS = 0.42;
	RIM = 0.75;
	RIM_TINT = 0.5;
	EMISSION = sky_tint * (0.05 + 0.12 * max(v_up, 0.0)) * (0.5 + sky);
	ALPHA = f;
}
