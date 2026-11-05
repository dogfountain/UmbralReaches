shader_type spatial;
// Soft halo round a lit village lamp (village system): a camera-facing quad, additive, faint;
// stays well under the glow threshold on its own (it reads as light in the damp air, not bloom).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float lit = 0.0;
instance uniform float seed = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.55, 0.22);
uniform float strength = 0.32;

void vertex() {
	// billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float t = TIME * 5.0 + seed * 11.0;
	float flick = 0.9 + 0.1 * sin(t);
	ALBEDO = tint * a * strength * lit * flick;
}
