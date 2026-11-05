shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Enemy health bar: one camera-facing quad. Frame, back, trail, fill and the notches between
// segments are all drawn here from three per-instance values, so every enemy shares one mesh and
// one material (one draw call each) and the fill is exact -- no scaled child quads.
//
// Why not StandardMaterial3D billboards: that billboard mode discards the node's rotation AND scale
// (billboard_keep_scale is off by default) and applies a position offset in world space, so scaling
// a fill quad does nothing and offsetting it slides it sideways in the world.

// Whole bar, in metres. Enemy.gd feeds the same numbers to the mesh; keep them in step.
uniform vec2 size = vec2(0.86, 0.1);
uniform float frame = 0.014;            // outer frame thickness, metres
uniform float notch = 0.006;            // half-width of a segment notch, metres

uniform vec3 frame_col : source_color = vec3(0.03, 0.02, 0.04);
uniform vec3 back_col : source_color = vec3(0.16, 0.09, 0.12);
// r29: ember, not crimson -- the night grade pulls hues under ~16 deg to blue (zz/critA_color_shot)
uniform vec3 fill_col : source_color = vec3(0.92, 0.36, 0.12);
uniform vec3 trail_col : source_color = vec3(1.0, 0.8, 0.45);

instance uniform float fill : hint_range(0.0, 1.0) = 1.0;     // current health ratio
instance uniform float trail : hint_range(0.0, 1.0) = 1.0;    // eases down behind `fill` after a hit
instance uniform float segments : hint_range(1.0, 16.0) = 3.0; // max_hp: one notch between each hit point
// r31: the poise meter (a gold strip along the bar's underside, filling toward a stagger) and the
// BROKEN state after one (the frame burns gold: every blow lands harder for a beat)
instance uniform float poise : hint_range(0.0, 1.0) = 0.0;
instance uniform float broken : hint_range(0.0, 1.0) = 0.0;
uniform vec3 poise_col : source_color = vec3(1.0, 0.82, 0.36);

void vertex() {
	// Face the camera, keep the node's position only.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= size;
}

void fragment() {
	vec2 m = UV * size;                                  // metres from the top-left corner
	vec2 inner = size - vec2(frame * 2.0);
	vec2 q = (m - vec2(frame)) / inner;                  // 0..1 inside the frame
	vec3 col = mix(frame_col, poise_col * (0.75 + 0.35 * sin(TIME * 16.0)), broken);
	if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) {
		col = back_col;
		if (q.x <= trail) {
			col = trail_col;
		}
		if (q.x <= fill) {
			col = fill_col;
		}
		col *= 1.15 - 0.45 * q.y;                        // lit top edge, darker underside
		if (q.y > 0.68 && q.x <= poise) {
			col = mix(col, poise_col * 1.3, 0.9);
		}
		float k = q.x * segments;
		float to_notch = abs(k - round(k)) / segments * inner.x;
		if (segments > 1.5 && to_notch < notch && k > 0.02 && k < segments - 0.02) {
			col = frame_col;
		}
	}
	ALBEDO = col;
}
