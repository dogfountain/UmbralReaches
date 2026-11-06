shader_type spatial;
// The loot beam: a soft column of light in the drop's quality colour, brightest at the ground and
// fading out upward, with soft edges (its middle faces you, its sides thin away). It used to be a
// solid glowing cylinder of even brightness that read as a pole stuck in the ground.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0);
uniform float strength = 0.9;
uniform float pulse = 0.0;

void fragment() {
	// CylinderMesh UV.y runs 0 at the top to 1 at the bottom
	float base = clamp(UV.y, 0.0, 1.0);
	float fade = pow(base, 1.15) * smoothstep(0.0, 0.08, 1.0 - base + 0.02);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, 1.4);
	float a = fade * edge * strength * (1.0 + 0.12 * pulse);
	ALBEDO = beam_color.rgb * a;
	ALPHA = a;
}
