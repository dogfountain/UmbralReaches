shader_type spatial;
// Village lamp glass (village system): dark smoky glass when out, a warm guttering flame when lit.
// Per lamp: instance uniforms `lit` (0..1, eased by the director) and `seed` (flicker phase).
render_mode unshaded, cull_disabled;

instance uniform float lit = 0.0;
instance uniform float seed = 0.0;
uniform vec3 flame : source_color = vec3(1.0, 0.6, 0.27);
uniform vec3 cold : source_color = vec3(0.07, 0.075, 0.09);
uniform float energy = 1.3;

void fragment() {
	float t = TIME * 7.0 + seed * 13.0;
	float flick = 0.86 + 0.08 * sin(t) + 0.06 * sin(t * 2.7 + 1.3);
	// brighter low in the glass (the wick), dimmer at the top
	float wick = mix(1.15, 0.7, clamp(UV.y, 0.0, 1.0));
	ALBEDO = mix(cold, flame * energy * flick * wick, lit);
}
