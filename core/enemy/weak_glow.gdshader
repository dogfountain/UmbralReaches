shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
// r38: the glow of a weak point or a lantern as a light from inside, not a flat disc. Hot at the middle,
// falling off to nothing at the silhouette (so it bleeds into the body round it), a slow irregular
// flicker from TIME. One shared material per colour; no lights, no extra meshes.
uniform vec3 glow_col : source_color = vec3(1.7, 1.0, 0.32);
uniform float flicker_rate = 5.0;
instance uniform float phase = 0.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(ndv, 2.0);
	float t = TIME * flicker_rate;
	float fl = 1.0 + 0.10 * sin(t + phase) + 0.07 * sin(t * 2.7 + phase * 1.9);
	ALBEDO = glow_col * (0.35 + 0.95 * core) * fl;
	ALPHA = pow(ndv, 0.8);
}
