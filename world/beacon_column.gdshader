shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A soft additive light column (the summit's guiding beam; Wayfinding.beacon(..., soft = true)).
// It used to be a flat alpha-blended cylinder that clipped to a solid white pole under AgX and read
// as a UI marker. Now: the alpha falls off radially to nothing at the silhouette (view angle on
// the cylinder wall), fades in above the foot and out at the top, and the colour is capped well
// under the HDR glow threshold (peak = tint * energy <= ~0.8, so it never reaches white).

uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.62);
uniform float energy = 0.7;
uniform float alpha = 0.5;
uniform float edge_power = 1.6;     // higher = a thinner bright axis, a softer edge
uniform float foot_fade = 0.12;     // fraction of the height that fades in from the bottom
uniform float top_fade = 0.35;      // fraction that fades out at the top

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float radial = pow(clamp(ndv, 0.0, 1.0), edge_power);
	float up = 1.0 - UV.y;          // CylinderMesh: v = 0 at the top, 1 at the foot
	float vert = smoothstep(0.0, foot_fade, up) * (1.0 - smoothstep(1.0 - top_fade, 1.0, up));
	ALBEDO = tint * energy;
	ALPHA = clamp(alpha * radial * vert, 0.0, 1.0);
}
